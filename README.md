# Shipi

A naval defense game made with Godot Engine 4.6. Build ships, planes and submarines from your base and sink the
enemy base.

## Modes
- **Campaign run**: a roguelite run on a branching map (4 floors + boss). Choose routes, set risk modifiers in the
  briefing, collect relics, repair at shipyards. Objectives vary per node (destroy the base, defend a beacon,
  escort a cargo ship, hunt submarines, shoot down a bomber).
- **Endless waves**: the original mode, survive wave after wave with bosses.

The game opens on a campaign screen where you must pick a mode before the troop menu.

## Run
- Editor: open the folder in Godot 4.6.
- Console: `run.bat` (edit the `GODOT` path inside if Godot is installed elsewhere).

## Tests
Headless logic test: `godot --headless --path . res://tests/run_logic_test.tscn`.
Window tests (`flow_test`, `battle_smoke`, `classic_mode_test`, `ui_shots`) live in `tests/` and run the same way
without `--headless`.
