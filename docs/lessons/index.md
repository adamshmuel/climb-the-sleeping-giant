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
| 125 | A start's slope limit is the stand-still limit, not the walk-up limit | `world-scenery.md` |
| 126 | Mute in the game, never the Mac | `studio-and-scripts.md` |
| 127 | Check every start again after a start-check change | `studio-and-scripts.md` |
| 128 | Measure "home" against the spawn spot, not a box near it | `studio-and-scripts.md` |
| 129 | Fakes must spawn bodies in the engine's order | `studio-and-scripts.md` |
| 130 | Re-prove only what failed | `studio-and-scripts.md` |
| 131 | Measure a move right after a spawn before the first fix | `studio-and-scripts.md` |
| 132 | A red step needs Studio, and a full run goes to the runner | `teamwork.md` |
| 133 | Compare decimal settings as "close", never "exactly" | `studio-and-scripts.md` |
| 134 | Studio's console never shows an analytics event's name or values | `studio-and-scripts.md` |
| 135 | A red pass rule quotes the real error and counts the failures | `studio-and-scripts.md` |
| 136 | A Play job with a pause for every shot is planned in two parts | `studio-and-scripts.md` |
| 137 | A rounded number is checked over a span, never tick against tick | `studio-and-scripts.md` |
| 138 | A Play job holds a prompt only after the game shows it | `studio-and-scripts.md` |
| 139 | A grab job faces the prompt before it holds | `studio-and-scripts.md` |
| 140 | A probe records whether a prompt is shown right now | `studio-and-scripts.md` |
| 141 | A shot camera looks at the prompt from the side | `studio-and-scripts.md` |
| 142 | A review's first-minute play and its must-shows get separate budgets | `teamwork.md` |
| 143 | Screenshots don't draw always-on-top billboards | `studio-and-scripts.md` |
| 144 | A job that reuses a shared check prints why it refused | `studio-and-scripts.md` |
| 145 | A phone review part holds at most 3 checks | `teamwork.md` |
| 146 | A Play proof recreates the bug shot's camera | `studio-and-scripts.md` |
| 147 | A test on a pixel line works its numbers out from the line | `studio-and-scripts.md` |
| 148 | A Play step's camera is worked out from the screen point it must give | `studio-and-scripts.md` |
| 149 | A phone press is aimed from the game point, and its landing is checked | `studio-and-scripts.md` |
| 150 | A pill beside the egg is aimed from the egg, or pinned first | `studio-and-scripts.md` |
| 151 | A full-run pass line names only what the fetch prints | `studio-and-scripts.md` |
| 152 | The always-on-top flip is for shots only, never before a touch hold | `studio-and-scripts.md` |
| 153 | A ladder's climbable part is as wide as the ladder the player sees | `world-scenery.md` |
| 154 | A handoff that grows a job file near 300 lines plans its split first | `studio-and-scripts.md` |
| 155 | The fetch names every failure first | `studio-and-scripts.md` |
| 156 | Play the off-angle climb before cutting a ladder's guide | `world-scenery.md` |
| 157 | A part pasted with the one before it is linted with it | `studio-and-scripts.md` |
| 158 | Write a full-run pass line with no quote marks | `studio-and-scripts.md` |
| 159 | After one failed fix, measure the cause before another shape | `world-scenery.md` |
| 160 | Play a "miss is cheap" safety net with real controls before lowering a bar | `world-scenery.md` |
| 161 | Measure the default behaviour in a bare test yard before changing a shape | `world-scenery.md` |
| 162 | Place a copied model by its bounding box, and check it before the shot | `look-and-art.md` |
| 163 | A runner copies file paths from its prompt, never from memory | `teamwork.md` |
| 164 | The 300-line job cap is for work/ jobs, not world scripts | `studio-and-scripts.md` |
| 165 | A names check prints each copied template's shape | `studio-and-scripts.md` |
| 166 | A world script checks itself read-only before its first Play paste | `studio-and-scripts.md` |
| 167 | A Play restart that pastes a big file gets a fresh agent | `teamwork.md` |
| 168 | A noise trial waits for a calm meter before each measure | `studio-and-scripts.md` |
| 169 | A fetch reads the same `shared.` name its job writes | `studio-and-scripts.md` |
| 170 | A noise trial watches the meter for 3 s after the player stands still | `studio-and-scripts.md` |
| 171 | A fall caught by a ladder is not a fall | `studio-and-scripts.md` |
| 172 | Putting a task's code back also puts its world back | `studio-and-scripts.md` |
| 173 | A ruling on how a job measures reads the job's own lines first | `teamwork.md` |
| 174 | A job script is pasted as written, comment lines aside | `studio-and-scripts.md` |
| 175 | Count the files a step edits before sizing it | `teamwork.md` |
| 176 | A design table's sizes follow the part's own size rules | `world-scenery.md` |
| 177 | A run report lists every failed name before any message | `studio-and-scripts.md` |
| 178 | A script is pasted as the text of one Studio call, never loaded from elsewhere | `studio-and-scripts.md` |
| 179 | A design names a prop by its art-list entry and asset id, checked in a shot | `world-scenery.md` |
| 180 | Moving a route point checks every link from it | `world-scenery.md` |
| 181 | Judge a shot only with what this version spawns | `look-and-art.md` |
| 182 | A run report pages every failed name and keeps its results until the end | `studio-and-scripts.md` |
| 183 | Check the sync of a script whose name has a dot with script_grep | `studio-and-scripts.md` |
| 184 | A shape change looks for the old shape's directions too, not only its part names | `world-scenery.md` |
| 185 | The runner reads a script before its Studio call, and never sends a placeholder | `studio-and-scripts.md` |
| 186 | A measure job keeps the whole message of the one test it needs | `studio-and-scripts.md` |
| 187 | Fill a stuck pocket with a solid block, never a thin board | `world-scenery.md` |
| 188 | A red run filters to the step's own tests, and its cap counts every page | `studio-and-scripts.md` |
| 189 | A cut failure message hides the next offender | `studio-and-scripts.md` |
| 190 | Run a world script by requiring its synced copy, never by pasting it | `studio-and-scripts.md` |
| 191 | Scan the skin under a wide object before naming its spot | `world-scenery.md` |
| 192 | Write "checked in Task N" for a later task's proof | `teamwork.md` |
| 193 | Name the later spec that reshapes each part, and give the plan a time budget | `teamwork.md` |
| 194 | Before adding anything to the main character, ask if it must be there, and judge it from the wide view | `look-and-art.md` |
| 195 | A world script that removes parts saves a copy of them first | `studio-and-scripts.md` |
| 196 | "Go back" is an idea to test, not a safe default | `teamwork.md` |
| 197 | Judge a way up to a main character's head as one line, foot to top | `look-and-art.md` |
| 198 | Start a placement ruling with what sits at the top and who needs it | `teamwork.md` |
| 199 | When a part on a main character is questioned, question what pulls players there too | `teamwork.md` |
| 200 | Four agents agreeing is not a check; ask what nobody tried | `teamwork.md` |
| 201 | A fairness check names where the ways up join | `teamwork.md` |
| 202 | Judge a one-sided route on the trip there and the trip home | `teamwork.md` |
| 203 | Judge every way up from every garden camera and the way home | `look-and-art.md` |
| 204 | Show both options as mockups before choosing between them | `teamwork.md` |
| 205 | Write test names in a Pass line without quote marks | `studio-and-scripts.md` |
| 206 | The shot steps say how to hold the camera in Play | `look-and-art.md` |
| 207 | Putting back is placing | `teamwork.md` |
| 208 | Split a world-script step by layer before ordering it | `teamwork.md` |
| 209 | A task ends at its own goal | `teamwork.md` |
| 210 | Agents ordered work by excuses until one checklist banned them | `teamwork.md` |
| 211 | A "Stands on:" line can't name a decision that is still open | `teamwork.md` |
| 212 | A Studio step with no spare call can't absorb one failed call | `teamwork.md` |
| 213 | Routes laid across a main character's face hide his charm | `look-and-art.md` |
| 214 | Job-script checks don't fit spec files | `teamwork.md` |
| 215 | A red world test can come from an old drift, not the newest change | `teamwork.md` |
| 216 | Check the front view first when placing near a main character's head | `look-and-art.md` |
| 217 | Every option in a side-by-side gets the same cameras | `look-and-art.md` |
| 218 | Check a placement mockup against the idea's own words | `look-and-art.md` |
| 219 | Measure a body part's edges before placing next to it | `look-and-art.md` |
| 220 | Measure a disputed fact before weighing two rulings | `teamwork.md` |
| 221 | A placement list gives measured spots, or says "measure first" | `look-and-art.md` |
| 222 | Give a walk bot measured waypoints, and start spots that have a floor | `studio-and-scripts.md` |
| 223 | A job script's background loop stops on a flag, and a walk script sets the real walk speed | `studio-and-scripts.md` |
| 224 | Walk tests on the giant hold the sleep meter at 0 and log any move the game makes | `studio-and-scripts.md` |
| 225 | Smoke-run the first case of a Play job before the job runs | `studio-and-scripts.md` |
| 226 | Test movement only on the real build, and build one side first | `studio-and-scripts.md` |
| 227 | Route a look along the visible surface, not an invisible guard part | `look-and-art.md` |
| 228 | In scripts, put a type cast in a local variable, never at the start of a line | `studio-and-scripts.md` |
| 229 | Test a climb that isn't a truss in the sky first, next to a truss | `world-scenery.md` |
| 230 | Every climb that isn't one truss needs a PathCheck change | `world-scenery.md` |
| 231 | A sky copy covers the whole path, and the push stops at the goal | `world-scenery.md` |
| 232 | A sky copy is in the meadow zone, so its meter hears nothing | `world-scenery.md` |
| 233 | A shadow meter names each case, not each teleport | `world-scenery.md` |
| 234 | Compare where every case lets go before judging the ends | `world-scenery.md` |
| 235 | A climb probe includes a player who freezes | `world-scenery.md` |
| 236 | Put a landing under where climbers really stand at the top | `world-scenery.md` |
| 237 | Check every stretch of a bent climb against both limits | `world-scenery.md` |
| 238 | Shape a hidden climb to the engine's limits, not to the look | `world-scenery.md` |
| 239 | Every climb probe includes a climb down | `world-scenery.md` |
| 240 | A hidden climb catches nobody walking off facing out | `world-scenery.md` |
| 241 | Measure each limit only over the zone its pass line names | `studio-and-scripts.md` |
| 242 | Say what each pass line judges, before the run | `world-scenery.md` |
| 243 | Gate a way up against the player journey the specs already decided | `world-scenery.md` |
| 244 | Test the bare shape of a way up against every player move before dressing it | `look-and-art.md` |
| 245 | Measure one surface with rays filtered to that part | `world-scenery.md` |
| 246 | A quiet fall judged by where it ends can become a shortcut | `world-scenery.md` |
| 247 | A task that changes the world ends with a full run before its accepted reds are final | `studio-and-scripts.md` |
| 248 | A rule that quiets some climbs names the parts it covers, not only the zones | `studio-and-scripts.md` |
| 249 | A look-only part can't be found by rays, so tests measure it from its shape | `studio-and-scripts.md` |
| 250 | Before naming a world script as a fix, match what the test reads with what the script writes | `studio-and-scripts.md` |
| 251 | A fix for a red test covers every kind of object the test checks | `studio-and-scripts.md` |
| 252 | Check a job's scripts as script files, not its written page | `studio-and-scripts.md` |
| 253 | A rescue can end a climb case on the goal without a climb | `studio-and-scripts.md` |
| 254 | The smoke run runs every script of the job once | `studio-and-scripts.md` |
| 255 | Compare two sides of a slope at the same spot, with the added part left out | `studio-and-scripts.md` |
| 256 | Set the push angles and walk-across paths a climb must survive before building it | `world-scenery.md` |
| 257 | Scan every seam along a climb route before a climb Play job | `world-scenery.md` |
| 258 | A mockup piece players walk on states its biggest step | `look-and-art.md` |
| 259 | Build a hidden climb from as few kinds of piece as it can, and push-test every joint | `world-scenery.md` |
| 260 | A second Play round on the same task starts "Stuck on one problem" | `teamwork.md` |
| 261 | Measure each corner a fix rests on with a ray | `world-scenery.md` |
| 262 | A walkable slab on a slope steps up by its thickness over the cosine | `world-scenery.md` |
| 263 | A spec limit names what the player feels, not a stand-in | `teamwork.md` |
| 264 | Read a tool's real limit in its code before a lesson relies on it | `studio-and-scripts.md` |
| 265 | Prove a player can walk to a way up before building the way up | `teamwork.md` |
| 266 | Every red flag lists the smallest keep-what's-built piece first | `teamwork.md` |
| 267 | A Play climb job steers like a player when it stalls | `studio-and-scripts.md` |
| 268 | Check the docs before naming an engine limit to the user | `teamwork.md` |
| 269 | A climber can't swivel round a truss with the stick | `studio-and-scripts.md` |
| 270 | Check a stuck spot on the real world with the rescue running | `world-scenery.md` |
| 271 | Scan behind every side of a climb before a climb test | `world-scenery.md` |
| 272 | Run `date` before writing any time in a log | `teamwork.md` |
| 273 | Hold a scripted camera every frame until the shot | `look-and-art.md` |
| 274 | Measure the shortest crossing before pricing a new route | `world-scenery.md` |
| 275 | Start each down-ray just above the line being measured | `world-scenery.md` |
| 276 | Each walk case starts standing on the ground | `studio-and-scripts.md` |
| 277 | List every mirrored line before reusing a walk script | `studio-and-scripts.md` |
| 278 | Price a task from the plan and the progress file, and use the larger | `teamwork.md` |
| 279 | Measure the surface under a handed-over spot | `world-scenery.md` |
| 280 | A scripted press uses the walk's own input | `studio-and-scripts.md` |
| 281 | Test a climb at the angles players really arrive from | `world-scenery.md` |
| 282 | Keys push in 45° steps, so test climbs at ±20° and ±25° | `world-scenery.md` |
| 283 | A server watcher gets its case marks through a RemoteEvent | `studio-and-scripts.md` |
| 284 | Measure gaps to meshes with raycasts | `studio-and-scripts.md` |
| 285 | Stall steering turns toward the open face | `studio-and-scripts.md` |
| 286 | Mark "between" and settle before each teleport | `studio-and-scripts.md` |
| 287 | One sleep-meter hold per Play session, with a heartbeat | `studio-and-scripts.md` |
| 288 | Run luau-lsp and a dry run in Edit before a trial script's first paste | `studio-and-scripts.md` |
| 289 | A path that ends at a climb shows its arrival heading | `look-and-art.md` |
| 290 | List each result and the pick it leads to before a trial | `teamwork.md` |
| 291 | Price the safety net before chasing "every try works" | `teamwork.md` |
| 292 | Check a case's last safe spot matches a real player's | `teamwork.md` |
| 293 | Count only real rules before flagging a spec split | `teamwork.md` |
| 294 | A names check marks which names exist only in Play | `studio-and-scripts.md` |
| 295 | A stall with no measured cause gets a trace step first | `studio-and-scripts.md` |
| 296 | Keep job scripts short from the start | `studio-and-scripts.md` |
| 297 | A Play trace retries like a player and shows the stall | `studio-and-scripts.md` |
| 298 | A task review checks git for the files it depends on | `teamwork.md` |
| 299 | When a design pick replaces what a plan fixes, re-plan it | `teamwork.md` |
| 300 | Check the spec's proof list before planning a proof task | `teamwork.md` |
| 301 | A fixed camera moves to another task, never out | `teamwork.md` |
| 302 | A trimmed paste voids that call | `studio-and-scripts.md` |
| 303 | Every promise in a task header has a budgeted step | `teamwork.md` |
| 304 | Use the game's own signal, and size job files before the step | `studio-and-scripts.md` |
| 305 | One Play case per behaviour the player feels | `teamwork.md` |
| 306 | A Play job's memory is mostly its pastes | `studio-and-scripts.md` |
| 307 | Measure the floor under a Play case's path, and end it like a player | `studio-and-scripts.md` |
| 308 | Rule on a Play result from its own lines | `teamwork.md` |
| 309 | Release the stick on the game's state, and aim every retry at what the case climbs | `studio-and-scripts.md` |
| 310 | Write each pass word as the game's own value, and name a spot after the part its ray hit | `studio-and-scripts.md` |
| 311 | A push away from a Roblox ladder climbs down; trace one let-go before rewriting a climbing job | `studio-and-scripts.md` |
| 312 | A Play case on a spot a later task builds over belongs to that task | `teamwork.md` |
| 313 | Budget a full run from the last run's page count | `studio-and-scripts.md` |
| 314 | A shot step names the camera method that works | `studio-and-scripts.md` |
| 315 | Measure what a check's ray hits before ruling it onto a new kind of piece | `studio-and-scripts.md` |
| 316 | Measure both sides of the body before mirroring a fitted part | `look-and-art.md` |
| 317 | Run a check on the built twin before making it a pass item | `teamwork.md` |
| 318 | When a check is skipped, drop the setup only it used | `teamwork.md` |
| 319 | Budget script-writing steps per script, and look parts up from their model | `teamwork.md` |
| 320 | Shots repeat, so the shot method is a ready-made job | `teamwork.md` |
| 321 | A red run's report grows with its failures | `studio-and-scripts.md` |
| 322 | StyLua makes a job file longer than you wrote it | `studio-and-scripts.md` |
| 323 | Build each paste from the file's text, never retype a line | `studio-and-scripts.md` |
| 324 | Read a task's progress row before ordering work against it | `teamwork.md` |
| 325 | A look job checks each new shot against its before shot | `look-and-art.md` |
| 326 | A task that adds visible parts takes its look check before approval | `teamwork.md` |
| 327 | What a decision calls "untried" is tried before the build | `teamwork.md` |
| 328 | A Studio cap is the count of a numbered call list | `teamwork.md` |
| 329 | Check a part's outline from the camera before restyling it | `look-and-art.md` |
| 330 | Parts beside a walk floor are judged from the player's spot | `look-and-art.md` |
| 331 | A feet proof is shot from behind the player | `look-and-art.md` |
| 332 | Play ignores a camera set once; bind it every frame | `studio-and-scripts.md` |
| 333 | Check a spot's reach right before its piece, not up front | `teamwork.md` |
| 334 | Measure the ground under every planned end | `world-scenery.md` |
| 335 | A deck's fit check scans its whole width | `world-scenery.md` |
| 336 | Show the first piece of a new way up before building the second | `teamwork.md` |
| 337 | Set walk limits from the measured route | `world-scenery.md` |
| 338 | Check both sides of a mirrored view | `look-and-art.md` |
| 339 | Check the folder before naming a new world script | `studio-and-scripts.md` |

| File | What it covers |
|---|---|
| `world-scenery.md` | Placing, fitting or fixing objects in the world, and checks that measure them |
| `studio-and-scripts.md` | Deleting files, reading output, and writing scripts for Studio |
| `teamwork.md` | Handing work between agents and asking owners |
| `look-and-art.md` | How the game looks, art and models, and approving a design |
| `research-and-tools.md` | Searching the web, reference pictures, and adding or trying tools |
