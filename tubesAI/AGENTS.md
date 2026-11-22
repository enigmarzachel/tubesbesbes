# Repository Guidelines

## Project Structure & Module Organization

This repository is a Godot 4.7 2D game project. `project.godot` contains project settings, input actions, and the main-scene reference. Put gameplay and AI logic in `scripts/` (player code is under `scripts/player/`), scene resources in `scenes/`, and image assets in `assets/`. Keep scene-to-script and asset references using Godot's `res://` paths. `LAPORAN_AI.md` is project documentation; `export_presets.cfg` stores export settings.

## Build, Run, and Development Commands

Open the project in Godot by choosing this directory, or run commands from the repository root:

- `godot --path .` launches the game using the configured main scene.
- `godot --editor --path .` opens the project in the editor.
- `godot --headless --path . --editor --quit` imports resources and checks that the project opens without editor errors.

Use a Godot 4.7-compatible editor/runtime. The project uses GDScript and the GL Compatibility renderer.

## Coding Style & Naming Conventions

Follow the editor's configured four-space indentation for GDScript. Use `PascalCase` for global classes and node-facing types, `snake_case` for functions and variables, and descriptive scene/script filenames (existing scenes use mixed naming; preserve their established names when editing). Prefer explicit types for public APIs and keep scene-specific behavior in its attached or related script. Do not hand-edit generated `.uid` or `.import` metadata unless resolving a specific import issue; let Godot regenerate it.

## Testing Guidelines

No automated test suite or test framework is present. For gameplay changes, run the relevant scene in Godot and check the affected interactions. For script or project-wide changes, use the headless editor command above and review its output for parse or resource errors. Add focused test scenes or scripts only when a change introduces logic that benefits from repeatable checks.

## Commits & Pull Requests

This directory has no Git metadata, so there is no repository commit history from which to infer a commit format. Use short imperative commit subjects if commits are created (for example, `Fix pathfinding bounds`). Pull requests should describe the player-visible or technical change, list the scenes/scripts affected, include reproduction or validation steps, and attach screenshots for visual changes.

## Configuration & Asset Tips

Keep input action names in `project.godot` consistent with their GDScript references. Preserve source assets under `assets/`; avoid committing editor caches or temporary exports. When changing scene paths or resource identifiers, verify that the main scene and dependent resources still resolve in Godot.
