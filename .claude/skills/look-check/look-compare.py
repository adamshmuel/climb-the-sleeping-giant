# Checks each after shot against its before shot. Usage:
#   python3 .claude/skills/look-check/look-compare.py <before folder> <after folder>
# Prints one row per shot. FLAG rows must be taken again before designer judges.
# Measured 2026-11-03: a true pair differs by 0.00 to 0.05,
# the wrong view (one gate saved as another) by 0.38, a repeated file by 0.00.
import sys, os, itertools
from PIL import Image, ImageChops
def changed(a, b):
    A = Image.open(a).convert("L").resize((96, 54)); B = Image.open(b).convert("L").resize((96, 54))
    px = list(ImageChops.difference(A, B).getdata())
    return sum(1 for p in px if p > 40) / len(px)
before, after = sys.argv[1], sys.argv[2]
shots = sorted(f for f in os.listdir(after) if f.endswith(".jpg"))
bad = 0
for f in shots:
    b = os.path.join(before, f)
    if not os.path.exists(b):
        print(f"{f}: no before shot (a new view), checked only for repeats"); continue
    c = changed(b, os.path.join(after, f))
    flag = c > 0.20
    bad += flag
    print(f"{f}: {c:.2f} of the picture changed" + ("  FLAG: most of the view moved, take it again" if flag else ""))
for x, y in itertools.combinations(shots, 2):
    if changed(os.path.join(after, x), os.path.join(after, y)) < 0.01:
        bad += 1
        print(f"FLAG: {x} and {y} are the same picture, take the second again")
print(f"look-compare: {bad} flagged, end of report")
