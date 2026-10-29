#!/usr/bin/env bash
# Checks for Studio job scripts in work/ before their first paste.
# Three Task 54 Studio calls were lost to job scripts that stopped before
# judging anything (Lesson 76). This catches the mistakes a shell can see.
# Usage: scripts/job-check.sh work/t54/server-p.luau [more files]
# A handoff is checked with --handoff work/handoff-x.md (Lesson 80).
# A job split into parts (Lesson 63) is checked with --joined part-a part-b:
# each part's size, then every other check on the parts joined in paste order.
set -uo pipefail
# Paths are made absolute before the cd, so a file name given from any
# folder works (Task 8c: "server.luau" from scripts/bot-walk failed).
args=()
for a in "$@"; do
	if [ -e "$a" ]; then
		args+=("$(cd "$(dirname "$a")" && pwd)/$(basename "$a")")
	elif [[ "$a" == --* ]]; then
		args+=("$a")
	else
		# A missing file once made the --joined check pass on an empty job.
		echo "Job check FAILED: $a does not exist (give a path from this folder)."
		exit 1
	fi
done
set -- "${args[@]}"
cd "$(dirname "$0")/.."
export PATH="$HOME/.rokit/bin:$PATH"
if [ "${1:-}" = "--handoff" ]; then
	# A part a job picks by a search at paste time is first seen by the
	# paste (Task 7 step 2, Lesson 80). Every pick is made in code_lead's
	# names-check call, and the handoff names the part by path or position.
	shift
	# A pick that can only happen in Play (for example, the landing spot
	# nearest where the player landed) is marked "(runtime pick)" on its line.
	pick='\b(nearest|finds? (it|them) by|picks? the|whichever)\b'
	named='(Workspace|World|ServerStorage|ReplicatedStorage)\.[A-Za-z_]|\(-?[0-9.]+, *-?[0-9.]+, *-?[0-9.]+\)|\(runtime pick\)|search "'
	found=$(grep -nEi "$pick" "$@" | grep -vE "$named")
	if [ -n "$found" ]; then
		echo "$found"
		echo "Handoff check FAILED: each line above picks a part by a rule with no path or position."
		echo "Run the pick in the names-check call and name the part (Lesson 80)."
		exit 1
	fi
	# A stop on a cross-check count that nothing reads (Task 7c call 1, Task 8b
	# slot 3) cost calls twice (Lesson 84). A job stops only when an input is
	# lost or broken; such a line is marked "(lost input)".
	match='(must|don.t|do not|doesn.t|not) match|match(es)? slot|differ(s)? from slot'
	stops=$(grep -nEi "$match" "$@" | grep -Ei 'FIRED|stop' | grep -v '(lost input)')
	if [ -n "$stops" ]; then
		echo "$stops"
		echo "Handoff check FAILED: each line above stops a job on a measured count."
		echo "Print cross-check counts; stop only on a lost or broken input, marked \"(lost input)\" (Lesson 84)."
		exit 1
	fi
	# Each step runs on the cheapest model that can do it (agent-workflow.md,
	# "Model per job"), so every step heading names one.
	nomodel=$(grep -nE '^## Step [0-9]' "$@" | grep -viE '\b(haiku|sonnet|opus)\b')
	if [ -n "$nomodel" ]; then
		echo "$nomodel"
		echo "Handoff check FAILED: each step heading above names no model (Haiku, Sonnet or Opus)."
		echo "Pick it from agent-workflow.md, \"Model per job\"."
		exit 1
	fi
	# A start taken from an Edit-time probe can float in the air or sit on a
	# slope (Task 12b step 2, the ninth job stopped before judging). So every
	# Play step that uses Studio begins with a dry-start call (Lesson 120).
	nodry=$(awk '
		FNR == 1 || /^## / { if (play && !dry) print head; play = 0; dry = 0 }
		/^## Step [0-9]/ { head = FILENAME ":" FNR ": " $0; play = ($0 ~ /Play/ && $0 !~ /\(0 Studio calls/) }
		tolower($0) ~ /dry.start/ { dry = 1 }
		END { if (play && !dry) print head }
	' "$@")
	if [ -n "$nodry" ]; then
		echo "$nodry"
		echo "Handoff check FAILED: each Play step above has no \"dry start\" call."
		echo "Begin it with one: put the body on each start, settle 2 s, press 1 s, print the drift and the floor under the feet, and stop \"(lost input)\" if a start drifts over 1 stud (Lesson 120)."
		exit 1
	fi
	# A handoff that invented its own "does a body fit" box check hit the
	# giant's mesh and found no start at 18 of 18 spots (Task 12c step 1, the
	# tenth wrong start check). Starts come only from StartCheck (Lesson 43).
	fitwords='overlap box|GetPartBoundsInBox|GetPartsInPart|GetPartsInBox|GetPartsInRegion|room for the body|body fits|room check|raycast room'
	fits=$(grep -nEi "$fitwords" "$@" | grep -v 'StartCheck' | grep -v '(not a fit check)')
	if [ -n "$fits" ]; then
		echo "$fits"
		echo "Handoff check FAILED: each line above tests whether a body fits without StartCheck."
		echo "Take every start and stand spot from StartCheck.find or StartCheck.nearSpot, and name it on the line (Lesson 43)."
		exit 1
	fi
	# StartCheck.find checks room, not a floor you can stand on, so 13 of 15
	# stand spots it called open slid off steep floors (Task 12c step 3).
	finds=$(grep -nE 'StartCheck\.find' "$@" | grep -v '(not a start)')
	if [ -n "$finds" ]; then
		echo "$finds"
		echo "Handoff check FAILED: each line above takes a start from StartCheck.find, which doesn't check the floor's slope."
		echo "Take it from StartCheck.nearSpot, or name a start that held in an earlier dry start (Lesson 43)."
		exit 1
	fi
	# A grab start that had only ever begun a walk was called "proven" and slid
	# 7.2 studs as a still stand, which stopped the beard proof too (Task 12c step 3
	# rerun, the twelfth wrong start). "Proven" means it held still in a dry start.
	proven=$(grep -nEi '\bproven\b' "$@" | grep -viE 'held( still)? [0-9]*\.?[0-9]+|\(not a start\)')
	if [ -n "$proven" ]; then
		echo "$proven"
		echo "Handoff check FAILED: each line above calls a start proven without the dry start it held in."
		echo "Write \"held 0.19 in <task> dry start\" on the line, or mark it \"(not a start)\" (Lesson 120)."
		exit 1
	fi
	echo "Handoff check passed: every pick names its part, no stop rests on a measured count, every step names its model, every Play step starts with a dry start, every fit test uses StartCheck, no start comes from StartCheck.find, and every proven start names the dry start it held in."
	exit 0
fi
joined=0
if [ "${1:-}" = "--joined" ]; then
	joined=1
	shift
fi
if [ $# -eq 0 ]; then
	echo "usage: scripts/job-check.sh [--joined] <job.luau> [more]"
	exit 2
fi
fail=0

echo "== Size (Lesson 63: at most 300 lines per job file)"
for f in "$@"; do
	n=$(wc -l <"$f" | tr -d ' ')
	if [ "$n" -gt 300 ]; then
		echo "  $f: $n lines, over 300; split it"
		fail=1
	fi
done

if [ "$joined" -eq 1 ]; then
	mkdir -p work
	joinedFile="work/.job-check-joined.luau"
	parts=("$@")
	cat "$@" >"$joinedFile"
	echo "  checking the rest on the ${#} parts joined: $joinedFile"
	set -- "$joinedFile"
fi

echo "== Fit tests outside StartCheck (Lesson 43: Task 12c step 1's own box check hit the giant's mesh)"
# An overlap query in a job that doesn't load StartCheck is a home-made fit
# test. One used for something else is marked "(not a fit check)" on its line.
for f in "$@"; do
	if ! grep -q 'StartCheck' "$f"; then
		if grep -nE 'GetPartBoundsInBox|GetPartsInPart|GetPartBoundsInRadius|GetPartsInBox' "$f" | grep -v '(not a fit check)'; then
			echo "  ^ $f tests a fit without StartCheck; use StartCheck.find or nearSpot"
			fail=1
		fi
	fi
done

echo "== Starts from StartCheck.find (Lesson 43: Task 12c step 3's stand spots slid off steep floors)"
if grep -nE 'StartCheck\.find' "$@" | grep -v '(not a start)'; then
	echo "  ^ take starts from StartCheck.nearSpot, which checks the floor's slope"
	fail=1
fi

echo "== Lines starting with \"(\" (Lesson 7)"
if grep -nE '^\s*\(' "$@"; then
	fail=1
fi

echo "== Clones of modules that use script.Parent (Lesson 74)"
# A module that loads its neighbours through script.Parent fails as an
# unparented clone, so a job must require it the plain way.
# Comment lines don't count: BotLegs says "It uses no script.Parent" (Task 8).
parent_users=$(grep -rE 'script\.Parent' src tools --include='*.luau' |
	grep -vE '^[^:]+:[[:space:]]*--' | cut -d: -f1 | sort -u |
	xargs -n1 basename | sed -E 's/\.luau$//; s/^init\.(server|client)$//' | grep -v '^$' | sort -u)
for name in $parent_users; do
	if grep -nE "\b${name}\b[^-]*:Clone\(\)" "$@"; then
		echo "  ^ $name uses script.Parent; require it the plain way"
		fail=1
	fi
done

echo "== string.format behind a ... wrapper (Lesson 79: the type check can't see its arguments)"
if grep -nE 'string\.format\([A-Za-z_]+, *\.\.\.\)' "$@"; then
	echo "  ^ call string.format at each site with a literal format; wrap booleans in tostring"
	fail=1
fi

echo "== Service members (Task 10: the type check let SoundService.Volume through)"
python3 scripts/job-props.py "$@" || fail=1

echo "== Objects the game makes at runtime (Task 11: the job looked for GiantState inside Remotes)"
net_names=$(grep -oE '^Net\.[A-Za-z]+Name = "[A-Za-z]+"' src/shared/Net.luau | sed -E 's/.*"(.*)"/\1/' | paste -sd'|' -)
if [ -n "$net_names" ] && grep -nE "(FindFirstChild|WaitForChild)\(\"($net_names)\"" "$@"; then
	echo "  ^ find these through Net.waitForClient (or Net.setup), so the job looks where the game puts them"
	fail=1
fi

echo "== Format"
stylua --check "$@" || fail=1

echo "== Lint"
# Each paste runs as its own chunk, so the joined file always warns that the
# next part re-declares the last one's names (Task 12c step 2). Lint the parts.
if [ "$joined" -eq 1 ]; then
	selene "${parts[@]}" || fail=1
else
	selene "$@" || fail=1
fi

echo "== Types"
mkdir -p build
if [ ! -f build/globalTypes.d.luau ]; then
	curl -sfL -o build/globalTypes.d.luau \
		https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
fi
rojo sourcemap default.project.json -o sourcemap.json
if [ "$joined" -eq 1 ]; then
	# Joining puts each later part's --!strict line, and the code after a part's
	# last return, in the middle of one file, and re-declares names; those three are
	# ignored here (selene lints each part for real shadowing). The filter matches
	# only the kind field after "file(line,col): ", so a message can't hide itself.
	types=$(luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json \
		--definitions=@roblox=build/globalTypes.d.luau "$@" 2>&1 |
		grep -vE '^\[(INFO|WARN)\]' | grep -vE '^[^ ]+\([0-9]+,[0-9]+\): (CommentDirective|UnreachableCode|LocalShadow): ')
	if [ -n "$types" ]; then
		echo "$types"
		fail=1
	fi
else
	luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json \
		--definitions=@roblox=build/globalTypes.d.luau "$@" || fail=1
fi

if [ "$fail" -ne 0 ]; then
	echo "Job check FAILED: fix the lines above before any Studio paste."
	exit 1
fi
echo "Job check passed. code_lead still reads the job against the lessons before its first paste (Lesson 76)."
