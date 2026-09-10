import Clutter from 'gi://Clutter';
import Meta from 'gi://Meta';

import {
    Extension,
    InjectionManager,
} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as Config from 'resource:///org/gnome/shell/misc/config.js';

import {
    FliqloProcess,
    resolveBinaryPath,
    hasHost,
    stopHost,
    sweepLockscreenOrphans,
} from './fliqloProcess.js';
import {
    BottomPromptLayout,
    resolveUnlockDialogLayoutActors,
} from './bottomPromptLayout.js';
import {sleep, destroySleeps} from './utils.js';

const SHELL_VERSION = parseInt(Config.PACKAGE_VERSION.split('.')[0], 10);
const MAX_DIALOG_ATTEMPTS = 100;
const DIALOG_POLL_MS = 100;

/**
 * Embed Open Fliqlo as the unlock-dialog background.
 *
 * Lifecycle follows Live Lock Screen + Idlescape community patterns:
 * - session-modes: unlock-dialog only (enable on lock, disable on unlock)
 * - One Gio.Subprocess for the whole lock (module singleton) — Shell may
 *   thrash enable/disable during lock; we must NOT respawn/kill each time
 * - Teardown: proc.send_signal(9) + window.kill() + /proc sweep on unlock
 * - Also listen to screenShield locked-changed (Idlescape) as a safety net
 */
export default class OpenFliqloLockscreenExtension extends Extension {
    enable() {
        // Required by EGO review guidelines when using unlock-dialog:
        // this extension must run on the lock screen to host open_fliqlo.
        this._wrapperActors ??= [];
        this._settings ??= this.getSettings();
        this._setupGeneration ??= 0;

        this._bindLockWatcher();

        if (Main.screenShield?.locked || this._isUnlockDialog())
            this._startLockscreen();
    }

    _isUnlockDialog() {
        return Main.sessionMode.currentMode === 'unlock-dialog';
    }

    /**
     * Idlescape pattern: react to lock state changes directly.
     */
    _bindLockWatcher() {
        if (this._lockWatchBound || !Main.screenShield)
            return;
        this._lockWatchBound = true;

        try {
            this._lockedChangedId = Main.screenShield.connect(
                'locked-changed',
                () => this._onLockChanged()
            );
        } catch (_e) {
            // Older shells may lack the signal; session-modes still drive us.
            this._lockedChangedId = 0;
        }

        try {
            this._activeChangedId = Main.screenShield.connect(
                'active-changed',
                () => this._onLockChanged()
            );
        } catch (_e) {
            this._activeChangedId = 0;
        }
    }

    _unbindLockWatcher() {
        if (Main.screenShield) {
            if (this._lockedChangedId) {
                Main.screenShield.disconnect(this._lockedChangedId);
                this._lockedChangedId = 0;
            }
            if (this._activeChangedId) {
                Main.screenShield.disconnect(this._activeChangedId);
                this._activeChangedId = 0;
            }
        }
        this._lockWatchBound = false;
    }

    _onLockChanged() {
        const locked = !!Main.screenShield?.locked;
        console.log(`[OpenFliqloLockscreen] lock-changed locked=${locked}`);
        if (!locked)
            this._teardownHost('unlocked');
    }

    _persistBinaryPath() {
        const configured = this._settings.get_string('binary-path');
        const binary = resolveBinaryPath(configured);
        if (binary && binary !== configured)
            this._settings.set_string('binary-path', binary);
        return binary;
    }

    _startLockscreen() {
        // Already embedded for this lock — ignore enable() thrashing.
        if (this._uiReady && hasHost()) {
            console.log('[OpenFliqloLockscreen] host already active, skip spawn');
            return;
        }
        if (this._setupStarted)
            return;
        this._setupStarted = true;
        const generation = ++this._setupGeneration;

        this._setup(generation).catch(err => {
            if (generation !== this._setupGeneration)
                return;
            console.error(`[OpenFliqloLockscreen] setup failed: ${err}`);
            try {
                Main.notify(
                    'Open Fliqlo Lock Screen',
                    String(err.message ?? err)
                );
            } catch (_e) {
                // ignore
            }
            this._teardownHost('setup-failed');
            this._setupStarted = false;
        });
    }

    async _setup(generation) {
        const stillCurrent = () => generation === this._setupGeneration;

        const binary = this._persistBinaryPath();
        if (!binary) {
            const msg =
                'open_fliqlo not found. Open extension preferences and set the binary path.';
            console.error(`[OpenFliqloLockscreen] ${msg}`);
            try {
                Main.notify('Open Fliqlo Lock Screen', msg);
            } catch (_e) {
                // ignore
            }
            return;
        }

        const reused = hasHost();
        if (!reused)
            console.log(`[OpenFliqloLockscreen] launching ${binary} --lockscreen`);
        else
            console.log('[OpenFliqloLockscreen] reusing existing host process');

        const timeoutMs = this._settings.get_int('window-timeout-ms');
        const player = new FliqloProcess(binary);
        this._player = player;
        await player.run();

        if (!stillCurrent())
            return;

        this._injectionManager ??= new InjectionManager();
        this._injectionManager.overrideMethod(
            Main.wm,
            '_shouldAnimateActor',
            _original => {
                return function (_actor, _types) {
                    return false;
                };
            }
        );

        const win = await player.waitForWindow(timeoutMs);
        if (!stillCurrent())
            return;

        this._window = win;
        this._windowActor = win.get_compositor_private();
        if (!this._windowActor)
            throw new Error('Missing compositor private for Open Fliqlo window');

        try {
            if (SHELL_VERSION > 48)
                this._window.unmaximize();
            else
                this._window.unmaximize(Meta.MaximizeFlags.BOTH);
        } catch (_e) {
            try {
                this._window.unmaximize(true);
            } catch (_e2) {
                // ignore
            }
        }

        const parent = this._windowActor.get_parent();
        if (parent && parent !== global.stage) {
            parent.remove_child(this._windowActor);
            global.stage.add_child(this._windowActor);
            global.stage.set_child_below_sibling(this._windowActor, null);
        }
        this._windowActor.opacity = 0;

        // Size to a single monitor — never span the virtual desktop (that
        // splits hours/minutes across screens). Clones copy the full clock.
        const src = this._sourceMonitor();
        this._window.move_resize_frame(true, 0, 0, src.width, src.height);
        player.w = src.width;
        player.h = src.height;

        await this._injectIntoDialog();
        if (!stillCurrent())
            return;

        this._uiReady = true;
        console.log(
            `[OpenFliqloLockscreen] lock screen background ready ` +
            `(monitor-mode=${this._monitorMode()}, ${src.width}x${src.height})`
        );
    }

    /**
     * @returns {'current'|'all'}
     */
    _monitorMode() {
        const mode = this._settings?.get_string('monitor-mode');
        return mode === 'current' ? 'current' : 'all';
    }

    _currentMonitorIndex() {
        try {
            return global.display.get_current_monitor();
        } catch (_e) {
            return Main.layoutManager.primaryIndex;
        }
    }

    _sourceMonitor() {
        if (this._monitorMode() === 'current') {
            const idx = this._currentMonitorIndex();
            return Main.layoutManager.monitors[idx]
                ?? Main.layoutManager.primaryMonitor;
        }
        return Main.layoutManager.primaryMonitor;
    }

    _shouldShowOnMonitor(monitorIndex) {
        if (this._monitorMode() === 'all')
            return true;
        return monitorIndex === this._currentMonitorIndex();
    }

    async _waitForDialog() {
        let attempts = 0;
        while (!Main.screenShield?._dialog) {
            if (attempts >= MAX_DIALOG_ATTEMPTS) {
                throw new Error(
                    `UnlockDialog never appeared after ${MAX_DIALOG_ATTEMPTS} attempts`
                );
            }
            attempts++;
            await sleep(DIALOG_POLL_MS);
        }
        return Main.screenShield._dialog;
    }

    async _injectIntoDialog() {
        const dialog = await this._waitForDialog();

        this._injectionManager.overrideMethod(
            dialog,
            '_createBackground',
            original => {
                const self = this;
                return function (monitorIndex) {
                    original.call(this, monitorIndex);
                    self._handleMonitor(monitorIndex);
                };
            }
        );

        if (this._settings.get_boolean('hide-stock-clock'))
            this._detachStockClock(dialog);

        if (this._settings.get_boolean('prompt-at-bottom'))
            this._applyBottomPrompt(dialog);

        if (this._settings.get_boolean('hide-profile-image'))
            this._hideProfileImage(dialog);

        dialog._updateBackgrounds();

        if (this._settings.get_boolean('hide-stock-clock'))
            this._detachStockClock(dialog);
    }

    /**
     * Pin avatar + password near the bottom edge (WACK-style layout swap).
     */
    _applyBottomPrompt(dialog) {
        this._restoreBottomPrompt();

        const resolved = resolveUnlockDialogLayoutActors(dialog);
        if (!resolved) {
            console.warn(
                '[OpenFliqloLockscreen] UnlockDialog mainBox not ready; skip prompt-at-bottom'
            );
            return;
        }

        const {mainBox, actors} = resolved;
        this._mainBox = mainBox;
        this._origLayout = mainBox.layout_manager;

        const margin = Math.max(
            0,
            this._settings.get_int('prompt-bottom-margin')
        );
        mainBox.layout_manager = new BottomPromptLayout({
            ...actors,
            bottomMargin: margin,
        });
        mainBox.queue_relayout();
        console.log(
            `[OpenFliqloLockscreen] auth prompt pinned to bottom (margin=${margin}px)`
        );
    }

    _restoreBottomPrompt() {
        if (!this._mainBox || !this._origLayout)
            return;

        try {
            const old = this._mainBox.layout_manager;
            this._mainBox.layout_manager = this._origLayout;
            this._mainBox.queue_relayout();
            if (old && old !== this._origLayout)
                old._stack = null;
        } catch (_e) {
            // Dialog may already be torn down on unlock.
        }

        this._mainBox = null;
        this._origLayout = null;
    }

    /**
     * Hide UserWidget avatar on the unlock AuthPrompt.
     * AuthPrompt is created lazily and setUser() rebuilds the widget, so we
     * patch both _ensureAuthPrompt and setUser.
     */
    _hideProfileImage(dialog) {
        if (!this._profileHidePatched && this._injectionManager) {
            this._profileHidePatched = true;
            const self = this;

            this._injectionManager.overrideMethod(
                dialog,
                '_ensureAuthPrompt',
                original => {
                    return function (...args) {
                        original.call(this, ...args);
                        self._bindAuthPromptAvatarHide(this._authPrompt);
                        self._detachProfileImage(this._authPrompt);
                    };
                }
            );
        }

        if (dialog._authPrompt) {
            this._bindAuthPromptAvatarHide(dialog._authPrompt);
            this._detachProfileImage(dialog._authPrompt);
        }
    }

    _bindAuthPromptAvatarHide(authPrompt) {
        if (!authPrompt || authPrompt._openFliqloAvatarPatched)
            return;
        if (!this._injectionManager)
            return;

        authPrompt._openFliqloAvatarPatched = true;
        const self = this;
        this._injectionManager.overrideMethod(
            authPrompt,
            'setUser',
            original => {
                return function (user) {
                    original.call(this, user);
                    self._detachProfileImage(this);
                };
            }
        );
    }

    _clearProfileHideState() {
        this._profileHidePatched = false;
        try {
            const prompt = Main.screenShield?._dialog?._authPrompt;
            if (prompt)
                delete prompt._openFliqloAvatarPatched;
        } catch (_e) {
            // ignore
        }
    }

    _detachProfileImage(authPrompt) {
        const userWidget = authPrompt?._userWell?.get_child?.();
        const avatar = userWidget?._avatar;
        if (!avatar)
            return;

        try {
            avatar.hide();
            avatar.visible = false;
            avatar.opacity = 0;
        } catch (_e) {
            // ignore
        }

        const parent = avatar.get_parent();
        if (parent) {
            try {
                parent.remove_child(avatar);
            } catch (_e) {
                // ignore
            }
        }
    }

    _detachStockClock(dialog) {
        const clock = dialog?._clock;
        if (!clock)
            return;

        try {
            clock.hide();
            clock.visible = false;
            clock.opacity = 0;
        } catch (_e) {
            // ignore
        }

        const parent = clock.get_parent();
        if (parent) {
            try {
                parent.remove_child(clock);
            } catch (_e) {
                // ignore
            }
        }

        if (!this._clockProgressPatched && this._injectionManager) {
            this._clockProgressPatched = true;
            this._injectionManager.overrideMethod(
                dialog,
                '_setTransitionProgress',
                original => {
                    return function (progress) {
                        original.call(this, progress);
                        if (this._clock) {
                            this._clock.visible = false;
                            this._clock.opacity = 0;
                            const p = this._clock.get_parent();
                            if (p)
                                p.remove_child(this._clock);
                        }
                    };
                }
            );
            this._injectionManager.overrideMethod(
                dialog,
                '_showClock',
                original => {
                    return function (...args) {
                        original.call(this, ...args);
                        if (this._clock) {
                            this._clock.visible = false;
                            this._clock.opacity = 0;
                            const p = this._clock.get_parent();
                            if (p)
                                p.remove_child(this._clock);
                        }
                    };
                }
            );
        }
    }

    _handleMonitor(monitorIndex) {
        const monitor = Main.layoutManager.monitors[monitorIndex];
        if (!monitor || !this._windowActor)
            return;

        if (monitorIndex === 0) {
            for (const actor of this._wrapperActors ?? []) {
                try {
                    actor.destroy();
                } catch (_e) {
                    // ignore
                }
            }
            this._wrapperActors = [];
            this._backgroundCreated = false;
        }

        if (!this._shouldShowOnMonitor(monitorIndex)) {
            this._maybeFadeIn(monitorIndex);
            return;
        }

        const wrapper = new Clutter.Actor({reactive: false});
        const dialog = Main.screenShield._dialog;
        dialog._backgroundGroup.add_child(wrapper);
        dialog._backgroundGroup.set_child_above_sibling(wrapper, null);

        const cloneActor = new Clutter.Clone({source: this._windowActor});
        wrapper.add_child(cloneActor);

        wrapper.set_position(monitor.x, monitor.y);
        wrapper.set_size(monitor.width, monitor.height);
        wrapper.set_clip_to_allocation(true);

        // Full flip clock on this monitor (scale to cover; do not crop by
        // virtual-desktop offset — that put hours on one screen and minutes
        // on another).
        const srcW = this._player.w || monitor.width;
        const srcH = this._player.h || monitor.height;
        const scale = Math.max(monitor.width / srcW, monitor.height / srcH);
        const cw = srcW * scale;
        const ch = srcH * scale;
        cloneActor.set_size(cw, ch);
        cloneActor.set_position(
            (monitor.width - cw) / 2,
            (monitor.height - ch) / 2
        );

        if (!this._backgroundCreated)
            wrapper.opacity = 0;

        this._wrapperActors.push(wrapper);
        this._maybeFadeIn(monitorIndex);
    }

    _maybeFadeIn(monitorIndex) {
        const isLastMonitor =
            monitorIndex === Main.layoutManager.monitors.length - 1;
        if (this._backgroundCreated || !isLastMonitor)
            return;
        if (!this._wrapperActors?.length)
            return;

        const duration = this._settings.get_int('fade-in-ms');
        for (const actor of this._wrapperActors) {
            actor.ease({
                opacity: 255,
                duration,
                mode: Clutter.AnimationMode.EASE_IN_QUAD,
            });
        }
        this._backgroundCreated = true;
    }

    /**
     * Full teardown when the screen is unlocked (or setup failed).
     */
    _teardownHost(reason) {
        destroySleeps();
        this._setupGeneration = (this._setupGeneration ?? 0) + 1;

        this._player?.detach();
        this._player = null;

        stopHost(reason);

        if (this._windowActor) {
            try {
                this._windowActor.hide();
            } catch (_e) {
                // ignore
            }
            this._windowActor = null;
        }

        this._restoreBottomPrompt();

        this._injectionManager?.clear();
        this._injectionManager = null;
        this._clockProgressPatched = false;
        this._clearProfileHideState();

        for (const actor of this._wrapperActors ?? []) {
            try {
                actor.destroy();
            } catch (_e) {
                // ignore
            }
        }
        this._wrapperActors = [];
        this._window = null;
        this._backgroundCreated = false;
        this._uiReady = false;
        this._setupStarted = false;
    }

    disable() {
        // unlock-dialog mode: disable() runs on unlock AND during lock thrashing.
        // Only kill the host when the screen is no longer locked (LLS/Idlescape).
        const stillLocked = !!Main.screenShield?.locked;

        if (stillLocked) {
            console.log(
                '[OpenFliqloLockscreen] disable() while still locked — keep host'
            );
            // Drop UI hooks for this enable cycle; host process stays alive.
            // Keep bottom-prompt layout across thrashing; restore only on unlock.
            this._injectionManager?.clear();
            this._injectionManager = null;
            this._clockProgressPatched = false;
            this._clearProfileHideState();
            for (const actor of this._wrapperActors ?? []) {
                try {
                    actor.destroy();
                } catch (_e) {
                    // ignore
                }
            }
            this._wrapperActors = [];
            this._uiReady = false;
            this._setupStarted = false;
            this._settings = null;
            return;
        }

        console.log('[OpenFliqloLockscreen] disable() on unlock — stop host');
        this._unbindLockWatcher();
        this._teardownHost('disable-unlocked');
        this._settings = null;

        // Final sweep in case anything escaped.
        sweepLockscreenOrphans();
    }
}
