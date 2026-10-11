# Readable documents

Every document an agent writes for this project is written so Adam can read it. That covers ideas, look studies, style guides, specs and reviews. Adam is a beginner and reads them himself, so a document he can't understand is not finished.

## Plain English

- Short sentences and simple words. One idea per sentence.
- Explain every game or technical term the first time it appears in a document, in a few words (for example: "retention (players coming back)").
- Prefer a small table or a short list to a long paragraph.
- Say what the player sees and does, not how the code works.

## No bare codes or labels

Never use a code on its own that Adam has to decode. Give everything a name a person understands:

| Don't write | Write |
|---|---|
| `P1` / `P2` / "nice to have" | nothing: there are no priority levels (see `sdd.md`, "In or out") |
| `FR-07` | **Rule 7: Sprinting is loud** |
| Given / When / Then | **Situation** / **Player does** / **Result** |

- A rule keeps its number forever, so other documents can point to it. Always write its short name next to the number, for example "Rule 7 (Sprinting is loud)", never "FR-07" or "Rule 7" alone.
- The same goes for analytics events and file names: say in a few words what each one is.

## Check before handing over

Before a document goes to a review or a gate, re-read it as Adam would. If a line needs knowledge he doesn't have, rewrite it.
