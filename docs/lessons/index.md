# Lessons

What this project learned the hard way, so it doesn't happen again.

**How to use it.** Every agent reads this map before planning, writing a rule, placing an object or starting a task. It opens only the topic files whose lessons match the work, and follows them. A task or ruling that follows a lesson names it, for example "Lesson 2 (Change the scenery, not the giant)".

**How it grows.** Lessons come from the problems log (`docs/problems-log/index.md`), the health check (`scripts/health.py`) and the short look back when each task closes (`agent-workflow.md`, "Learning from experience"). The main chat writes them: the lesson goes into the topic file that fits, and gets one line in the table below. A lesson keeps its number forever. Merge lessons that say the same thing.

**Files by area, never by date.** One file per area of the project, feature or gameplay part, with the same names as the problems log's area files (`docs/problems-log/index.md`), so a problem and its lesson sit side by side. No file here goes over 1000 lines: when one nears the limit, split it into narrower areas and update the tables.

| Lesson | Short name | File |
|---|---|---|
| 1 | Scenery gets the cheap fix | `world-scenery.md` |
| 2 | Change the scenery, not the giant | `world-scenery.md` |
| 3 | Removing a synced folder crashes Rojo | `studio-and-scripts.md` |
| 4 | Never end a turn on a promise | `teamwork.md` |
| 5 | Don't ask owners about numbers players can't see | `teamwork.md` |
| 6 | Never pull the whole console into an agent's memory | `studio-and-scripts.md` |
| 7 | A Luau line can't start with "(" | `studio-and-scripts.md` |
| 8 | Checks that look straight down miss upright surfaces | `world-scenery.md` |
| 9 | Rank what matters before fixing the world | `world-scenery.md` |
| 10 | Check the safety net reaches the spot | `world-scenery.md` |
| 11 | Judge the look next to the top games | `look-and-art.md` |
| 12 | Every decision asks "could it go viral?" | `look-and-art.md` |
| 13 | Real art comes from the store and the generator | `look-and-art.md` |
| 14 | Generated models need waiting, checking and hinges | `look-and-art.md` |
| 15 | Search before guessing, and Bing works for images | `research-and-tools.md` |
| 16 | A new tool works only after a fresh start | `research-and-tools.md` |
| 17 | Don't install unknown tools | `research-and-tools.md` |
| 18 | Clean up after a test, and say what's left | `research-and-tools.md` |
| 19 | Sink scenery instead of fitting parts to it | `world-scenery.md` |
| 20 | Cap each builder step by tool calls | `teamwork.md` |
| 21 | Never start a walk, check or camera inside a mesh | `world-scenery.md` |
| 22 | Long Play work runs in the background | `studio-and-scripts.md` |
| 23 | A Studio script returns a short summary, never a list | `teamwork.md` |
| 24 | The handoff names the exact files and lines | `teamwork.md` |
| 25 | A hook enforces the memory limit, not a guess | `teamwork.md` |
| 26 | Try 5 examples before choosing a fix | `world-scenery.md` |
| 27 | Every task close compares the scan with the planned reds | `teamwork.md` |
| 28 | Each object's recorded places live in one module | `studio-and-scripts.md` |
| 29 | Fetch background work once, when it's done | `studio-and-scripts.md` |
| 30 | A new lesson rechecks the open tasks | `teamwork.md` |
| 31 | A background job reports as it goes | `studio-and-scripts.md` |
| 32 | The walk map can't see the walking band | `world-scenery.md` |
| 33 | A ruling names what each fix must leave alone | `teamwork.md` |
| 34 | Placing numbers are fixed, and each part gets its own try | `studio-and-scripts.md` |
| 35 | A fill's top is a new floor | `world-scenery.md` |
| 36 | Stand-in numbers name what replaces them | `teamwork.md` |
| 37 | A trial part must also pass the tests for its kind | `world-scenery.md` |
| 38 | A shared check is tested on the spots it will be used on | `world-scenery.md` |
| 39 | Count the list before sizing the task | `teamwork.md` |
| 40 | A job a later step reuses lives in a tested module | `studio-and-scripts.md` |
| 41 | One test filter per runner call, and check the suite count | `studio-and-scripts.md` |
| 42 | A job keeps slow results in `shared`, and takes data shapes from the server's own calls | `studio-and-scripts.md` |
| 43 | One "does a body fit here" check, or test the points directly (extended: job-check blocks any other fit test, and starts from `StartCheck.find`) | `world-scenery.md` |
| 44 | Check the sync with a free search before the first runner call | `studio-and-scripts.md` |
| 45 | A place a fix has filled is replayed from its own start | `world-scenery.md` |
| 46 | A Play job counts climbable parts and play time up front | `studio-and-scripts.md` |
| 47 | A start point has a floor under it | `world-scenery.md` |
| 48 | Check Rule 22 before suggesting the rescue | `world-scenery.md` |
| 49 | A test that places a blocker by a body's reach says which check it comes from | `studio-and-scripts.md` |
| 50 | When a real-world test turns red, read the part it checks first | `studio-and-scripts.md` |
| 51 | A full test run is fetched again, never started again | `studio-and-scripts.md` |
| 52 | `expect` takes one value | `studio-and-scripts.md` |
| 53 | A Play job matches labels by their first word, and counts every call | `studio-and-scripts.md` |
| 54 | A check that finds nothing shows its closest case | `studio-and-scripts.md` |
| 55 | A part goes in the script that owns its folder | `world-scenery.md` |
| 56 | A fill next to a slanted wall turns to follow it | `world-scenery.md` |
| 57 | Size a prop from its visible mesh, not the model's outer box | `look-and-art.md` |
| 58 | A world script says how many parts it will add before it adds them | `world-scenery.md` |
| 59 | A handoff that names a job's walk points to the lines that do it (extended: seeds come from measured positions) | `teamwork.md` |
| 60 | A plan counts Studio calls for every step | `teamwork.md` |
| 61 | A handoff's world names are checked before the builder starts (extended: a part not built yet gets its spec position) | `teamwork.md` |
| 62 | A saved walk map goes stale when the world changes | `studio-and-scripts.md` |
| 63 | A big job is pasted by a builder with room to spare (extended: the joined check ignores join-only warnings) | `studio-and-scripts.md` |
| 64 | A job's walk map holds every place it measures | `studio-and-scripts.md` |
| 65 | A dry check call comes before the long Play run | `studio-and-scripts.md` |
| 66 | Job scripts in work/ pass the type check with a require cast | `studio-and-scripts.md` |
| 67 | A gap proof aims the camera across the gap | `world-scenery.md` |
| 68 | A task's close clears its own shared keys | `studio-and-scripts.md` |
| 69 | Only a walk-out decides "got out" | `world-scenery.md` |
| 70 | Load a generated model by its asset id, never by a name search | `look-and-art.md` |
| 71 | A check passes on the unchanged world before it judges a trial | `studio-and-scripts.md` |
| 72 | Map the whole gap before designing a fill | `world-scenery.md` |
| 73 | The hook counts an agent's tool calls, not the agent | `studio-and-scripts.md` |
| 74 | A Studio script requires a tools module through a clone (also the ready-made run scripts) | `studio-and-scripts.md` |
| 75 | Re-check a start from the point it was found from | `studio-and-scripts.md` |
| 76 | A job script is checked in the shell before its first paste | `studio-and-scripts.md` |
| 77 | A start meant to be inside a gap is checked to be under its roof | `world-scenery.md` |
| 78 | A measure's shapes come from saved measurements, and every dependent test is scored | `world-scenery.md` |
| 79 | Every stop prints the check that fired and its own failure | `studio-and-scripts.md` |
| 80 | A job never picks a part by a search; the handoff names it | `studio-and-scripts.md` |
| 81 | A look check measures where the client draws, with the client's own ray | `studio-and-scripts.md` |
| 82 | Set the phone in Edit, and take a "keeps X" shot before another rule can remove X | `studio-and-scripts.md` |
| 83 | Spacing points out by flat distance merges edges stacked at different heights | `world-scenery.md` |
| 84 | A job stops only on a lost or broken input, never on a cross-check count | `studio-and-scripts.md` |
| 85 | A press that waits for a landing stops at touchdown, and every fail line says why | `studio-and-scripts.md` |
| 86 | A walk job measures what the body really did, never what the plan expected | `studio-and-scripts.md` |
| 87 | Prove a check ran, and fetch only what is saved | `studio-and-scripts.md` |
| 88 | A test helper can't pass nil through a loop | `studio-and-scripts.md` |
| 89 | A step's reading fits inside its cap | `teamwork.md` |
| 90 | Edit mode never fires Died | `studio-and-scripts.md` |
| 91 | A Studio job gets its own copy of a module | `studio-and-scripts.md` |
| 92 | Set the phone device before its orientation | `studio-and-scripts.md` |
| 93 | Look up every property a job sets | `studio-and-scripts.md` |
| 94 | A "nothing happened" check also proves something was tried | `studio-and-scripts.md` |
| 95 | A job finds what the game makes through the game's own lookup | `studio-and-scripts.md` |
| 96 | Press a button where the new and old results differ | `studio-and-scripts.md` |
| 97 | The task that builds a look checks it in Play | `teamwork.md` |
| 98 | Each shared place word is defined once | `teamwork.md` |
| 99 | Writing a Play job is a step of its own | `teamwork.md` |
| 100 | Set a proof's tries by how much the spot matters | `teamwork.md` |
| 101 | Tests run red before any code is written | `studio-and-scripts.md` |
| 102 | Pass in the lookup when a property is read-only | `studio-and-scripts.md` |
| 103 | The memory hook always lets the report through | `teamwork.md` |
| 104 | Write job text with backtick strings | `studio-and-scripts.md` |
| 105 | Measure the place, or quote the newest ruling | `teamwork.md` |
| 106 | A grab step checks the prompt is really shown | `studio-and-scripts.md` |
| 107 | Every whole-session proof grabs after a real respawn | `teamwork.md` |
| 108 | A silent-meter check runs with and without an egg | `studio-and-scripts.md` |
| 109 | A Play job reads the game's own signal and stops input when it fires | `studio-and-scripts.md` |
| 110 | Compare feet with feet | `studio-and-scripts.md` |
| 111 | Listen to changes with times, don't poll afterwards | `studio-and-scripts.md` |
| 112 | Decide from the numbers when the timing makes the result certain | `teamwork.md` |
| 113 | Every size counts the Studio calls of its test runs | `teamwork.md` |
| 114 | Carry an egg home into the garden box, not onto the spawn spot | `studio-and-scripts.md` |
| 115 | Don't start a test name with "picks the" | `teamwork.md` |
| 116 | Start a timed action from a signal inside the key call | `studio-and-scripts.md` |
| 117 | Measure "stands still" along the ground | `studio-and-scripts.md` |
| 118 | A job prints its own proof of a fail | `studio-and-scripts.md` |
| 119 | A handoff writes each Studio call with its service | `studio-and-scripts.md` |
| 120 | Every Play step starts with a dry start (extended: "proven" means it held in one, and only the main proof's starts stop it) | `studio-and-scripts.md` |
| 121 | Judge "held still" and "silent" only once the body has settled | `studio-and-scripts.md` |
| 122 | A move's grace lasts until the body is on the ground and still | `studio-and-scripts.md` |
| 123 | A Play job always judges a rescue that happens | `studio-and-scripts.md` |
| 124 | A job that carries an egg grabs from a held start and prints why the egg left | `studio-and-scripts.md` |

| File | What it covers |
|---|---|
| `world-scenery.md` | Placing, fitting or fixing objects in the world, and checks that measure them |
| `studio-and-scripts.md` | Deleting files, reading output, and writing scripts for Studio |
| `teamwork.md` | Handing work between agents and asking owners |
| `look-and-art.md` | How the game looks, art and models, and approving a design |
| `research-and-tools.md` | Searching the web, reference pictures, and adding or trying tools |
