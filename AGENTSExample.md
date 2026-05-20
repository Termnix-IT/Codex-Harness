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

## Pre-Implementation Design

- Before deciding the feature shape, requirements, design, dependency strategy, or implementation approach for non-trivial work, research whether the change should be implemented at all and where the instruction or behavior belongs.
- Compare built-in APIs, framework features, existing dependencies, new libraries, and custom implementation risks before coding.
- For instruction changes, check whether the rule belongs in global `AGENTS.md`, a repo `AGENTS.md`, or a Skill before editing.
- Keep this lightweight for typo fixes, documentation-only edits, and obvious changes that follow an existing local pattern.

## Git And Change Tracking

- When a task creates high-impact changes, recommend committing the result so the user can preserve a reviewable checkpoint.
- Treat this as a suggestion only: do not stage, commit, or push unless the user explicitly asks.
- High-impact changes include broad behavior changes, multi-file refactors, dependency or build changes, security-sensitive edits, generated artifacts, or changes that would be costly to reconstruct.

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

## Global Instruction Scope

- Keep this file focused on rules that are useful across repositories and task types.
- Do not include repository-specific directory layouts, generated artifact paths, or project-only commands.
- Move detailed workflows into Skills when they are too long or too situational for always-loaded global instructions.
- Move project conventions into that repository's `AGENTS.md` when they do not apply globally.
- Do not overwrite the active global `AGENTS.md` unless the user explicitly approves the reflection.
