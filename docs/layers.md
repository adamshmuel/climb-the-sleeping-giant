# Layer map: Climb the Sleeping Giant

This map splits the game's world into five layers, and says which layer sits on which. It is used to order work (the `order-the-work` skill): work that changes or reads a layer waits for every open change to that layer, wherever in the world that change is.

**Sits on** means: is placed on it, is reached through it, or is measured against it.

How much each part matters to the player is in the idea file, "What matters most" (`docs/ideas/climb-the-sleeping-giant.md`). This map only says where each part is and what it rests on.

## The five layers

| Layer | What it is in this game | Sits on |
|---|---|---|
| **Where things are found** | The places players walk, climb and sneak to find eggs: the meadow grass around him, and every part of his body players stand on (boot tops, knees, lap fold, belly top and sides down to the seam, arms out to the cuffs, the beard–belly fold, the nightcap's brim, side stripe and top). It also holds what makes those places walkable and safe: the invisible walk pieces, patches and guards fitted to his body, every way up (the ramps, the belly path, the ladders by his ears), the route points the glowing footprints follow, and the noise zones laid over them | His body shape (the giant is never reshaped, so his body is the ground this layer is fitted to). Reached through **Home base**: every climb starts at a garden's Safe Gate |
| **Where things are kept** | Inside each garden: the incubators where eggs hatch, the pet pads where pets earn cash, and the cash chest | **Home base** |
| **Home base** | The 8 gardens: where a player spawns, the Safe Gate they carry an egg through, and the plank bridge over the stream | The valley ground. Its fairness (no garden gets a faster way up or home) is measured against the ways up in **Where things are found** |
| **The collectibles** | Every egg and its straw nest (the egg spots: 16 in the meadow, 22 on him), the Team Egg on his belly, and the Dream Egg on top of his nightcap during Deep Sleep | **Where things are found**: each nest is placed on a walkable spot and reached through the ways up and the route |
| **Scenery** | What is only there to look at: the parts of him off every route (his face, eyelids, nose, forehead, cheeks, the beard above the fold, his back, the skin below the seam), the nightcap's tail and pom-pom, the pillow, the Sock, and the valley around him | Nothing. It is the bottom layer, next to his body shape |

## Notes on the layers

- **His face is scenery as a place, but it is the main character in the first view.** Nothing is placed on it and no route crosses it (Rule 101: Ladders hold you, "no ladder on his face"). But any work that changes what the fixed cameras see of his face passes the before-and-after look check, and a "worse" there is a red alert (`agent-workflow.md`).
- **A way up is part of "Where things are found",** even where it touches scenery (the ladders by his ears). So a change to a way up is an open change to the layer every egg sits on, however far that egg is from it.
- **Putting an egg back where it was is placing it.** It waits for every open change to "Where things are found", like a new egg.
- **A check of the whole play** (stuck scan, bot walk, full test run, reach and fairness checks) reads "Where things are found", "The collectibles" and "Home base" together. It runs once, after every open change to them.
