# AGENTS.md

## Instruction Language

- Write this home-level `AGENTS.md` in English to reduce token usage compared with Japanese instructions.
- Respond to the user in Japanese by default.
- Keep code, commands, file paths, API names, JSON keys, and other technical identifiers in their original English form.
- Switch to English only when the user explicitly asks for English.
- Add short Japanese explanations for technical terms only when they improve clarity.

## Core Workflow

- Before changing files, inspect the README, existing structure, and relevant files to understand the impact.
- Prefer the repository's existing structure, naming conventions, and design choices.
- Make small changes that are easy to review in Git diff.
- State uncertainty as an assumption instead of presenting it as fact.
- Explain important decisions with concrete reasons.
- Ask before destructive or broad changes.

## Sub-Agent Delegation

- For non-trivial feature work, bug fixes, error investigations, and CI failures, consider using sub-agents when the work can be split into independent research, implementation, or validation scopes.
- Use explorer sub-agents for bounded read-only questions such as tracing call sites, finding existing feature patterns, locating related tests, analyzing logs, or comparing existing conventions.
- Use worker sub-agents only when write ownership can be clearly separated by file, module, layer, or responsibility.
- Keep architecture, data model, API contract, permission, and UX decisions with the main agent unless the user explicitly asks for alternatives.
- Do not delegate the immediate blocking step or design decision if the main agent needs that result before work can continue.
- Do not create multiple agents for small, obvious, single-file fixes or single-component features.
- When delegating code changes, tell sub-agents they are not alone in the codebase, must avoid reverting others' changes, and must report changed file paths.
- The main agent remains responsible for integration, consistency, review, and validation.

## Safety

- Treat public repository exposure as the default.
- Do not include API keys, tokens, passwords, secrets, private keys, or `.env` contents in files or output.
- Do not expose personal email addresses, personal paths, internal IP addresses, or internal network details.
- Do not add assets with unclear copyright or license status.
- Do not revert user-owned changes unless explicitly requested.

## Windows And PowerShell

- Prefer Windows PowerShell / PowerShell 7 workflows.
- When showing commands, briefly explain the purpose and impact when useful.
- Separate Linux commands from PowerShell commands when they differ.
- Prefer path and quoting forms that are safe on Windows.

## Validation

- After changes, run lightweight validation when feasible.
- When scripts or templates change, test the smallest representative case.
- If validation cannot be run, state what was not run and why.

## This Repository

- Use this repository as a harness for safely editing and validating a home-level `AGENTS.md`.
- Treat the root `AGENTS.md` as the source candidate for the user's home-level agent instructions.
- Use `templates/` only as helper templates for other projects.
- Use `skills/` as lightweight harness-specific workflows, not replacements for existing general skills.
- Do not automatically overwrite the user's home-level `AGENTS.md` in the MVP.
