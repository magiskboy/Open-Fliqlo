# Open Fliqlo Lock Screen — GNOME Shell extension

Embeds `open_fliqlo --lockscreen` into the GNOME unlock dialog.

Full docs: [docs/lockscreen-gnome.md](../../docs/lockscreen-gnome.md)

```bash
# Dev install (rsync into ~/.local/share/gnome-shell/extensions/)
./install.sh

# Or pack a zip for gnome-extensions install / CI / Release
./pack.sh
gnome-extensions install dist/open-fliqlo-lockscreen@openfliqlo.shell-extension.zip

gnome-extensions enable open-fliqlo-lockscreen@openfliqlo
```