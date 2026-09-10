import Adw from 'gi://Adw';
import Gio from 'gi://Gio';
import Gtk from 'gi://Gtk';

import {
    ExtensionPreferences,
    gettext as _,
} from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';

export default class OpenFliqloLockscreenPrefs extends ExtensionPreferences {
    fillPreferencesWindow(window) {
        const settings = this.getSettings();

        const page = new Adw.PreferencesPage({
            title: _('General'),
            icon_name: 'preferences-system-time-symbolic',
        });
        window.add(page);

        const binaryGroup = new Adw.PreferencesGroup({
            title: _('Open Fliqlo binary'),
            description: _(
                'Absolute path to open_fliqlo. Leave empty to use open_fliqlo from PATH.'
            ),
        });
        page.add(binaryGroup);

        const binaryRow = new Adw.EntryRow({
            title: _('Binary path'),
        });
        binaryRow.set_text(settings.get_string('binary-path'));
        binaryRow.connect('changed', () => {
            settings.set_string('binary-path', binaryRow.get_text());
        });
        binaryGroup.add(binaryRow);

        const browseBtn = new Gtk.Button({
            label: _('Browse…'),
            valign: Gtk.Align.CENTER,
            css_classes: ['flat'],
        });
        browseBtn.connect('clicked', () => {
            const dialog = new Gtk.FileDialog({title: _('Select open_fliqlo')});
            dialog.open(window, null, (_d, res) => {
                try {
                    const file = dialog.open_finish(res);
                    if (file) {
                        const path = file.get_path();
                        binaryRow.set_text(path);
                        settings.set_string('binary-path', path);
                    }
                } catch (_e) {
                    // cancelled
                }
            });
        });
        binaryRow.add_suffix(browseBtn);

        const behaviorGroup = new Adw.PreferencesGroup({
            title: _('Lock screen behavior'),
        });
        page.add(behaviorGroup);

        const hideClock = new Adw.SwitchRow({
            title: _('Hide GNOME clock'),
            subtitle: _('Hide the built-in unlock-dialog clock'),
        });
        settings.bind(
            'hide-stock-clock',
            hideClock,
            'active',
            Gio.SettingsBindFlags.DEFAULT
        );
        behaviorGroup.add(hideClock);

        const promptBottom = new Adw.SwitchRow({
            title: _('Move unlock prompt to bottom'),
            subtitle: _(
                'Keep avatar and password below the flip clock'
            ),
        });
        settings.bind(
            'prompt-at-bottom',
            promptBottom,
            'active',
            Gio.SettingsBindFlags.DEFAULT
        );
        behaviorGroup.add(promptBottom);

        const marginRow = new Adw.SpinRow({
            title: _('Prompt bottom margin'),
            subtitle: _('Pixels from the bottom edge'),
            adjustment: new Gtk.Adjustment({
                lower: 0,
                upper: 200,
                step_increment: 4,
                page_increment: 16,
                value: settings.get_int('prompt-bottom-margin'),
            }),
        });
        settings.bind(
            'prompt-bottom-margin',
            marginRow,
            'value',
            Gio.SettingsBindFlags.DEFAULT
        );
        behaviorGroup.add(marginRow);

        const hideProfile = new Adw.SwitchRow({
            title: _('Hide profile image'),
            subtitle: _('Hide the user avatar on the unlock prompt'),
        });
        settings.bind(
            'hide-profile-image',
            hideProfile,
            'active',
            Gio.SettingsBindFlags.DEFAULT
        );
        behaviorGroup.add(hideProfile);

        const monitorMode = new Adw.ComboRow({
            title: _('Show on monitors'),
            subtitle: _(
                'Full flip clock on each selected screen — never split across monitors'
            ),
            model: new Gtk.StringList({
                strings: [
                    _('Current monitor only'),
                    _('All monitors'),
                ],
            }),
        });
        const modeToIndex = mode => (mode === 'all' ? 1 : 0);
        const indexToMode = index => (index === 1 ? 'all' : 'current');
        monitorMode.selected = modeToIndex(settings.get_string('monitor-mode'));
        monitorMode.connect('notify::selected', () => {
            settings.set_string(
                'monitor-mode',
                indexToMode(monitorMode.selected)
            );
        });
        settings.connect('changed::monitor-mode', () => {
            const next = modeToIndex(settings.get_string('monitor-mode'));
            if (monitorMode.selected !== next)
                monitorMode.selected = next;
        });
        behaviorGroup.add(monitorMode);

        const fadeRow = new Adw.SpinRow({
            title: _('Fade-in duration'),
            subtitle: _('Milliseconds'),
            adjustment: new Gtk.Adjustment({
                lower: 0,
                upper: 3000,
                step_increment: 50,
                page_increment: 100,
                value: settings.get_int('fade-in-ms'),
            }),
        });
        settings.bind(
            'fade-in-ms',
            fadeRow,
            'value',
            Gio.SettingsBindFlags.DEFAULT
        );
        behaviorGroup.add(fadeRow);

        const timeoutRow = new Adw.SpinRow({
            title: _('Window wait timeout'),
            subtitle: _('Milliseconds to wait for Open Fliqlo to appear'),
            adjustment: new Gtk.Adjustment({
                lower: 5000,
                upper: 60000,
                step_increment: 1000,
                page_increment: 5000,
                value: settings.get_int('window-timeout-ms'),
            }),
        });
        settings.bind(
            'window-timeout-ms',
            timeoutRow,
            'value',
            Gio.SettingsBindFlags.DEFAULT
        );
        behaviorGroup.add(timeoutRow);
    }
}
