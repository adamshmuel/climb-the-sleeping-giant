---
name: guides-check
description: Review the Anthropic guide pages that changed since their last review, against this project's agent setup. Use at a task close when the session start said a guide page changed, or when the user asks whether the setup still follows the latest guides.
---

# Guides check

`.claude/hooks/guides-check.py` compares the official guide pages with their last reviewed copies at every session start. It writes only the changed lines to `work/guides/diffs/<page>.diff`. This skill reviews those lines. It runs at a task close, never mid-task.

## Steps

1. **Read the diffs only.** Open each file in `work/guides/diffs/`. Never reread a whole guide page; open its copy in `work/guides/latest/` only to read the section around a changed line.
2. **Sort each change.** For each changed point, one row:

   | Page | What changed | Our file it touches | Fits / change needed |
   |---|---|---|---|

   A wording, layout or link change is "fits". A new or changed setting, limit, default, frontmatter key, hook event or model advice is checked against `CLAUDE.md`, `.claude/rules`, `.claude/agents`, `.claude/skills`, `.claude/hooks` and `.claude/settings.json`.
   An `index-code` or `index-platform` diff lists guide pages added (`+`) or removed (`-`) on that site. Read each new page's summary; if our setup uses what it covers, add it to `PAGES` in `.claude/hooks/guides-check.py`, otherwise it "fits". A removed page we watch: find where it moved and fix its URL.
3. **Make the changes.** Setup changes are the main chat's: one `setup/<name>` branch, edits through Edit or Write, and the guide point and link named in the report. A change that touches gameplay, money or a new feature goes to the user first ("Asking the user" in `agent-workflow.md`).
4. **Mark the pages reviewed.** `python3 .claude/hooks/guides-check.py --reviewed <page> ...` (or `--reviewed all`). This saves the current copy as reviewed and deletes its diff.
5. **Tell the user in one line:** pages checked, changes made, with the link to each guide point.
