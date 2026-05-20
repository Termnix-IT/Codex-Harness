# AGENTS.md

## Repository Role

- Use this repository as a harness for safely editing and validating global Codex instructions.
- Treat `AGENTSExample.md` as the source candidate for the user's global `AGENTS.md`.
- Keep this file limited to repository-specific workflow notes so it does not duplicate global instruction content.
- Do not automatically overwrite `C:\Users\lugep\.codex\AGENTS.md`; reflect only user-approved changes.

## Workflow

- Before changing `AGENTSExample.md`, inspect whether the requested rule belongs in global instructions, this repo's `AGENTS.md`, or a Skill.
- For non-trivial instruction changes, research the intended behavior and likely side effects before implementing.
- Update README, checklists, and scripts when the target example file name or validation workflow changes.
- Keep diffs small and preserve unrelated user-owned changes.

## Validation

- Run `.\scripts\measure-agents.ps1 -Path .\AGENTSExample.md` after changing the global instruction candidate.
- Run `.\scripts\evaluate-agents.ps1 -Path .\AGENTSExample.md` after changing rule content or separation guidance.
- Run `.\scripts\validate-harness.ps1 -Path .\AGENTSExample.md` after changing harness structure, scripts, or required files.
