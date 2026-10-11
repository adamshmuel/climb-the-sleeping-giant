# Spec-driven development

Specs live in `docs/specs/`. Implementation plans live in `docs/plans/`.

The order is always: **spec → Adam approves → plan → code.**

- No feature is coded before its spec exists in `docs/specs/` and Adam has
  approved it.
- A spec describes *what* and *why*: screens, behaviour, data, edge cases. Not
  code.
- A plan describes *how*: the steps to build it, in TDD order. One plan file per
  spec, written only after that spec is approved.
- When the code and the spec disagree, the spec is updated first, then the code.
- Specs contain no "TBD" and no open questions. Every question is answered by
  its owner before the spec reaches Adam's gate. If a value can only be set by a
  playtest, the spec still sets a starting value and says what playtest result
  would change it.

## In or out, never "nice to have"

Every feature, story, rule and task is either **in** (it gets built as part of this
spec) or **out** (it is not built in this spec). There is no "nice to have", no
priority levels like P1/P2, no "optional" and no "fallback if it's too hard".

- Something that is out but still needed later goes into a named later spec in
  `docs/specs/index.md`, for example "Launch polish: tiptoe animation".
- If a choice depends on difficulty, the owner decides now which version is built.

## Coding starts only when Adam says so

Approving a spec, or approving a plan, is **not** permission to write code.

Claude keeps planning — specs, designs, build plans — until Adam says
explicitly: *"let's start coding X."* Then only X is coded, nothing else.

If a plan seems to lead naturally into code, it stops at the plan anyway and
waits.
