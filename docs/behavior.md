# Open Fliqlo behavior

## Display

- Fullscreen black background (`#000000`).
- Four flip digits for `HH:MM` (six when seconds are visible).
- Digits rendered with the Gluqlo/`Fliqlo` TrueType font (`gluqlo.ttf`; glyphs `0–9` / `AMP`).
- In 12-hour mode, `AM` / `PM` is painted on top of the hour-tens flap corner (Gluqlo-style).
- Optional horizontal hinge line on each digit (“flaps”).
- Optional dim overlay (0–80% black).
- Scale 100% fits the clock to nearly the full viewport; lower values shrink via `Transform.scale`.

## Interactions

| Gesture / key | Action |
|---|---|
| Tap | Toggle seconds |
| Long-press | Open settings sheet |
| Esc (desktop) | Exit fullscreen (or close settings if open) |
| F11 (desktop) | Toggle fullscreen |

## Settings (persisted)

- 24-hour clock
- Show seconds
- Show flaps
- Dim (0–0.8)
- Scale (0.5–1.0)

## Animation

- Digit flips use a ~500ms ease-in-out split-flap motion when a digit value changes.

## Platform notes

- iOS / Android: keep screen awake while the clock is foreground; immersive system UI.
- Windows / Linux: borderless fullscreen via `window_manager` on launch.
- Not an OS screensaver in P0 (no `.scr` / DreamService).
