# Lessons: Look and art

About how the game looks, the art and models, and approving a design. The map of all lessons is `docs/lessons/index.md`.

## Lesson 11: Judge the look next to the top games
- **What happened:** the first design (Sneak the Nest, 2026-10-11) had a near-empty world, a blob giant and thin, blank buttons, and still passed `designer`, `game_creator`, `product` and the main chat. "A beginner can build it" won over "it looks like a hit". All of it was thrown away.
- **Do instead:** every look is judged side by side with real gameplay screenshots of the top games (`references/top-games/`). "Simple to build" is never a reason to accept a plain look.
- **Who checks:** `designer`, `game_creator`, `product`, the main chat.

## Lesson 12: Every decision asks "could it go viral?"
- **What happened:** the main chat passed each approval along without asking the questions that mattered, and `product` wrote specs from the mockups as they were (2026-10-11). Asked afterwards, "Could it go viral looking like this?", the honest answer was "almost no chance".
- **Do instead:** every look or gameplay decision, review and relay of an approval answers the viral test (`.claude/rules/viral-goal.md`): "Could it go viral looking and feeling like this?" and "Would a kid pick ours over the top game next to it?" A "no" or "not sure" means changes, even if every rule passes.
- **Who checks:** every reviewer, the main chat.

## Lesson 13: Real art comes from the store and the generator
- **What happened:** the world was built from plain blocks. Tests showed free store models (trees, rocks, props) and Studio's model generator (`generate_mesh`) both give far better results with little work (2026-10-11).
- **Do instead:** use store models for scenery and the generator for our own characters and key objects. Pick store packs that match the style guide.
- **Who checks:** `designer`.

## Lesson 14: Generated models need waiting, checking and hinges
- **What happened:** the generator's normal call reported a time-out though the model still finished; one piece came out with a patchy texture; a moving piece turned the wrong way because its hinge point wasn't set (2026-10-11).
- **Do instead:** run the generator in the background and wait for the result. Look at every generated model and regenerate or retexture bad ones. Generate moving models in named pieces and set each piece's hinge point before moving it.
- **Who checks:** `designer`, `builder`.

## Lesson 57: Size a prop from its visible mesh, not the model's outer box
- **What happened:** for Task 48, designer sized the R-141 bush from the model's outer box (`GetBoundingBox`, 12.9 x 9 x 13). The round leaves inside were only 9.6 wide, and 4 to 5 studs wide near the ground, so the placed bush was too small to hide the box (2026-10-28, second failure on R-141).
- **Do instead:** size a prop from its visible mesh's width at the heights the gap needs, never from the model's outer box.
- **Who checks:** `designer`, `code_lead` (in the handoff).

## Lesson 70: Load a generated model by its asset id, never by a name search
- **What happened:** in Task 54 designer generated the brim tuft, then searched the world for it by the word "tuft". The search found the live meadow `Nature_GrassTuft` and moved it into the mockup folder. Two more Studio calls went to putting it back, so designer ran out of its 6 calls with no mockup and no shots (2026-10-28).
- **Do instead:** a mockup script loads a generated model only by its asset id, into its own mockup folder. It never moves or changes anything a world search finds. A mockup's first call makes the folder and loads the model, before anything else.
- **Who checks:** `designer`.
