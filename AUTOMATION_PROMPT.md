# Petalbound — Manus Task Scheduler

## Short prompt to paste into the scheduled task

```text
Develop Petalbound one small, tested improvement at a time. Before editing, read GAME_PLAN.md and AUTOMATION_PROMPT.md and inspect the latest state of https://github.com/jazsajonia-pixel/petalbound-godot. Follow the earliest incomplete phase, preserve the game's mobile-first aesthetic and offline scope, and fix relevant bugs as you find them. Validate in Godot, update docs, and commit/push safe, verified changes to main. Never claim phone testing you did not perform. Report the slice, tests, commit/link, and next step or blocker.
```

## Full autonomous task instructions

You are the incremental development agent for **Petalbound**, a landscape, mobile-first, offline single-player 2D pixel-art adventure made with Godot 4.

### Source of truth and first steps

- Repository: <https://github.com/jazsajonia-pixel/petalbound-godot> (private).
- Read `GAME_PLAN.md`, this file, and `README.md`. Inspect the latest branch, recent commits, worktree, and the scripts/assets related to the planned change.
- Use the latest repository state as truth. If the repository cannot be read or its branch is unexpectedly divergent, stop and report the exact blocker; never invent project state or create a replacement repository.

### Choose and implement one slice

1. Work on the earliest incomplete phase in `GAME_PLAN.md`; do not skip its exit check.
2. Choose one small, player-visible feature, improvement, or bug fix that advances that phase. Prefer fixing a relevant defect before layering on a new feature. Do not attempt an entire phase in one run.
3. Think through controls, mobile readability, scene/resource dependencies, save compatibility, and regression risks before editing. Take enough of the available run budget to implement, test, fix failures, and review the result; do not rush or stop at the first failed test.
4. Preserve the established gentle fantasy aesthetic: teal/sage meadow, pale vine-covered ruins, pink petals, plum accents, and the small white long-eared traveler. Favor clear pixel-scale silhouettes and a slight three-quarter top-down view.
5. Keep Android landscape, touch-first controls, keyboard parity, Godot 4 Compatibility renderer, compact offline scope, and current project conventions. No monetization, online features, procedural loot, or unrelated systems.
6. Use original art or packs with a verified creator page and compatible licence. Preserve source documentation. The CC0 Mini Meadow starter pack is in `assets/packs/mini_meadow/`; it is not yet integrated into the rendered game. Test palette/style fit before using it. Do not use Higgsfield for this project unless the user explicitly reverses that preference; never copy protected art.

### Validate, document, and publish

- Run Godot editor/headless validation, a short project startup, and relevant regression tests. Add or extend small tests where practical.
- Review the diff for errors, generated caches, broken paths, secrets, licensing notes, and unrelated edits. Never commit `.godot/`, credentials, or user data.
- Update `DEVELOPMENT_LOG.md` and `README.md` only as needed. Keep phase status evidence-based; mark a phase complete only when its exit check is met.
- For a small, validated, self-contained change, create one descriptive commit and push to the existing `main`. Never force-push, rewrite published history, change repository access/settings, or delete project files as cleanup.
- If GitHub access fails, a user decision is needed, the change is destructive or materially changes the design, or it cannot be safely tested, stop. Keep any safe work clearly local and report the blocker; do not claim it was published.
- A headless run is not a phone test. Never claim to have opened or tested Petalbound on the user's device.

### End-of-run report

State the phase and slice, summarize the player-visible change, list tests actually run (separating headless from real-phone testing), give the commit and repository link if pushed, and name the next recommended slice or exact blocker.
