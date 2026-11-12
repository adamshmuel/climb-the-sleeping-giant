# Progress: Wake-up (V2 plan 6)

Plan: `docs/plans/v2/wake-up.md`. Where every plan stands: `docs/progress/index.md`.

Status: ☐ not started · ◐ in progress · ☑ done. "Checked by" lists who has approved it so far.

| Feature (spec) | Task | Status | Checked by |
|---|---|---|---|
| Wake-up (V2 spec 6) | Task 1: The new slam times and the wake-up numbers | ☑ done 2026-11-12 | full run 3484 passed, 1 failed (the standing stuck-scan red); code_lead approved |
| Wake-up (V2 spec 6) | Task 2: Who can be a target | ☑ done 2026-11-12 | narrow Slams.spec 107/0; full run 3501 passed, 1 failed (the standing stuck-scan red); code_lead approved |
| Wake-up (V2 spec 6) | Task 3: Who the hand hits | ☑ done 2026-11-12 | HandShape (shared), Slams.underHand/hits, SlamSurface.under, RedCircles guard; full run 3538 passed, 1 failed (the standing stuck-scan red); code_lead approved |
| Wake-up (V2 spec 6) | Task 4: Show slams near a protected player | ☑ done 2026-11-12 | ShowSlam.pickShow (new module), garden margin moved to Config.Wake.SlamGardenMarginStuds, Slams.flatDistance shared; full run 3547 passed, 1 failed (the standing stuck-scan red); builder, code_lead |
| Wake-up (V2 spec 6) | Task 5: The meadow spots for show slams | ☑ done | builder, code_lead |
| Wake-up (V2 spec 6) | Task 6: The circle under anyone, on the first walkable surface | ☑ done (2026-11-12; full run 3585/1, standing red only; circle shots in Task 23) | code_lead |
| Wake-up (V2 spec 6) | Task 7: The bonk on the server | ☑ done 2026-11-12 | Bonker 6/0, Carry 35/0; full run 3510 passed, 1 failed (the standing stuck-scan red); Play hold proof moved to Task 16 (product, accept for now); code_lead approved |
| Wake-up (V2 spec 6) | Task 8: The director hunts everyone | ☑ done (2026-11-12; full run 3568/1, standing red only) | code_lead |
| Wake-up (V2 spec 6) | Task 9: The server says who is in a garden and who floats | ☑ done 2026-11-12 | PlayerTracker 40/0, Floater 41/0; full run 3516 passed, 1 failed (the standing stuck-scan red); code_lead approved |
| Wake-up (V2 spec 6) | Task 10: World prep: the wake pieces | ☑ done | builder, code_lead, designer |
| Wake-up (V2 spec 6) | Task 11: His face wakes | ☑ done (2026-11-12; full run 3599/1, standing red only; Play reads and 4 shots, designer judging) | code_lead |
| Wake-up (V2 spec 6) | Task 12: His arm between slams, and back to sleep | ☑ done (2026-11-12; full run 3607/1, standing red only; Play: 6 warnings, biggest frame turn 3.6 deg, arm and cuff at rest 0.5 s after the awake end) | builder, code_lead |
| Wake-up (V2 spec 6) | Task 13: Birds and dust | ☑ done (2026-11-12; full run 3622/1, standing red only; Play: 24 birds behind him, gone by 3.3 s, dust on his body. History: the first Play found wings coming off the real birds (the code took a Wing as the body when there was no PrimaryPart); fixed to pick the first non-Wing part, red test first; re-proof worst gap 0.0000 stud) | builder, code_lead |
| Wake-up (V2 spec 6) | Task 14: The wake shake and the slam shake | ☑ done (2026-11-12; Play run 2: wake biggest 1.313, at rest at 1.05, 2.0 and 9.5 s; slam 10 studs away 0.581, 70 studs away 0; console clean. Run 1 not counted: the wake came during the spawn view raise, which adds to the shake on purpose) | builder, code_lead |
| Wake-up (V2 spec 6) | Task 15: The bonk on screen | ☑ done (2026-11-12; full run 3698/1, standing red only; Play on a real R15 avatar: head 1.13 lying back, still phase steady, back to 4.52 after the end, root moves 0.000, ladder bonk stays upright, stars show. History: the first Play found no tumble, because real R15 rigs use AnimationConstraint joints and the code and fake rigs used Motor6D; fixed to tip through the joint's Transform, red tests first) | builder, code_lead |
| Wake-up (V2 spec 6) | Task 16: The fist on your own screen, and the slam sounds' places | ☑ done 2026-11-12 (OwnFist 12/0, Celebrations 45/0; full run 3732/1, standing red only; Play A on BootLadder_Left: held on, freeze over at 1.02 s, stars by signal; Play B: carrier caught and sent home, poof and "Caught!" card. The screenshots moved to Task 23 item 7, and the carrier's own fist is accepted from Play A plus unit tests (product rulings). A bonk on the spawn spot 6.4 s after a catch follows Rules 60 and 62: not a bug) | builder, code_lead |
| Wake-up (V2 spec 6) | Task 17: The flowers shake | ☑ done 2026-11-12 (FlowerShake 12/0; full run 3744/1, standing red only; Play A: flowers inside real slam circles tip about 12° and rest by 0.5 s, 37 flowers outside never move. The screenshots from the circle's edge moved to Task 23 item 12 (product ruling)) | builder, code_lead |
| Wake-up (V2 spec 6) | Task 18: The one-line wake banner and the bottom tip | ☐ not started | |
| Wake-up (V2 spec 6) | Task 19: RUN HOME! | ☐ not started | |
| Wake-up (V2 spec 6) | Task 20: Red edges while he hunts | ☐ not started | |
| Wake-up (V2 spec 6) | Task 21: Analytics for the hunt | ☑ done (2026-11-12; full run 3575/1, standing red only) | code_lead |
| Wake-up (V2 spec 6) | Task 22: A whole session with wake-ups | ☐ not started | |
| Wake-up (V2 spec 6) | Task 23: The Play proof | ☐ not started | |

## Notes for the next V2 review

- **From other plans' notes:** the red "!" at the wake comes in Tasks 10 and 11 (`new-player-safety.md`, "Task 13 points for later", point 1).
