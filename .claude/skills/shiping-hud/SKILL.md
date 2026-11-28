---
name: shiping-hud
description: Visual standard for Shiping UI (pixel scale, panels, buttons, colors, CRT display shaders, fonts, margins, layout). Use whenever creating or changing any HUD, menu, screen, overlay, popup, tooltip, card, bar, counter, UI icon or UI texture in this Godot project, even if the request only says "add a button", "show this value on screen" or "make a panel".
---

# Shiping HUD standard

Read `extras/CLAUDE.md` too: typing, localization, no comments in `.gd`, tests.

## References

Approved look, copy from these: fleet menu (`scenes/ui/shop/scripts/shop_menu.gd`), battle HUD
(`scenes/ui/naval_hud/naval_hud.gd`), campaign screens (`scenes/ui/run/run_screen.gd` and subclasses), pause and options.

The campaign route map (`run_map_screen.gd`, `map_chart.gd`) is approved too. Not finished, never copy from it:
research (`scenes/ui/research/`). Legacy, never copy: `scenes/ui/game/game_ui.tscn`, `game_ui_button.tscn`, `win_screen`,
`ui-atlas*.png`, `core/resources/ui/game_ui.tres`.

## 1. Pick the context first

Everything else follows from it. Do not mix columns inside one element.

| | Screen (campaign, pause, options, modals) | Dense menu (fleet) | Battle HUD |
|---|---|---|---|
| Source factories | `RunScreen`, `PauseMenu` | `ShopMenu` | `naval_hud.gd` |
| Outer panel | `panel_frame_v01` | `panel_frame_v01` | `panel_frame_v01` |
| Inner module | frame + `header_plate` | flat 1px, radius 0 | flat 1px, radius 2 |
| Button | textured `pause/button_*` | flat | flat |
| Selected / focus | focus texture | cyan edge | amber edge (selected), cyan (focus) |
| Default font | `dogicapixel` | `dogicabold` | `dogicabold` |
| Body size | 16, secondary 8 | 8 | 8 |

A new campaign screen extends `RunScreen`. For another context, reuse the existing factory of that context. If the
factory is private to its file and the new element lives elsewhere, move it to a shared class and make both call it;
do not paste a second copy (one code path per effect).

## 2. Pixels

- Base viewport 1280x720, Nearest filtering. Set `texture_filter = TEXTURE_FILTER_NEAREST` on the UI root.
- Chrome (frames, buttons, plates, dividers, slots) is 1 texture px = 1 viewport px. Never set `scale` on it; grow it
  with 9-slice margins.
- Icons and unit art may scale by an integer (1x, 2x, 3x) only. Compute `Vector2(texture.get_size()) * factor`; never
  type a size that is not a multiple of the native one.
- Positions of centered art are `floor()`ed.
- New textures: transparent PNG, no antialiasing, gradients, blur or soft shadow, light from above, `_v01` suffix,
  preview in `extras/art_preview/` and approval before entering `assets/`.

| Texture | 9-slice margin |
|---|---|
| `pause/panel_frame_v01` | 16 (`MenuBackground.make_box()`) |
| `pause/button_*` | 4 (focus: left 9) |
| `pause/header_plate_v01` | 2 |
| `pause/divider_v01` | none, 2px tall, stretched horizontally |
| `modifiers/slot_*` | 8 (equipped, unavailable), 4 (available, empty) |

Icon sizes in use: 8x8 inline with 8px text, 12x12 in card headers, 24x24 for skills and objectives, 32x32 relics and
map glyphs. Screw is 9x9 and gear 10x10.

## 3. Type

- **Descriptions** (sentences that explain a relic, unit, weapon, skill, objective, weather, event, option or what to
  do next) use Pixel Operator 8: call `PixelText.describe(label)` after building the label. It keeps the label's size,
  color and case, and its digits fall back to Dogica. This is the only way to apply the font; never preload it
  elsewhere.
- Everything else stays in Dogica: titles, plates, buttons, labels, status, unit names and numbers. Never change a
  Dogica text's font, weight or size as a side effect; accents that rise above the line are intentional.
- Only 8, 16, 24 and 32. Other numbers either snap (`PixelText.snap`: 12 becomes 8, 14 becomes 16) or render soft when
  passed raw.
- Text at 8 is UPPERCASE (`PixelText.fit`). 16 and up keeps its authored case.
- `dogicabold` for titles, buttons, plates; `dogicapixel` for body on screens.
- Screen title 32, kicker and subtitle 16, big values 24, captions 8.
- No text shadow. Outline only over moving art: size 4, `#090f15` (or `#06181a` on a display).
- Every string is a localization ID, in every `assets/localization/*.json`, and must fit in PT-BR.

## 4. Color

| Role | Screen (`RunScreen` consts) | Dense menu | Battle HUD |
|---|---|---|---|
| Text | `#eaf3f5` | `#e8f1f2` | theme default |
| Text secondary | `#a3bec8` | `#c4cdd0` | `#c4cdd0` |
| Text dim / disabled | `#7795a1` | `#7f8b90` | `#c4cdd0` |
| Accent cyan | `#78dddd` | `#70d6d3` | `#a4d7d4`, focus `#70d6d3` |
| Accent amber | `#ecc078` | `#e6b35d` | `#e6b35d` |
| Danger | `#dfa0a2` | | low resource `#d7a4a0`, enemy `#eb6862` |
| Panel face | `#152027` | `#151f25` | `#151f25` |
| Plate / steel | `#34454f` | `#34454f`, edge `#596a73` | same |
| Well | `#090f16` | `#090f16` | `#172127` |
| Plate heading | | `#c5dbdd` | `#c5dbdd` |

Flat buttons and cards (dense menu and HUD):

| State | Face | Edge |
|---|---|---|
| Normal | `#293740` | `#72838d` |
| Hover | face lightened 0.10 | edge lightened 0.12 |
| Pressed | face darkened 0.25 | edge |
| Disabled | `#20292e` | `#47545a` |
| Unavailable / empty card | `#141b1f` | `#3a464c` |
| Primary action | `#1f4448` | `#70d6d3` |
| Purchase | `#3a3220` | amber, amber text |
| Skill card | `#2a2036` | skill palette |

Flat styles always set `anti_aliasing = false` and 1px borders.

Meaning is fixed: cyan = interface and focus, amber = cost, currency and attention, red = danger or enemy,
purple = skill. Do not add a new accent without asking.

Rarity: `#c5cdd0`, `#a2d5ad`, `#9bbeeb`, `#dfa0a2` (`run_data.gd`).

## 5. CRT displays

Use a display for anything that is a "screen" in the fiction: unit portraits, previews, queue slots, resource and
currency readouts. Plain information panels are not displays.

Anatomy, back to front:

1. Well: flat panel, fill `#4d6069` (lit) or `#2f3c43` (off), edge `#172127`.
2. `ColorRect` with `shaders/digital_panel.gdshader`.
3. Art with `shaders/unit_tint.gdshader`: `tint = pal.rest` lit, `pal.unloaded` off.
4. Labels and header icons in `pal.text`; captions in `pal.light`.

Rules:

- Colors come from `DisplayPalette.of_unit()`, `of_dock()`, `of_skill()` plus `apply_screen()`. Never hardcode the cyan.

| Palette | rest | text | light | unloaded |
|---|---|---|---|---|
| Naval | `#5fd9cf` | `#9ad5ce` | `#b8fff6` | `#1b4c4b` |
| Air | `#e6c24d` | `#d5c79a` | `#fff3b8` | `#4c421b` |
| Sub | `#6fdc7a` | `#9ad5a1` | `#c4ffc9` | `#1b4c25` |
| Skill | `#c58ae8` | `#c9a6dd` | `#ecc4ff` | `#43225a` |

- Bind `rect_size` on `resized`, or the dot grid and corner brackets distort.
- `band_strength` 1 when live, 0 when empty, locked or unavailable.
- Off state also dims: well `modulate (0.72, 0.74, 0.78)`, title `(0.65, 0.68, 0.7)`, HUD header `(0.38, 0.45, 0.45)`.
- Over a live viewport (battle preview) use `digital_overlay.gdshader` through `battle_sandbox.make_digital_overlay()`
  and `apply_overlay()`.
- One-color icons on plain panels use `silhouette.gdshader`.
- Do not use `radar_panel`, `vhs_display`, `button_carved_ui` or `fill_rect` in new UI.

### Disabled displays

When a display is off (dock offline, unit unavailable, empty slot, locked), the whole control is off. If the display
is part of a button, the button is disabled too (`disabled = true`, disabled style, no hover lift or press), and every
text and icon on it follows: title, slot number, status, price and header icons all dim together
(`OFF_MODULATE`). The one exception is a status that explains why it is off (low screws or command in pink, queue
full in amber). Shop cards are another exception: a locked card stays clickable so the unit can be bought.

## 6. Spacing and layout

Screen (`RunScreen`):

- `MenuBackground`, margins left/right 32, top 28, bottom 14, content separation 10.
- Header: `header_plate` 92 tall, 4px cyan strip, text margin left 20, kicker 16 over title 32, subtitle right
  (margin 24). `_header()` does it.
- Columns separated by 14, card rows by 20 (28 for large reward cards).
- `_panel(12)`: the real inset is the value plus 6 of frame art.
- Footer: divider, then `_footer(back_left, primary_right)`. Buttons 46 tall, 220 to 300 wide, font 16.

Modal: centered, dim `Color(0, 0, 0, 0.55)`, framed panel, header plate 32, buttons 34 tall inset 11, separation 8,
safe action first with initial focus, destructive action last after a divider.

Dense menu: margin 18, page separation 12, columns 14, framed module content 10 + inner 4, title plate 20,
header buttons 34 tall, card 112 tall with 5 inner margin, grid separation 11 x 10.

Battle HUD: top bar 44 tall, bottom console 200 tall (frame content 10 + 4), modules separated by 4 with 4 inner
margin, title plate 14, cards 100x72 with grid separation 3 x 1, queue slot 32x26, small button 22 tall.
The world between y 44 and 520 stays clear; overlays there must be in the `hud_blocker` group if they take clicks.

### Battle top bar (`naval_hud._make_header`)

`panel_frame_v01` with no content margin, 44 tall, inner margins left/right 20, top 14, bottom 8, row separation 14.
Three parts: allied HP (caption 8 over a bar 8 tall, `#a4d7d4`), middle block at least 215 wide (wave caption, or the
8x8 code-drawn clock at 2x plus time in bold 16, `#a3bec8`, turning `#dfa0a2` at 30 seconds or less), enemy HP
(`#eb6862`). HP bars are segmented with `progress_full/empty_v01` stretched across the bar (`_make_segmented`).
Captions read `NAME  current / max`. The minimap is separate (see below).

### Results

Two forms; pick by where the player is.

- Over the battle (`RunEndOverlay`): layer 100, dim `Color(0, 0, 0, 0.6)`, centered between y 38 and 520, framed panel
  340x200, pause header (`run_end` icon pause when won, alert when lost), reason centered (danger color when lost),
  divider, one `LABEL: value` line per reward, divider, a single button with the next step.
- Full screen (`RunEndScreen`, node done): a `RunScreen` with a framed summary (plate with cyan strip when won, danger
  when lost, icon and reason), then equal `_stat_panel`s separated by 14 (title plate, value 24, divider, note), spacer,
  divider and a footer with the single action on the right (290 wide).

### Battle alerts and edge markers

- Anything that announces a threat or arrival calls `BattleAlert.show_on(canvas, title, body, stats)`. Never build
  another floating warning label. It is a flat module (`#202b31`, 1px `#dfa0a2`, radius 2), a 128x64 display of the
  unit, title bold 16 and a description; centered at y 80 (just under the minimap), 3 s then fades, one at a time.
- Off-screen targets use `ObjectiveMarkers`: for the first 3.5 s the module shows the unit display, then only the
  name tag. Arrows point in 8 fixed directions (never rotate pixel art). They are code-drawn placeholders until final
  art is approved.
- Kind sets the color of border, text and arrow: threat `#dfa0a2`, ally `#78dddd`, objective point `#ecc078`.
- Enemy units on a display use `DisplayPalette.of_threat()` (red); allies use their own unit palette.

### Battle minimap (`battle_minimap.gd`)

360x22, centered, top 50: solid `#151f25`, 1px `#596a73` outline, never translucent and never glued to the top bar.
One water line, a base silhouette at each end (no HP bars), unit glyphs 5px wide that differ by ship, plane and sub.
Meaning is carried by color or shape only, with no pings or blinking: ally `#78dddd`, enemy `#eb6862`, boss `#ecc078`,
escort a white 7px square with a core. The camera rectangle shows width and height of what is visible between the
HUD bars. Click or drag moves the camera, the wheel zooms.

## 7. Behaviour

- Panels never change size with content: reserve the space, use a `ScrollContainer`, or ellipsize.
- Nothing crosses the screen margins (on a `RunScreen`: left/right 32, bottom 14, so panels end at y 706 at most). A
  fixed minimum height inside a column is the usual cause: keep minimums small and let expand flags fill the rest.
- Every screen grabs an initial focus (`grab_focus.call_deferred`).
- Destructive actions need two steps.
- `UiSfx` already sounds every `BaseButton`; for custom cues set `UiSfx.MANUAL_META` before adding it to the tree and
  play through `HudSfx`.
- Segmented bars use `progress_full/empty_v01` or `reward_full/empty_v01` (16x8, 1x) via `_segment_bar`.

## 8. Verify

1. Look at the result in a window: `godot --path . res://dev_tools/ui_gallery/ui_gallery.tscn -- shots` for the building blocks
   (without `-- shots`, or via `extras/ui_gallery.bat`, it stays open),
   `res://tests/ui_shots.tscn` for campaign screens. Open the PNGs and check them against this list.
2. Check PT-BR: no clipped text, no panel that grew, accents readable.
3. `sh extras/run_tests.sh` (includes `loc_test`).
4. A screen not covered by those two: say it is unverified, or ask before extending a permanent test. No temporary
   scenes.

## Known debt (do not fix unasked, do not repeat)

- Card prices pass font size 12 raw (fleet menu and HUD).
- Same screw icon at 1x, 2x and forced 18x18.
- Many private copies of `_style`, `_label`, `_box`, with different argument order.
- No shared tooltip: most use Godot's default `tooltip_text`.
- Fleet menu and HUD hardcode `DISPLAY_*` cyans instead of `DisplayPalette`.
- The default scale mode in `core/game_settings.gd` is fractional, which breaks pixel uniformity off 1280x720.
