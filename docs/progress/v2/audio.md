# Progress: Audio (V2 plan 7)

Plan: `docs/plans/v2/audio.md`. Where every plan stands: `docs/progress/index.md`.

Status: ☐ not started · ◐ in progress · ☑ done. "Checked by" lists who has approved it so far.

| Feature (spec) | Task | Status | Checked by |
|---|---|---|---|
| Audio (V2 spec 7) | Task 1: The sound list and the loudness scale | ☑ done | 2026-11-12: 30 rows, 26 ids, Config.Audio; full run 3938/1 (standing OnTheGiant red); code_lead APPROVED |
| Audio (V2 spec 7) | Task 2: Every file loads, and is the one designer picked | ☑ done | 2026-11-12: 26 files load, makers and lengths match; full run 3943/1 (standing OnTheGiant red); code_lead APPROVED |
| Audio (V2 spec 7) | Task 3: The sound board, and the muted session | ☑ done | 2026-11-12: board code (22 + 2 tests), full run 3967/1 (standing OnTheGiant red); muted session 3 runs: 3 wires cut each run, later wires cut, character spawned before the mute (ruled fine until Task 6's play counter); code_lead APPROVED |
| Audio (V2 spec 7) | Task 4: World prep: Roblox's character sounds on the newer objects | ☑ done | 2026-11-12: SoundSettings check (7 tests), world script 26 set CharacterSoundsUseNewApi to Enabled (backup WorldBackups.p7t4), second run "already done"; full run 3974/1 (standing OnTheGiant red); code_lead APPROVED. Adam saves the place at the commit |
| Audio (V2 spec 7) | Task 5: What the music should be doing | ☑ done | builder (MusicMix 15/0); runner (full run 3989/1, only the standing red); code_lead APPROVED 2026-11-12 |
| Audio (V2 spec 7) | Task 6: The music plays | ☑ done | 2026-11-12: Music + SoundBoard tests green; full run 4003/1 (standing OnTheGiant red, t4fix-run-note.md, Task 6 code in the tree); muted session round 3 all pass: half and 1000 Hz at 60%, silent 14.05-18.25 s after the 85% Warning, back at 50%, chase 0 to 1 from 1 s after the wake (one copy); calm tune at spawn kept, no delay (product ruling); code_lead APPROVED |
| Audio (V2 spec 7) | Task 7: The snore follows his sleep | ☑ done | 2026-11-12: Snore 9/9, GiantFx 280/0, full run 4015/1 (only the standing red; t7-run-note.md), code review approved; muted session passed (task7-note.md Step 4). Its 3 stop-time misses (0.17-0.18 s against 0.15) are the Play client's ~15 fps frame plus the probe's sample gap, not code: accepted by code_lead |
| Audio (V2 spec 7) | Task 8: The snorts and the mumble | ☑ done | 2026-11-12: GiantFx 289/0, Cues 4/0, SoundBoard 31/0, code review approved; full run 4034/1 (only the standing red); muted Play passed every line (snorts 1.00 then 0.90, mumble 1.08 s after the warning, stopped at the free save and the wake) |
| Audio (V2 spec 7) | Task 9: The wake-up is loud, and the yawn | ☑ done | 2026-11-12: Cues 6/0, SoundBoard 32/0, Moments 16/0, WakeFace 14/0, GiantFx 289/0; code review approved after one fix (a leaving player's connection is dropped); full run 4053/1 (only the standing red); muted Play wake passed every line (sting, roar, rumble at W, birds W+0.20, pop W+0.26, rumble silent by W+0.93, one yawn at the lie-down) |
| Audio (V2 spec 7) | Task 10: Every slam is heard | ◐ in progress | 2026-11-12: card work/p7/task10-card.md |
| Audio (V2 spec 7) | Task 11: Grabbing and bringing eggs home | ☐ not started | |
| Audio (V2 spec 7) | Task 12: A new egg sparkles, a lost egg pops | ☐ not started | |
| Audio (V2 spec 7) | Task 13: Your own thuds are heard | ☐ not started | |
| Audio (V2 spec 7) | Task 14: Tiptoe is quiet, and clicks | ☐ not started | |
| Audio (V2 spec 7) | Task 15: The rescue poof | ☐ not started | |
| Audio (V2 spec 7) | Task 16: The music button | ☐ not started | |
| Audio (V2 spec 7) | Task 17: The music button's analytics | ☐ not started | |
| Audio (V2 spec 7) | Task 18: A whole session with sound | ☐ not started | |
| Audio (V2 spec 7) | Task 19: The Gate 4 sound check | ☐ not started | |
| Audio (V2 spec 7) | Task 20: The Play proof | ☐ not started | |

## Notes for the next V2 review

- **From other plans' notes:** Tasks 5, 6 and 7 wait for product and designer (`stuck-safety.md`, "Where the reviews stand"). The safe way to mute sound in Play is in `docs/progress/index.md` ("Muting the sound in Play (never saved)").
