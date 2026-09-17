# Global Agent Instructions

Keep `~/.omp/agent/AGENTS.md` as the only user-local agent instruction file. Do not create global copies or redirect files.
Keep repository instruction files and load them for the target repository.

## Writing System

Follow the writing rules in the loaded system prompt. Pi uses `~/.pi/agent/APPEND_SYSTEM.md`; OMP uses `~/.omp/agent/SYSTEM.md`.

## Git workflow

- Resolve the target repository first, including its worktrees. Do not choose a tool from the shell directory alone.
- Use `gh` for GitHub operations and `git` for local version control.
- Commit, push, submit, or merge only when the user requests those actions. Preserve unrelated changes.
- Open new PRs as drafts. Publish only when the user requests it.
- Preserve existing commit messages unless the user requests a change.
- Do not force-submit or remove a PR from the merge queue without explicit approval.

## Permissions and attribution

- Send chat or notification messages only with explicit permission in the current conversation.
- Append `co-authored by AI` to commit messages or PR descriptions when AI materially contributes.
- Preserve existing AI attribution and disclosure.

## Checks and test changes

- Run existing focused tests and relevant type, lint, and format checks after behavioral changes.
- Write or update test files only when the user requests tests.
- When tests are requested, follow project test rules and target 100% branch coverage for all modified files.
- Do not claim a passing check or coverage result without running the corresponding check.
- Report unrelated baseline failures separately. Do not expand the task to repair unrelated files.
- Read applicable repository test guidelines before writing tests.

### Test execution and watcher lifetime

- Run tests as bounded, one-shot commands by default.
- Read the resolved script and runner options before using test aliases.
- Start watch mode or persistent test processes only when the user requests continuous watching or approves a stated need.
- Disable watch mode explicitly when a wrapper defaults to it. Use Jest's `--watch=false --watchAll=false` or Vitest's `run`.
- One-off Jest runs can still create persistent Watchman indexes. Use `--watchman=false` unless the user approves testing Watchman integration.
- Supervise approved watchers and record their process or service identities. Stop only task-owned watchers when their approved purpose ends.
- Confirm one-shot test processes have exited before reporting completion. Never stop pre-existing workloads or remove their watches without approval.
- Pass these rules to subagents. Report any task-created persistent process or watch that remains after the task.

### Local service ownership

- Before starting services, record the running services and their namespaces. Start only the services required for the task.
- Prefer supported dependency-only setup when tests do not need services.
- Treat shared services and pre-existing processes as user-owned. Do not stop or restart them without explicit approval.
- Record the controller and identity of each task-started project service. Recheck its identity and consumers before cleanup.
- Stop only task-owned services that no other work needs. Honor requests to keep services running.
- Do not use process age, low CPU, or a detached parent as proof that work is abandoned.
- Keep personal performance tuning in user-level configuration. Do not alter repository commands or tracked settings unless explicitly requested.

## Code quality

- Use the most capable available model, regardless of cost.
- Remove unused imports, variables, and functions.
- Avoid unnecessary type assertions, including `as`. Prefer provider data injection over module mocks.
- Do not add conditionals to `.test.tsx` files.
- Ignore `console.log` linter warnings unless the user requests those fixes.

## Command setup

- Before Git, CI, or local UI command setup, reuse checked syntax, working directories, and environment settings within the task.
- After a syntax or missing-command error, fix the cause before retrying. Do not repeat the same failing command.
- Check uncertain paths with `glob`. Check tool availability before treating an example as an executable command.
- Use state or readiness checks instead of fixed sleeps. Wait only when no independent work remains.
- Use bounded timeouts and retries.

### Browser focus safety

- Keep automated browser work off the user's visible desktop.
- Use `read` for static web content.
- For `browser.open`, use a headless browser instance.
- Never activate a browser or use a relay tab unless the user explicitly requests visible browser interaction.
- If headless interaction is unavailable, report the blocker instead of opening a visible browser.

## Code comments

- Use few code comments. Add one only when the code cannot clearly show an important constraint, invariant, workaround, or external requirement.
- Do not comment obvious code, restate the implementation, narrate control flow, record every design decision, or describe the diff.
- Prefer clear names and simple code over explanatory comments.
- Before adding a comment, ask whether a maintainer needs it to avoid a wrong change. If not, omit it.
- Keep comments short and near the relevant code. Remove comments that add no maintenance value.
- Hard cap: a comment is at most 2 lines, ideally 1. This cap has no exceptions. If the explanation needs more, it belongs in the commit message or PR body, not the code.
