# Architecture: Climb the Sleeping Giant

How the game is built. Each choice has a short "why". Written 2026-10-12 for spec 1 (Core heist). Updated 2026-10-19 for V2 spec 1 (New-player safety), V2 spec 2 (Stuck safety), V2 spec 3 (Gardens and ways up), V2 spec 4 (Egg reachability), V2 spec 5 (Egg nests and the walk-anywhere belly), V2 spec 6 (Wake-up) and V2 spec 7 (Audio). It is updated whenever a later spec changes how things are built.

**Sections.** Each is its own file in `docs/architecture/`. Read this page, then only the sections your task touches.

- [1. Where things live](architecture/01-where-things-live.md)
- [2. Networking](architecture/02-networking.md)
- [3. Game loop on the server](architecture/03-game-loop-on-the-server.md)
- [4. Data saving](architecture/04-data-saving.md)
- [5. The screen (HUD)](architecture/05-the-screen-hud.md)
- [6. Testing](architecture/06-testing.md)
- [7. Quality checks before every handoff](architecture/07-quality-checks-before-every-handoff.md)
- [8. Studio rules for the build](architecture/08-studio-rules-for-the-build.md)
- [9. The shared walk check (`World/PathCheck`)](architecture/09-the-shared-walk-check.md)
- [10. Sound (V2 spec 7)](architecture/10-sound-v2-spec-7.md)

Words used here:

| Word | Means |
|---|---|
| **Server** | Roblox's computer that runs one copy of the game for up to 8 players. It decides everything that matters. |
| **Client** | One player's own device (computer or phone). It draws the screen and reads the controls. |
| **ModuleScript** | A Luau file that other scripts load with `require`. All game logic lives in these. |
| **Remote** | A message between the client and the server (a `RemoteEvent`). |
| **Attribute** | A named value stored on a Roblox object. The server sets it, and Roblox copies it to every client automatically. |
| **Rojo** | The tool that copies our code from the `src/` folder into Studio. |
| **Test** | A small Luau file that checks one behaviour of one module and says pass or fail. |
| **Pure module** | A module that only does maths on what it is given. It touches no players, parts or clocks, so a test can check it in a split second. |
