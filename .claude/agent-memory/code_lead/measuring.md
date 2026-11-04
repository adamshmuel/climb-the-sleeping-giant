# Measuring

- Measure gaps to a mesh with raycasts: `GetPartBoundsInBox` uses its whole bounding box.
- A look-only part (CanQuery off) can't be hit by rays: measure it from `CFrame` and `Size`. When a task makes a part look-only, check every test and script that rays it first.
- Compare two sides of a slope at the same x (or the same distance along), and leave the new part out of a measure of the ground under it.
- Before ruling a check onto a new kind of piece, measure what its ray really hits on the built piece (one read-only call). Where the piece has a stricter test of its own, reuse it and skip the old one, with a comment.
- A reach check for an invisible walk part also prints its gap above the visible surface; a gap over 0.5 goes to designer before the build (Task 6a hover, 2026-11-04). Check each look word in a spec against its mockup at plan time.
- Sink depth: never along the face normal (measures through the whole limb) nor straight down only (misses sideways burial). Inside = 0 of 26 outward rays hit and 20+ inward hit; depth = shortest inward hit; test inside PER character part (whole-character outward rays hit his other parts and miss sinks); no ray-down covered check, it gives false hits under overhangs (2026-11-04, 6d).
