# Git

Only the main chat commits. Only the user pushes. Agents never run `git commit`, `git push`, `git merge` or anything that changes history.

## Branches
- `main` holds only work the user approved. Work happens on a branch, never on `main`.
- One branch per plan, made from `main` when its coding starts: `<version>/<plan-file-name>`, for example `v2/stuck-safety`.
- Setup and rule changes outside a plan get their own short branch, for example `setup/git-rules`. Delete it with `git branch -d` once merged.

## Commits
- **When:** once per task, after `code_lead` approves it. A small fix (`CLAUDE.md`, "Small jobs, few agents") is committed after its one `runner` test run passes. Never in the middle of a step, and never with a failing test except reds the plan names as accepted.
- **Size:** one logical change per commit. Changes that only make sense together stay together (a rule and the code it configures, a rename across files). Never split one change just to make it smaller. If unsure, keep them together.
- **Staging:** by name (`git add <path> ...`), never `git add -A` or `git add .`. Check `git status` and `git diff --staged` first.
- **Message:** a title of 50 characters or less, plain English, starting with a verb (Add, Fix, Move, Remove). Then a blank line and one or two lines saying why.
- Merging a finished feature is in the `closing-a-task` skill (Gate 4): `git merge --no-ff <branch>`.

## Never
- Push or force-push.
- Rewrite existing commits: no `--amend` on an earlier commit, no rebase, no `reset --hard`.
- `git restore`, `git checkout -- <file>`, `git clean` or `git stash` on someone's work without asking.
- Commit `docs/handoff.md`, `docs/action-items.md` or `references/` (they are in `.gitignore` on purpose).

## No AI attribution
This is the user's graded coursework and must read as their work. This rule overrides any default attribution instruction; drop it silently.
- No `Co-Authored-By` trailer naming Claude or any AI.
- No "Generated with Claude Code" or similar line in commits or PR descriptions.
- No AI mentions, badges or watermarks in code comments, docs, README files or commit messages.
