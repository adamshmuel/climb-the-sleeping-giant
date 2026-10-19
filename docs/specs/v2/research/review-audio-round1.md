# Spec 7 (audio), review round 1 (2026-10-19)

Reviews of product's write-up of designer's answers, saved in full so a product agent can apply them.

## designer: changes (6)
All 28 sound-table rows, Rule 98 (The music button) and section 6 match designer's answers and the mockups. The "nobody has listened yet" wording is honest.

1. **Section 1, "Loudness" (and the scale note in section 5):** don't state that 0.5 "plays a file as it was recorded". The Roblox docs only say 0.5 is the default (`Sound.Volume`, checked 2026-10-19). Fix: "0.5 is Roblox's default. This spec assumes it plays a file as recorded; the docs don't say so."
2. **Section 7, "What they share", point 3:** only Don't Steal the Bobo shows a one-tap mute; the other four show a gear whose menu wasn't checked. Fix: "Sound controls sit in the top bar. Five of these games put a speaker or gear button there. Only Don't Steal the Bobo's is shown to be a one-tap mute."
3. **Top note and section 9, "Nobody has heard the sounds":** say who judges. Fix: "Any sound Adam says sounds wrong at the Gate 4 listen is swapped by designer (measured silently, with the same checks). Adam hears the new sound at his next listen."
4. **Section 8 ("A sound doesn't load") and section 9 ("A sound disappears"):** team tests are muted (Rule 99). Fix: "The build check loads and plays every sound once, muted, and fails if one doesn't load."
5. **Section 5, "Other values", "Phone check line", the trigger:** the phone simulator copies the screen and touch, not the speaker ("Studio testing modes", "Device simulation"). Tightening to 6 dB would fail 7 picks at once (calm tune −6.4, "!" sting −6.1, rumble −6.5, yawn −6.5, Rare happy hit −6.5, mumble −8.1, egg pop −8.5). Fix: "A sound that is hard to hear on a real phone (spec 10's check): first raise its loudness one step, up to the crackle limit. If it's still hard to hear, designer swaps that sound for one that loses 6 dB or less." Add to Rule 87 (Phone speakers first): "Checked on a real phone in spec 10. Until then, the phone check in section 5 stands in."
6. **Section 9, "The mix was never heard", triggers:**
   - Crackle: add "in steps of a quarter. If that puts it below its place in the order (for example the roar quieter than the snore), designer swaps it instead."
   - Clash: "**the calm tune** is turned down by a quarter" (only the calm tune plays with the snore; Rule 90). That is 0.2 → 0.15, the same as the music-off trigger.

**Product's point 2, one sound used twice: keep it.** The new-egg sparkle and the bonk twinkle both use Magic Glows 2 (9116394876, loudness 2.6). Both go with gold sparkles, a bonk always adds the comic hit, and the other measured picks are already used. Add:
- New trigger: "If at Gate 4 Adam can't tell a new egg's sparkle from a bonk, designer swaps the sparkle pop for another Magic Glows file with the same checks."
- Rule 86 (Three ways to hear): the "at most 3 copies" limit counts each row of the table on its own, so bonks never mute a new egg's sparkle.

**Product's point 4, self-set triggers:** phone check to 6 dB → change 5. Small-phone gap 16 px: approve. Crackle: approve with change 6. Tune clash: approve, named as the calm tune.

**Product's point 5:** no retake. designer renames `test-music-small-phone.png` to `hud-music-small-phone.png` (and its mentions in `build-check.md` and the style guide). product then updates the spec's two mentions (section 5 "Small-phone move", section 6 "Small phone").

## game_creator: changes (9)
Core loop, twist and Mild rating hold. Nothing touches money. No sound was treated as heard.

**Product's point 1, Rule 99:** confirmed: the mute covers the team's test sessions only. Adam's Gate 4 playtest plays with sound on. Put it in the rule (item 2).
**Product's point 3, the 85% snort: yes, it gets its own sound** (every other thing the giant does on screen makes a sound; the warning is weaker from the gardens without the arm twitch; it completes "snort, snort, silence, Mmm..."; Rule 88 still holds). designer picks it; try first one breath cut from our own snore file (9114663574). "Mumble from his mouth" with the bubble by his nose is fine.
**Product's point 4:** the self-set triggers are fine except the party-horn one (item 4).
**designer's swaps:** keep the party-horn toot (a voice cheer would wear thin on every egg home). Keep the tired lion roar as the starting yawn, with a firmer fallback (item 6). Roblox's spring sound as the boing is fine; APMOfficial "Up and Over" (1841186808) is the first swap if it sounds thin.

1. **Rule 91 (The mumble), Rule 89 (Music follows the meter) and section 5: add the snort sound.** Two short snorts (0.5 s or less each) from his nose tip, whole-valley group, one with each puff burst (0 s and 0.5 s). The mumble starts at 1.0 s and lasts 2.1 s, ending about 3.1 s, before the bubble goes. Music and snore start fading at the 85% moment and are silent by 1.0 s (reword Rule 89's "starting at the same moment as the mumble"). The snorts replay with every free save (Rule 17), not when the meter passes 85 during the replay. Starting loudness about the snore's; designer sets it. Trigger: if the snorts and the mumble blur, or the snort sounds gross or scary, designer swaps it; if testers don't notice the 85% silence, drop the snort sound.
2. **Rule 99: add** "Adam's Gate 4 playtest is not a test session; it plays with sound on." The Gate 4 listen is a normal session plus a short sound check the team sets up while the game runs, triggering once each moment a session rarely reaches (an egg home of each rank, a free save, the yawn, a rescue). Nothing in that setup is saved.
3. **Section 1 "Words used here", sections 7 and 9: fix two store claims.** A partner children's cheer exists (APMOfficial "Yeah", 1841221347) and partner boings exist ("Up and Over", 1841186808; "Fun Effect 11", 1839865512). Say the toot and the spring were chosen, not forced.
4. **Section 9, "party horn feels small" trigger: keep the rank ladder.** New trigger: Common and Uncommon get a short layer of their own, smaller than the Rare's hit; designer picks it.
5. **Rule 95: Legendary must sound bigger than Epic.** Legendary adds a third layer; designer picks it, checking APMOfficial "Yeah" first. Trigger: if it clashes with the fanfare at Gate 4, it plays 0.5 s after the fanfare starts.
6. **Rule 92 and section 9, the yawn:** the lie-down sound must say "safe again" and never reuse the roar or mumble files. Calmer option to try: "Lion Roar Tired 13" (9116304896). Final fallback, decided now: if no partner sound passes the phone check and the Gate 4 listen, no yawn; the Heavy Sleep snore starts at the lie-down.
7. **Rule 90 and section 9: the snore must not wear players out** (a 5.7 s loop heard all session; the music button can't turn it off). Starting choice: each breath at a slightly different speed (0.95–1.05, random), or alternating two takes; designer picks. New risk row "The snore annoys". Trigger: if testers call it annoying after 10 minutes, lower it by a quarter on his body, same at the gardens.
8. **Rule 90, Heavy Sleep wording:** "for the 45 seconds" → "for as long as Heavy Sleep lasts (45 seconds after a wake-up)", so spec 9's paid Lullaby (60 s) needs no rule change.
9. **Section 5 sound table:** add the snort row and the Legendary layer row.

Re-checked against the idea, the look (designer checks items 1, 3, 5, 6, 7, 9), business goals and standards.

## Also for the product agent that applies this round (from the specs 1, 3, 4, 5 update, 2026-10-19)
- Set every V2 spec's status to `approved` (Adam approved all 7 on 2026-10-18) in `docs/specs/v2/index.md` and in each spec's header, including spec 3's "in review".
- `wake-up.md`: add a build-review check for designer's known weak spot: the cap ladder stays put while his head tips, so it crosses his open face from gardens 4 and 5 (`view-wake-face.png`, `view-phone-wake-cuff-g4/g5`).
- Spec 7, sections 5 and 6: `test-music-small-phone.png` is now `hud-music-small-phone.png`.

## Round 2 (2026-10-19)
- game_creator: **approve** (all 9 items and its 3 acceptances are in).
- designer: 2 wording fixes (section 2's mute button; "no yawn … was found" in sections 7 and 9), applied by product, then **approve**.
Spec 7 is final.
