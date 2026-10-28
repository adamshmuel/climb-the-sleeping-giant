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
	echo "Handoff check passed: every pick names its part, and no stop rests on a measured count."
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
	cat "$@" >"$joinedFile"
	echo "  checking the rest on the ${#} parts joined: $joinedFile"
	set -- "$joinedFile"
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

echo "== Format"
stylua --check "$@" || fail=1

echo "== Lint"
selene "$@" || fail=1

echo "== Types"
mkdir -p build
if [ ! -f build/globalTypes.d.luau ]; then
	curl -sfL -o build/globalTypes.d.luau \
		https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
fi
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json \
	--definitions=@roblox=build/globalTypes.d.luau "$@" || fail=1

if [ "$fail" -ne 0 ]; then
	echo "Job check FAILED: fix the lines above before any Studio paste."
	exit 1
fi
echo "Job check passed. code_lead still reads the job against the lessons before its first paste (Lesson 76)."
