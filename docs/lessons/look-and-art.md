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

## Lesson 162: Place a copied model by its bounding box, and check it before the shot
- **What happened:** in Task 58b's upright-ladder mockup, designer copied the nest and the Dream Egg and placed them by their pivot point. They landed in the wrong spot, so no shot showed them and their place was given by numbers only (2026-11-01).
- **Do instead:** place a copied model by its bounding box (`GetBoundingBox`), and print its real position before taking the screenshot.
- **Who checks:** `designer`.

## Lesson 181: Judge a shot only with what this version spawns
- **What happened:** in Task 58b Step 5b, the look check put a Rare egg in the nose nest as a stand-in for the Dream Egg, which doesn't spawn until a later version. The egg hid the cap ladder's lowest rungs, and two builds failed on it before anyone noticed no egg spawns there in V2. The library nest was also stored hidden (Transparency 1), so the copy was invisible (2026-11-02).
- **Do instead:** judge a shot only with what the version really spawns. If a stand-in is needed, name the version it belongs to and judge it as that version's check. Check a copied library model's Transparency before the shot.
- **Who checks:** `designer` (when it writes the look check), `code_lead` (in the handoff).

## Lesson 194: Before adding anything to the main character, ask if it must be there, and judge it from the wide view
- **What happened:** in Tasks 58b and 58e the face ladders were made upright, then a foot ledge, brace and white fill blocks were added, each fixing the last. Every step was judged from close cameras and safety numbers. Nobody shot old against new from the spawn or on a phone, and nobody asked whether a ladder belonged on the face at all. The giant's face, the game's hook, ended up hidden behind a ladder and white walls, and Adam saw it first (2026-11-02).
- **Do instead:** before ruling on or adding any part on a main character, first ask whether it can go somewhere else or be left out. Then judge it old against new from the fixed wide and phone cameras (`agent-workflow.md`, "Before and after"), and never stack another fix on a change that hasn't passed that check.
- **Who checks:** `designer` (the look), `game_creator` and `product` (rulings that place things on a main character).

## Lesson 197: Judge a way up to a main character's head as one line, foot to top
- **What happened:** the face route was judged in halves (the beard climb, the forehead strip). Each half looked fixable on its own, but the whole route still crossed the giant's face (red alert round 3, 2026-11-02).
- **Do instead:** draw the whole way up to a main character's head as one line from its foot to its top, on the fixed wide and phone shots, before pricing any part of it.
- **Who checks:** `designer` (placing ways up), `product` and `game_creator` (choosing a route).

## Lesson 203: Judge every way up from every garden camera and the way home
- **What happened:** round 3 judged the way up only from the front cameras, so nobody saw that half the gardens couldn't see the single ear ladder (designer, red alert round 4, 2026-11-02).
- **Do instead:** judge every way up from all 8 garden gate cameras and along the way home, not only from the first view.

## Lesson 206: The shot steps say how to hold the camera in Play
- **What happened:** Task 60 Step 1 (phone before shots, 2026-11-02) went 6 calls over its cap. A one-time `CameraType = Scriptable` and CFrame set doesn't hold in Play, because the game's camera script puts it back, and `SetOrientationAsync` errors when no device is set. The builder found the fix by trial.
- **Do instead:** every shot step quotes the method: set the phone device in Edit before Play, then the orientation; in Play, hold the camera with a RenderStepped loop run from `execute_luau` (it ends when Play stops). Shots are 1210x558 from the built-in iPhone 14, landscape, FOV 70.
- **Who checks:** `code_lead` (shot steps in handoffs), `designer` (`look-cameras.md`).

## Lesson 213: Routes laid across a main character's face hide his charm
- **What happened:** the beard and cap ladders crossed the giant's face and stuck up above his cap in the first view. When they came off, the designer judged all 10 before-and-after pairs "better": his nose, eyes, moustache and beard tuft show again (Task 60, 2026-11-02).
- **Do instead:** put routes beside a main character's face, never across it, and check the first view from the front before building.

## Lesson 216: Check the front view first when placing near a main character's head
- **What happened:** in the ear-ladder mockups, a ladder only 5 studs in front of the ear looked like lines on the giant's face from the meadow camera. The designer moved it back and took the shots again (2026-11-02).
- **Do instead:** right after placing anything near a main character's head, take one meadow-front shot before any other shot.

## Lesson 217: Every option in a side-by-side gets the same cameras
- **What happened:** in the ear-ladder mockups, options A and B were shot from the side gardens and the face camera, but the new option C only from the first view and close up. game_creator could not judge C against the others and asked for the missing shots (2026-11-02).
- **Do instead:** shoot every option, including one added late, from the same fixed cameras on computer and phone before anyone judges them.

## Lesson 218: Check a placement mockup against the idea's own words
- **What happened:** the ear-ladder mockups put the climbing line between the giant's cheek and his ear, but the idea file says "behind each ear". Nobody checked the two against each other before judging (2026-11-02).
- **Do instead:** before judging a placement mockup, check its line against the idea's "What matters most" row for that part.

## Lesson 219: Measure a body part's edges before placing next to it
- **What happened:** the judges asked to move the cap ties "about 6 studs back" behind the giant's ear. The real ear runs from z 19 to z 30, so 6 studs put the tie right over it. It took 18 studs (2026-11-02).
- **Do instead:** before placing anything near a body part, measure its edges with raycasts, and give placement asks as measured spots, not guesses.

## Lesson 221: A placement list gives measured spots, or says "measure first"
- **What happened:** the designer's list put the tie's top landing at "about y 104". The cap there is 3.7 studs higher, so the fold would have sat inside a dip. The designer measured and raised it. It was the second guessed spot in one day, after Lesson 219 (2026-11-02).
- **Do instead:** whoever writes a placement list measures each spot first, or writes "measure first". The rule is now in `agent-workflow.md`, "Fewer round trips".

## Lesson 227: Route a look along the visible surface, not an invisible guard part
- **What happened:** the cap-tie climb test read "the cap's side" from a ray hit, but the part hit was `CapSideLeft_28`, an invisible guard plate up to 7 studs outside the visible cap. A tie routed along the plates framed his face with striped poles from the front, which looked worse (2026-11-02).
- **Do instead:** before routing anything along a character, check whether each hit part is visible. Leave guard and collision-only parts out of the look route, and list the ones the new part must replace.

## Lesson 244: Test the bare shape of a way up against every player move before dressing it

In Task 61a, the cap tie's look was designed first. Then each gate found a player move it failed: a freeze, a push off the line, a climb down facing out. Each one cost a new round.

**Do instead:** before mocking up any way up, list every player move on it (up, freeze, off the line, down facing in and facing out, jump off). Test the bare shape against all of them in one sky test, then dress it.

## Lesson 258: A mockup piece players walk on states its biggest step

In Task 61a the mockup's fold on his cap was judged only from the camera. It tilted about 20 degrees on a cap that tilts about 43, so one edge stood 2 studs off the cap. Walking across it made a full thud.

**Do instead:** every mockup piece players will walk on states its biggest step to the surface around it (0.5 studs or less), measured in Studio before the mockup is handed over.

## Lesson 273: Hold a scripted camera every frame until the shot

A scriptable camera set once in Play was reset by the game's camera before the shot was taken.

**Do instead:** hold the camera with BindToRenderStep at a priority after Enum.RenderPriority.Last until the shot is taken, then unbind it.

## Lesson 289: A path that ends at a climb shows its arrival heading

The walkway's mockup showed where it ends, but not which way a player faces when he gets to the tie.

**Do instead:** a path that ends at a climb shows its measured arrival heading inside the climb's clear angles in the mockup. Movement is tested only on the built piece, with player-like steering.

## Lesson 316: Measure both sides of the body before mirroring a fitted part
- **What happened:** Task 61b built the right cap tie as an exact mirror of the left. The giant's nightcap is up to 0.34 studs wider on the right, so two CapTies tests failed (head gap, landing height) and a third would have. That cost a measuring round and a refit pass.
- **Do instead:** before mirroring a part fitted to a body, measure both sides of that body in one read-only call, and write the differences into the per-side table before the build step.

## Lesson 325: A look job checks each new shot against its before shot
- **What happened:** In Task 61x the after shot for gate 8 on computer repeated the gate 1 view. The designer could not judge that pair, so the look check had a gap.
- **Do instead:** a look-shots job compares each new shot with its before shot and flags any pair where most of the picture changed. A flagged pair is taken again before the designer judges.
