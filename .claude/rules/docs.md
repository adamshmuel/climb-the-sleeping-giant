---
paths:
  - "docs/**"
---

# Writing docs

The user is a beginner and reads every document themselves. A document they can't understand is not finished.

## Plain English
- Short sentences and simple words. One idea per sentence.
- Explain every game or technical term the first time it appears, in a few words, for example "retention (players coming back)".
- Prefer a small table or a short list to a long paragraph.
- Say what the player sees and does, not how the code works.

## No bare codes
| Don't write | Write |
|---|---|
| `P1` / `P2` / "nice to have" | nothing: there are no priority levels |
| `FR-07` or "Rule 7" alone | **Rule 7 (Sprinting is loud)** |
| Given / When / Then | **Situation** / **Player does** / **Result** |

A rule keeps its number forever, so other documents can point to it. Analytics events and file names also get a few words saying what they are.

## Specs and plans
- The order is always **spec → the user approves → plan → code.** Coding starts only when the user says "let's start coding X", and then only X.
- A spec says *what* and *why* (screens, behaviour, data, edge cases), never code. At most 15 rules per feature spec.
- A plan says *how*: steps in test-first order, one plan file per approved spec.
- When code and spec disagree, update the spec first, then the code.
- No "TBD" and no open questions. A value only a playtest can set gets a starting value, plus the result that would change it.
- **In or out, never "nice to have".** Something out but needed later goes into a named later spec in `docs/specs/index.md`. If a choice depends on difficulty, the owner decides now which version is built.

## Layout
- `docs/specs/<version>/index.md` (one line per feature: file, status, build order) plus `<feature>.md`; research and owner input in `docs/specs/<version>/research/`.
- `docs/plans/<version>/` in the same shape.
- `docs/progress/index.md` plus one file or folder per version.
- `docs/design/<version>/`: the look. A later version holds only what it adds or changes.
- An agent gets the index and only its feature files, never the whole folder.
- A doc over 100 lines starts with a table of contents. A reference doc (style guide, art list, build check) holds only what is true now: dated session logs and to-do lists go in their own file, linked from its index.
- V1 is older: its design is in `docs/design/v1/`, its spec and plan in `docs/specs/core-heist.md` and `docs/plans/core-heist.md`.

`.claude/hooks/docs-check.py` checks the contents list, links and "TBD" after every docs edit and at each task close (`scripts/health.py`). The rest of this rule needs judgment.

Before a document goes to a review or a gate, re-read it as the user would. Rewrite any line that needs knowledge they don't have.
