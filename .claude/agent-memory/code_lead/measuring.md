# Measuring

- Measure gaps to a mesh with raycasts: `GetPartBoundsInBox` uses its whole bounding box.
- A look-only part (CanQuery off) can't be hit by rays: measure it from `CFrame` and `Size`. When a task makes a part look-only, check every test and script that rays it first.
- Compare two sides of a slope at the same x (or the same distance along), and leave the new part out of a measure of the ground under it.
- Before ruling a check onto a new kind of piece, measure what its ray really hits on the built piece (one read-only call). Where the piece has a stricter test of its own, reuse it and skip the old one, with a comment.
