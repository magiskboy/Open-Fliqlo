import Clutter from 'gi://Clutter';
import GObject from 'gi://GObject';

/** Default gap between the auth prompt and the bottom edge (logical px). */
export const DEFAULT_BOTTOM_MARGIN = 48;

/**
 * UnlockDialog layout that pins the auth stack (avatar + password) near the
 * bottom edge, so a centered flip-clock background is not covered.
 *
 * Compatible with GNOME 46–49 (stack / notifications / switch-user) and
 * GNOME 50+ (also auth-indicator + bottom button group). Pattern mirrors
 * WACK Sonoma Lockscreen's custom LayoutManager swap.
 */
export const BottomPromptLayout = GObject.registerClass(
class BottomPromptLayout extends Clutter.LayoutManager {
    /**
     * @param {object} actors
     * @param {Clutter.Actor} actors.stack
     * @param {Clutter.Actor} actors.notifications
     * @param {Clutter.Actor|null} [actors.switchUserButton]
     * @param {Clutter.Actor|null} [actors.authIndicatorButton]
     * @param {Clutter.Actor|null} [actors.bottomButtonGroup]
     * @param {number} [actors.bottomMargin]
     */
    _init(actors) {
        super._init();
        this._stack = actors.stack;
        this._notifications = actors.notifications;
        this._switchUserButton = actors.switchUserButton ?? null;
        this._authIndicatorButton = actors.authIndicatorButton ?? null;
        this._bottomButtonGroup = actors.bottomButtonGroup ?? null;
        this._bottomMargin = actors.bottomMargin ?? DEFAULT_BOTTOM_MARGIN;
    }

    vfunc_get_preferred_width(_container, forHeight) {
        return this._stack.get_preferred_width(forHeight);
    }

    vfunc_get_preferred_height(_container, forWidth) {
        return this._stack.get_preferred_height(forWidth);
    }

    vfunc_allocate(_container, box) {
        const [width, height] = box.get_size();
        const tenthOfHeight = height / 10.0;

        const [, , stackWidth, stackHeight] = this._stack.get_preferred_size();
        const [, , notificationsWidth, notificationsHeight] =
            this._notifications.get_preferred_size();

        const columnWidth = Math.max(stackWidth, notificationsWidth);
        const columnX1 = Math.floor((width - columnWidth) / 2.0);
        const actorBox = new Clutter.ActorBox();

        // Auth / clock stack — bottom-aligned (WACK Cupertino-style).
        const stackY = Math.max(
            tenthOfHeight,
            height - stackHeight - this._bottomMargin
        );

        actorBox.x1 = columnX1;
        actorBox.y1 = stackY;
        actorBox.x2 = columnX1 + columnWidth;
        actorBox.y2 = stackY + stackHeight;
        this._stack.allocate(actorBox);

        // Notifications sit above the prompt so they do not cover the password.
        const maxNotificationsHeight = Math.min(
            notificationsHeight,
            Math.max(0, stackY - tenthOfHeight)
        );
        const notifY = stackY - maxNotificationsHeight;

        actorBox.x1 = columnX1;
        actorBox.y1 = notifY;
        actorBox.x2 = columnX1 + columnWidth;
        actorBox.y2 = notifY + maxNotificationsHeight;
        this._notifications.allocate(actorBox);

        this._allocateCornerActor(
            this._authIndicatorButton,
            box,
            /* atStart */ true
        );
        this._allocateCornerActor(
            this._bottomButtonGroup,
            box,
            /* atStart */ false
        );

        // GNOME 46–49: single switch-user control (stock uses a 2× inset).
        if (this._switchUserButton?.visible && !this._bottomButtonGroup) {
            const [, , natWidth, natHeight] =
                this._switchUserButton.get_preferred_size();
            const rtl =
                this._switchUserButton.get_text_direction() ===
                Clutter.TextDirection.RTL;

            if (rtl)
                actorBox.x1 = box.x1 + natWidth;
            else
                actorBox.x1 = box.x2 - natWidth * 2;

            actorBox.y1 = box.y2 - natHeight * 2;
            actorBox.x2 = actorBox.x1 + natWidth;
            actorBox.y2 = actorBox.y1 + natHeight;
            this._switchUserButton.allocate(actorBox);
        }
    }

    _allocateCornerActor(actor, box, atStart) {
        if (!actor?.visible)
            return;

        const [, , natWidth, natHeight] = actor.get_preferred_size();
        const actorBox = new Clutter.ActorBox();
        const rtl =
            actor.get_text_direction() === Clutter.TextDirection.RTL;
        const placeAtStart = rtl ? !atStart : atStart;

        if (placeAtStart)
            actorBox.x1 = box.x1;
        else
            actorBox.x1 = box.x2 - natWidth;

        actorBox.y1 = box.y2 - natHeight;
        actorBox.x2 = actorBox.x1 + natWidth;
        actorBox.y2 = actorBox.y1 + natHeight;
        actor.allocate(actorBox);
    }
});

/**
 * Resolve UnlockDialog mainBox actors across Shell versions.
 *
 * @param {object} dialog Main.screenShield._dialog
 * @returns {{mainBox: Clutter.Actor, actors: object}|null}
 */
export function resolveUnlockDialogLayoutActors(dialog) {
    const stack = dialog?._stack;
    if (!stack)
        return null;

    const mainBox = stack.get_parent();
    if (!mainBox?.layout_manager)
        return null;

    const orig = mainBox.layout_manager;
    return {
        mainBox,
        actors: {
            stack: orig._stack ?? stack,
            notifications:
                orig._notifications ?? dialog._notificationsBox,
            switchUserButton:
                orig._switchUserButton ?? dialog._otherUserButton ?? null,
            authIndicatorButton: orig._authIndicatorButton ?? null,
            bottomButtonGroup: orig._bottomButtonGroup ?? null,
        },
    };
}
