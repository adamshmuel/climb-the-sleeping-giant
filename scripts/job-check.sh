#!/usr/bin/env bash
# Checks for Studio job scripts in work/ before their first paste.
# Three Task 54 Studio calls were lost to job scripts that stopped before
# judging anything. This catches the mistakes a shell can see.
# Usage: scripts/job-check.sh work/t54/server-p.luau [more files]
# A handoff is checked with --handoff work/handoff-x.md.
# A job split into parts is checked with --joined part-a part-b:
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
# Every task and step says what it stands on, and nothing comes before what it
# stands on (agent-workflow.md, "Order work by what it stands on"). Task 60 put
# the Rare egg check before the ear ladders it depends on were even chosen.
stands_on_check() {
	local bad f
	if [ $# -eq 0 ]; then
		echo "Plan check FAILED: no files given."
		return 1
	fi
	for f in "$@"; do
		if [ ! -f "$f" ] || [ ! -r "$f" ]; then
			echo "Plan check FAILED: can't read $f"
			return 1
		fi
	done
	bad=$(for f in "$@"; do
		awk '
			function name(s) { return match(s, /(Task|Step) [0-9]+[a-z]?/) ? substr(s, RSTART, RLENGTH) : "" }
			# A reach walk comes first (order-the-work, Step 4, item 1): Task 61a built a cap tie at a spot
			# no player could walk to, found only by the last task. A task or step whose heading builds or
			# places a way up or an item stands on a reach walk: named on its "Stands on:" line, or a Task
			# or Step whose heading is one. A heading that is itself a reach walk needs none.
			function isreach(s) { return s ~ /reach (walk|check|probe)/ }
			function places(s) {
				return s ~ /(ladder|ramp|bridge|way up|tie|truss|perch|deck|plank|rope|stair|nest|egg|route ?point)/ \
					&& s ~ /(build|built|place|go(es)? back|put back|restore|mirror|lean|added|adds|moved|moves)/ \
					&& !isreach(s)
			}
			function close_head() {
				if (head != "" && !seen) print FILENAME ":" headline ": \"" head "\" has no \"Stands on:\" line"
				if (head != "" && builds && !reached)
					print FILENAME ":" headline ": \"" head "\" builds or places at a spot, but stands on no reach walk"
			}
			# First pass: where each task and step heading is, and which are reach walks.
			NR == FNR {
				if (/^#+ / && name($0) != "") {
					if (!(name($0) in pos)) pos[name($0)] = FNR
					if (isreach(tolower($0))) reach[name($0)] = 1
				}
				next
			}
			/^#+ / { close_head(); head = name($0); headline = FNR; seen = 0; builds = places(tolower($0)); reached = 0; next }
			head != "" && /^[*_ -]*Stands on/ {
				seen = 1
				low = tolower($0)
				if (isreach(low)) reached = 1
				if (low ~ /(^|[^a-z])(open|undecided|not decided|pending|waiting|tbd)([^a-z]|$)/)
					print FILENAME ":" FNR ": \"" head "\" stands on something not final"
				s = $0
				while (match(s, /(Task|Step) [0-9]+[a-z]?/)) {
					ref = substr(s, RSTART, RLENGTH)
					s = substr(s, RSTART + RLENGTH)
					if (ref in reach) reached = 1
					if ((ref in pos) && pos[ref] > headline)
						print FILENAME ":" FNR ": \"" head "\" comes before \"" ref "\", which it stands on"
				}
			}
			END { close_head() }
		' "$f" "$f"
	done)
	if [ -n "$bad" ]; then
		echo "$bad"
		echo "Plan check FAILED: every task and step needs a \"Stands on:\" line, and comes after"
		echo "everything it stands on, which must be final (agent-workflow.md, \"Order work by what it stands on\")."
		echo "One that builds or places at a spot also stands on its reach walk (order-the-work, Step 4, item 1)."
		return 1
	fi
}
if [ "${1:-}" = "--plan" ]; then
	shift
	stands_on_check "$@" || exit 1
	echo "Plan check passed: $*"
	exit 0
fi
if [ "${1:-}" = "--handoff" ]; then
	shift
	stands_on_check "$@" || exit 1
	# A part a job picks by a search at paste time is first seen by the
	# paste (Task 7 step 2). Every pick is made in code_lead's
	# names-check call, and the handoff names the part by path or position.
	# A pick that can only happen in Play (for example, the landing spot
	# nearest where the player landed) is marked "(runtime pick)" on its line.
	pick='\b(nearest|finds? (it|them) by|picks? the|whichever)\b'
	named='(Workspace|World|ServerStorage|ReplicatedStorage)\.[A-Za-z_]|\(-?[0-9.]+, *-?[0-9.]+, *-?[0-9.]+\)|\(runtime pick\)|search "'
	found=$(grep -nEi "$pick" "$@" | grep -vE "$named")
	if [ -n "$found" ]; then
		echo "$found"
		echo "Handoff check FAILED: each line above picks a part by a rule with no path or position."
		echo "Run the pick in the names-check call and name the part."
		exit 1
	fi
	# A stop on a cross-check count that nothing reads (Task 7c call 1, Task 8b
	# slot 3) cost calls twice. A job stops only when an input is
	# lost or broken; such a line is marked "(lost input)".
	match='(must|don.t|do not|doesn.t|not) match|match(es)? slot|differ(s)? from slot'
	stops=$(grep -nEi "$match" "$@" | grep -Ei 'FIRED|stop' | grep -v '(lost input)')
	if [ -n "$stops" ]; then
		echo "$stops"
		echo "Handoff check FAILED: each line above stops a job on a measured count."
		echo "Print cross-check counts; stop only on a lost or broken input, marked \"(lost input)\"."
		exit 1
	fi
	# Each step runs on the cheapest model that can do it (CLAUDE.md,
	# "Model per job"), so every step heading names one.
	nomodel=$(grep -nE '^## Step [0-9]' "$@" | grep -viE '\b(haiku|sonnet|opus)\b')
	if [ -n "$nomodel" ]; then
		echo "$nomodel"
		echo "Handoff check FAILED: each step heading above names no model (Haiku, Sonnet or Opus)."
		echo "Pick it from CLAUDE.md, \"Model per job\"."
		exit 1
	fi
	# Tests run only in Studio, so a red step with no Studio calls can't see
	# its red (Task 13 step 6b and Task 13b step 1).
	nostudiored=$(grep -nE '^## Step [0-9]' "$@" | grep -iE '\b(red|failing test)' | grep -iE '\(0 Studio calls|\(no Studio calls')
	if [ -n "$nostudiored" ]; then
		echo "$nostudiored"
		echo "Handoff check FAILED: each red step above has no Studio calls, but tests run only in Studio."
		echo "Budget the full run: start and one fetch (2 Studio calls, cap 3)."
		exit 1
	fi
	# A full run is a runner job on Haiku, never part of a Sonnet or Opus step
	# (CLAUDE.md, "Model per job"; Task 13b ran three on Sonnet).
	fullrun=$(grep -nE '^## Step [0-9]' "$@" | grep -iE 'full run' | grep -iE '\b(sonnet|opus)\b')
	if [ -n "$fullrun" ]; then
		echo "$fullrun"
		echo "Handoff check FAILED: each step above puts a full run on Sonnet or Opus."
		echo "Give the full run its own step on Haiku (the runner)."
		exit 1
	fi
	# The runner (Haiku) has no screen_capture, Play or input tools, so a Haiku
	# step that needs one stops at once (review Part 4, then Task 4b Step 1).
	notools=$(awk '
		FNR == 1 || /^## / { haiku = 0 }
		/^## Step [0-9]/ { haiku = (tolower($0) ~ /haiku/); step = $0 }
		haiku && /screen_capture|start_stop_play|user_keyboard_input|user_mouse_input|character_navigation/ {
			print FILENAME ": " step; haiku = 0
		}
	' "$@")
	if [ -n "$notools" ]; then
		echo "$notools"
		echo "Handoff check FAILED: each Haiku step above needs screen_capture, Play or input tools, which the runner lacks."
		echo "Give the shots and Play to a Sonnet step (the builder); keep only the full run on Haiku."
		exit 1
	fi
	# A full run's fetch reports only its counts (passed, failed, could not run,
	# spec files) and the failing test names. A pass line copied from an older
	# step asked for a "stuck scan line" no run prints (Task 57 step 2).
	badpass=$(awk '
		FNR == 1 || /^## / { full = 0 }
		/^## Step [0-9]/ { full = (tolower($0) ~ /full run/) }
		full && /Pass/ && tolower($0) ~ /(line|scan|print|")/ { print FILENAME ":" FNR ": " $0 }
	' "$@")
	# A pass line that names world parts ("for CapLadder and BeardLadder")
	# can't be judged either: the fetch cuts each failure's text short (Task 58
	# Step 2). So every CamelCase name on a full-run pass line must be a spec.
	specs=" $(find src/tests -name '*.spec.luau' -exec basename {} .spec.luau \; | tr '\n' ' ') "
	partpass=$(awk -v specs="$specs" '
		FNR == 1 || /^## / { full = 0 }
		/^## Step [0-9]/ { full = (tolower($0) ~ /full run/) }
		full && /Pass/ {
			line = $0
			while (match(line, /[A-Z][a-z0-9]+[A-Z][A-Za-z0-9]*/)) {
				word = substr(line, RSTART, RLENGTH)
				if (index(specs, " " word " ") == 0) { print FILENAME ":" FNR ": " $0; break }
				line = substr(line, RSTART + RLENGTH)
			}
		}
	' "$@")
	badpass="$badpass$partpass"
	if [ -n "$badpass" ]; then
		echo "$badpass"
		echo "Handoff check FAILED: each full-run pass line above names output the fetch doesn't print."
		echo "Word it only from the fetch's report: \"N passed, 0 failed\", \"could not run\", spec files, failing test names."
		exit 1
	fi
	# A start taken from an Edit-time probe can float in the air or sit on a
	# slope (Task 12b step 2, the ninth job stopped before judging). So every
	# Play step that uses Studio begins with a dry-start call.
	nodry=$(awk '
		FNR == 1 || /^## / { if (play && !dry) print head; play = 0; dry = 0 }
		/^## Step [0-9]/ { head = FILENAME ":" FNR ": " $0; play = ($0 ~ /Play/ && $0 !~ /\(0 Studio calls/) }
		tolower($0) ~ /dry.start/ { dry = 1 }
		END { if (play && !dry) print head }
	' "$@")
	if [ -n "$nodry" ]; then
		echo "$nodry"
		echo "Handoff check FAILED: each Play step above has no \"dry start\" call."
		echo "Begin it with one: put the body on each start, settle 2 s, press 1 s, print the drift and the floor under the feet, and stop \"(lost input)\" if a start drifts over 1 stud."
		exit 1
	fi
	# A climb trace that gave up after two turns, with no step back and no shot
	# from the player's camera, called a stall it couldn't show (Task 61a Step 2;
	# the same kind as the 2026-11-02 ladder wedge). So a Play step
	# that can report STUCK retries like a player and shoots the stall.
	nostall=$(awk '
		function check() { if (play && stuck && (!back || !shot)) print head }
		FNR == 1 || /^## / { check(); play = 0; stuck = 0; back = 0; shot = 0 }
		/^## Step [0-9]/ { head = FILENAME ":" FNR ": " $0; play = ($0 ~ /Play/ && $0 !~ /\(0 Studio calls/) }
		/STUCK/ { stuck = 1 }
		tolower($0) ~ /step(s|ping)? back/ { back = 1 }
		tolower($0) ~ /stall shot|shot (at|of) the stall|screen_capture/ { shot = 1 }
		END { check() }
	' "$@")
	if [ -n "$nostall" ]; then
		echo "$nostall"
		echo "Handoff check FAILED: each Play step above can report STUCK, but has no \"step back\" retry or no stall shot."
		echo "Before a STUCK, retry like a player (turn, step back, turn again) and take a screen_capture at the stall."
		exit 1
	fi
	# Task 61h's drop job rebuilt the game's own landing check and was pasted
	# many times, so two builders ran out of memory. So
	# every step gives its planned minutes, and every Play step gives its paste
	# lines and names the game signal each pass item reads.
	nosize=$(awk '
		function check() {
			if (head == "") return
			if (!mins) print head " (no planned minutes)"
			if (play && !paste) print head " (no paste lines)"
			if (play && !signal) print head " (no game signal named)"
		}
		FNR == 1 || /^## / { check(); head = ""; play = 0; mins = 0; paste = 0; signal = 0 }
		/^## Step [0-9]/ { head = FILENAME ":" FNR ": " $0; play = ($0 ~ /Play/ && $0 !~ /\(0 Studio calls/) }
		tolower($0) ~ /[0-9]+ ?min/ { mins = 1 }
		tolower($0) ~ /paste lines/ { paste = 1 }
		tolower($0) ~ /signal/ { signal = 1 }
		END { check() }
	' "$@")
	if [ -n "$nosize" ]; then
		echo "$nosize"
		echo "Handoff check FAILED: each step above needs its planned minutes, and each Play step its paste lines (file lines times pastes, split over about 2000) and the game signal each pass item reads."
		exit 1
	fi
	# A handoff that invented its own "does a body fit" box check hit the
	# giant's mesh and found no start at 18 of 18 spots (Task 12c step 1, the
	# tenth wrong start check). Starts come only from StartCheck.
	fitwords='overlap box|GetPartBoundsInBox|GetPartsInPart|GetPartsInBox|GetPartsInRegion|room for the body|body fits|room check|raycast room'
	fits=$(grep -nEi "$fitwords" "$@" | grep -v 'StartCheck' | grep -v '(not a fit check)')
	if [ -n "$fits" ]; then
		echo "$fits"
		echo "Handoff check FAILED: each line above tests whether a body fits without StartCheck."
		echo "Take every start and stand spot from StartCheck.find or StartCheck.nearSpot, and name it on the line."
		exit 1
	fi
	# StartCheck.find checks room, not a floor you can stand on, so 13 of 15
	# stand spots it called open slid off steep floors (Task 12c step 3).
	finds=$(grep -nE 'StartCheck\.find' "$@" | grep -v '(not a start)')
	if [ -n "$finds" ]; then
		echo "$finds"
		echo "Handoff check FAILED: each line above takes a start from StartCheck.find, which doesn't check the floor's slope."
		echo "Take it from StartCheck.nearSpot, or name a start that held in an earlier dry start."
		exit 1
	fi
	# A grab start that had only ever begun a walk was called "proven" and slid
	# 7.2 studs as a still stand, which stopped the beard proof too (Task 12c step 3
	# rerun, the twelfth wrong start). "Proven" means it held still in a dry start.
	proven=$(grep -nEi '\bproven\b' "$@" | grep -viE 'held( still)? [0-9]*\.?[0-9]+|\(not a start\)')
	if [ -n "$proven" ]; then
		echo "$proven"
		echo "Handoff check FAILED: each line above calls a start proven without the dry start it held in."
		echo "Write \"held 0.19 in <task> dry start\" on the line, or mark it \"(not a start)\"."
		exit 1
	fi
	# A grab start marked "(not a start)" dodged the rule above, slid, and the
	# egg was lost before any beard try (Task 12c last run). A grab's start holds too.
	grabs=$(grep -nEi '\bgrab' "$@" | grep -E '\(-?[0-9.]+, *-?[0-9.]+, *-?[0-9.]+\)' | grep -viE 'held( still)? [0-9]*\.?[0-9]+')
	if [ -n "$grabs" ]; then
		echo "$grabs"
		echo "Handoff check FAILED: each line above grabs from a position with no dry start it held in."
		echo "Write \"held 0.19 in <task> dry start\" on the line; a grab start is a start."
		exit 1
	fi
	# A red run over "the five spec names" ran only the first name, and three
	# specs never ran (Task 61d step 1). The runner
	# takes one name per filter, so a filter over several names, or with "|", fails.
	multifilter=$(grep -nEi 'filter' "$@" | grep -Ei '[A-Za-z]\|[A-Za-z]|spec names|test names' | grep -viE 'one (spec )?name per run')
	if [ -n "$multifilter" ]; then
		echo "$multifilter"
		echo "Handoff check FAILED: each line above runs several spec names in one filter."
		echo "Give each spec name its own run, and write \"one spec name per run\" on the line."
		exit 1
	fi
	# Red flag 61a, the meter hold: twice a script that held the giant's sleep
	# meter stopped between runs, the giant woke, and the run looked real but
	# was void. In a handoff with a Play step, every work/ script it names has
	# the hold check (a), passes the script checks before any paste (b), and
	# has a CHECK_ONLY switch run read-only in Edit first (c).
	# A Play handoff has a step heading with "Play", or a step with Studio calls in a handoff that talks of Play.
	hasplay=$(awk '
		/^## Step [0-9]/ && $0 ~ /Play/ && $0 !~ /\(0 Studio calls/ { n++ }
		/^## Step [0-9]/ && $0 ~ /Studio call/ && $0 !~ /\(0 Studio calls/ { calls++ }
		!/^#/ && /(^|[^A-Za-z])Play([^A-Za-z]|$)/ { talks = 1 }
		END { print n + (talks ? calls : 0) + 0 }
	' "$@")
	if [ "$hasplay" -gt 0 ]; then
		scripts_named=$(grep -ohE 'work/[A-Za-z0-9_./-]+\.luau' "$@" | sort -u)
		# (a) The hold: the handoff names the session hold, and every named run script reads the beat.
		if ! grep -q 'scripts/studio/session-hold\.luau' "$@"; then
			echo "Handoff check FAILED: this handoff has a Play step but never names scripts/studio/session-hold.luau."
			echo "Paste the session hold right after Start Play, and say so in the step (red flag 61a)."
			exit 1
		fi
		# (d) A named script must exist, unless its line says "written in Step <n>" (red flag 61a).
		for f in $scripts_named; do
			[ -f "$f" ] && continue
			if grep -hF "$f" "$@" | grep -qv 'written in Step [0-9]'; then
				echo "$f: no such file"
				echo "Handoff check FAILED: the script above is named but does not exist. Write it first, or say \"written in Step <n>\" on its line (red flag 61a)."
				exit 1
			fi
		done
		for f in $scripts_named; do
			[ -f "$f" ] || continue
			head -5 "$f" | grep -q '(no hold: Edit only)' && continue
			if ! grep -q 'TrialHoldBeat' "$f"; then
				echo "$f: no TrialHoldBeat check"
				echo "Handoff check FAILED: the script above has no hold check. Copy the held() snippet from scripts/studio/session-hold.luau into it,"
				echo "or write \"(no hold: Edit only)\" in its first 5 lines if it never runs in Play (red flag 61a)."
				exit 1
			fi
		done
		# (c) Dry run in Edit: a CHECK_ONLY switch in each script, and a "dry run in Edit" line before the first Play step.
		for f in $scripts_named; do
			[ -f "$f" ] || continue
			head -5 "$f" | grep -q '(no hold: Edit only)' && continue
			if ! grep -q 'CHECK_ONLY' "$f"; then
				echo "$f: no CHECK_ONLY switch"
				echo "Handoff check FAILED: the script above has no CHECK_ONLY switch, so it can't be dry run in Edit (red flag 61a)."
				exit 1
			fi
		done
		nodryedit=$(awk '
			FNR == 1 { seen = 0 }
			tolower($0) ~ /dry run in edit/ { seen = 1 }
			tolower($0) ~ /start play|dry.start/ && !seen { print FILENAME ":" FNR ": " $0; seen = 1 }
		' "$@")
		if [ -n "$nodryedit" ]; then
			echo "$nodryedit"
			echo "Handoff check FAILED: the line above starts Play before any \"dry run in Edit\" line (red flag 61a)."
			exit 1
		fi
		# (b) Before the paste: the plain script checks (selene, type check) on every named work/ and scripts/studio/ script.
		studio_named=$(grep -ohE 'scripts/studio/[A-Za-z0-9_./-]+\.luau' "$@" | sort -u)
		for f in $scripts_named $studio_named; do
			[ -f "$f" ] || continue
			if ! bash scripts/job-check.sh "$f" >/dev/null 2>&1; then
				echo "Handoff check FAILED: $f fails scripts/job-check.sh $f (run it to see why). Red flag 61a: no script is pasted before it passes."
				exit 1
			fi
		done
	fi
	echo "Handoff check passed: every pick names its part, no stop rests on a measured count, every step names its model, every red step budgets Studio, every full run is on Haiku, every full-run pass line names only what the fetch prints, every Play step starts with a dry start, every fit test uses StartCheck, no start comes from StartCheck.find, and every proven or grab start names the dry start it held in, every run filter names one spec, and every Play handoff names the session hold, checks the beat, passes the script checks and has a dry run in Edit, and every step gives its minutes and every Play step its paste lines and game signals."
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

echo "== Size (at most 300 lines per job file; 1000 for tools/world/)"
for f in "$@"; do
	n=$(wc -l <"$f" | tr -d ' ')
	case "$f" in
	tools/world/* | */tools/world/*)
		if [ "$n" -gt 1000 ]; then
			echo "  $f: $n lines, over 1000; split it by topic"
			fail=1
		fi
		continue
		;;
	esac
	if [ "$n" -gt 300 ]; then
		echo "  $f: $n lines, over 300; split it"
		fail=1
	fi
done

echo "== CHECK_ONLY switch in new world scripts (Task 58b's 18 stopped twice in Play on a wrong guess)"
# A world script not yet in git must have a CHECK_ONLY switch, so its own
# lookups and guards run read-only in Edit before its first Play paste.
# Older world scripts already in git only get a warning.
for f in "$@"; do
	case "$f" in
	tools/world/* | */tools/world/*) ;;
	*) continue ;;
	esac
	if ! grep -q "CHECK_ONLY" "$f"; then
		if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
			echo "  warning: $f has no CHECK_ONLY switch (add one when it next changes)"
		else
			echo "  $f: new world script with no CHECK_ONLY switch; add one and run it read-only in Edit first"
			fail=1
		fi
	fi
done

echo "== Fetch reads its job's shared. names (Task 58b's rerun fetch read the old trial's name)"
# When a fetch is checked together with its jobs, every shared. name the
# fetch reads must be written by one of those jobs.
jobNames=""
for f in "$@"; do
	case "$f" in
	*fetch*) ;;
	*) jobNames="$jobNames $(grep -oE 'shared\.[A-Za-z0-9_]+' "$f" | sort -u | tr '\n' ' ')" ;;
	esac
done
if [ -n "${jobNames// /}" ]; then
	for f in "$@"; do
		case "$f" in
		*fetch*) ;;
		*) continue ;;
		esac
		for name in $(grep -oE 'shared\.[A-Za-z0-9_]+' "$f" | sort -u); do
			case " $jobNames " in
			*" $name "*) ;;
			*)
				echo "  $f reads $name, but no job checked with it uses that name"
				fail=1
				;;
			esac
		done
	done
fi

if [ "$joined" -eq 1 ]; then
	mkdir -p work
	joinedFile="work/.job-check-joined.luau"
	parts=("$@")
	cat "$@" >"$joinedFile"
	echo "  checking the rest on the ${#} parts joined: $joinedFile"
	set -- "$joinedFile"
fi

echo "== Fit tests outside StartCheck (Task 12c step 1's own box check hit the giant's mesh)"
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

echo "== Starts from StartCheck.find (Task 12c step 3's stand spots slid off steep floors)"
if grep -nE 'StartCheck\.find' "$@" | grep -v '(not a start)'; then
	echo "  ^ take starts from StartCheck.nearSpot, which checks the floor's slope"
	fail=1
fi

echo "== Lines starting with \"(\""
if grep -nE '^\s*\(' "$@"; then
	fail=1
fi

echo "== Clones of modules that use script.Parent"
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

echo "== string.format behind a ... wrapper (the type check can't see its arguments)"
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
# A part that doesn't start with --!strict goes in the same paste as the part
# before it (Task 58b trial), so it is linted joined to that part.
if [ "$joined" -eq 1 ]; then
	groups=()
	g=-1
	for f in "${parts[@]}"; do
		if [ "$g" -lt 0 ] || [ "$(head -n 1 "$f")" = "--!strict" ]; then
			g=$((g + 1))
			groups[g]="work/.job-check-paste-$g.luau"
			: >"${groups[g]}"
		fi
		cat "$f" >>"${groups[g]}"
	done
	selene "${groups[@]}" || fail=1
	rm -f "${groups[@]}"
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
echo "Job check passed. code_lead still reads the job before its first paste."
