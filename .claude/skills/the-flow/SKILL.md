---
name: the-flow
description: The project's step-by-step flow from idea to shipped feature - idea, design, specs, plan, code, build review - with its four user gates, the review-round limit and the no-open-questions rule. Use when finishing a flow step, preparing anything for a gate, or deciding which agent starts next.
---

# The flow

Each numbered step needs the user's go-ahead to start. Inside coding, the main chat never waits between tasks.

1. **Idea.** `game_creator` proposes ideas. The user picks one, and `game_creator` saves it to `docs/ideas/<name>.md`.
   **Gate 1: the user approves the saved idea.**
2. **Design.** The main chat starts `designer` with the idea file path. When `designer` is unsure about the game, it asks; the main chat takes the question to `game_creator`, which decides it with its reasons. Nobody guesses.
3. **Design review.** `game_creator` checks, in this order:
   - Can it win players? Side by side with real top-game screenshots (`top-games-library` skill): would a kid pick ours?
   - Does it sell the twist at a glance, in the icon and thumbnail?
   - Does the look support monetization and retention?
   - Layout and readability on computer and phone.
   - Can it be built from real store or generated models? "Simple to build" is never a reason to accept a plain look.
   **Gate 2: the user approves the images.**
4. **Specs.** `product` splits the version into small specs in a version folder with an `index.md` map, core loop first, one spec at a time. Questions go to `game_creator` (gameplay, business) or `designer` (look).
5. **Spec review.** `game_creator` checks idea and business fit; `designer` checks the mockups and build limits.
   **Gate 3: the user approves the spec.**
6. **Plan.** `code_lead` keeps `docs/architecture.md` current and writes `docs/plans/<version>/index.md` plus one plan per spec: small tasks in test-first order, each naming the spec rules it covers.
7. **Code.** Only after the user says "let's start coding X". The main chat makes the feature's branch (`git.md`). `code_lead` hands one task at a time to `builder` (`writing-handoffs` skill), which writes it test-first in `src/` and proves it works. `code_lead` reviews every task, except a small fix (`CLAUDE.md`, "Small jobs, few agents"). The main chat commits each one (`closing-a-task` skill).
8. **Build review.** `product_reviewer` (not the spec's writer) plays the feature like a regular player: whole sessions, the player's own controls only, computer and phone. Anything that hurts the player is a fail, even if no rule names it. Then it checks the spec, the idea and the business goals, and writes `docs/reviews/<feature>.md` with **accept** or **changes**. `game_creator` judges the first impression and business fit by playing it; `designer` checks the look. Changes go back to `builder`.
   **Gate 4: the user approves the built feature** (`closing-a-task` skill).

## Reviews

- Every review replies **approve** or **changes**, plus a numbered list.
- **Review rounds stop at 3.** After 3 rounds without approval, the main chat uses the `stop-and-step-back` skill (loop). This limit is for review rounds only.

## No open questions at a gate

Nothing reaches the user with open questions. Every question is answered by its owner first. A question that "can wait until after the playtest" still gets a decision now: a starting choice, plus the playtest result that would change it.

## Before any gate

The main chat asks both viral-test questions again (`viral-goal.md`) and re-reads every document as the user would (`docs.md`).
