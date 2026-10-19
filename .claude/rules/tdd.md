# Test-driven development

Applies to code Claude writes.

The cycle, one small step at a time:

1. **Red** — write a failing test first. Run it. Watch it fail for the right
   reason.
2. **Green** — write the least code that makes it pass.
3. **Refactor** — clean it up while the test stays green.

Rules:

- No implementation code before a failing test exists for it.
- One behavior per test, named after the behavior.
- Never change a test to make a broken implementation pass.
- If a test passes the moment it is written, it is not testing anything — fix
  the test.
- **Test helpers start from a brand-new player** (nothing earned, nothing
  saved) unless a test asks for something else by name. A default "veteran"
  player hides every rule that only applies to new players.
- **Whole-session tests.** Every feature that affects a full play session gets
  at least one test that plays it end to end: join, play, keep going past the
  first goal, and check what the player really gets. Unit tests of one rule
  only prove the rule, not the experience.
