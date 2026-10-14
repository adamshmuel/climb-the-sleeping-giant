---
name: roblox-game-naming
description: Research-first naming for a Roblox game. Drills down into about 30 successful games to find how their names link to their gameplay, counts every pattern (and tests any naming idea from the team instead of assuming it), checks crowded words and Roblox's own discovery rules, then proposes 5–8 free names with a pick. Use before proposing or changing a game's name.
---

# Roblox game naming

A name is chosen from data, never from taste or memory. Every naming idea, including one from Adam or another agent (for example "good names name the main character"), is a **guess to test**: count it against the data and report what the data shows, even if it shows the idea is wrong.

Live data comes from the `roblox-trends` skill (commands 1, 2, 4, 9 and 10). Always state the date and time the data was fetched.

## Steps

**1. Read the idea.** From `docs/ideas/<name>.md`, note:
- the core loop (the action players repeat);
- the twist (what's new);
- who it's for;
- what the player collects;
- the main danger.

Write down the reason for the new name, if there is one.

**2. Pick about 30 successful games:**
- the top 20 of Top Playing Now (commands 1 and 2, no sponsored games);
- the top of Top Earning (command 9);
- the biggest breakouts of the last 12–18 months (new games that grew fast). Find them in Up-and-Coming and Top Trending with creation dates (command 4), and in recent articles, such as a web search for "fastest growing Roblox games <year>".

Get each game's core loop from the shared library `references/top-games/` (see `agent-workflow.md`), or from its description.

**3. Drill-down table:** one row per game, with these columns:

| Column | What goes in it |
|---|---|
| Name | As shown on Roblox |
| Words | How many words |
| Points to | Everything the name tells a kid: **action** (what you do), **thing** (what you collect or use), **creature** (a kind of animal or character), **main character** (one named character), **enemy** (what you face or avoid), **place**, **goal**, **made-up word**, **mood word only** (says nothing about the gameplay), **number** |
| Starts with an action word | yes / no |
| Core loop | A few words |
| Strength | Players now, peak (most players at once, with its source), and creation year |

**4. Count the patterns.** For each "points to" type, and for word count and "starts with an action word", give a count such as "14 of 30". Then:
- split the counts for games made in the last 2 years, and for the 5 biggest peaks;
- rate each pattern **strong**, **medium** or **weak**;
- test every naming idea from the team the same way, under its own heading ("<idea>, tested").

**5. Our own corner.** Find 5–10 games in the idea's own subgenre (search Roblox with command 10 for the core action and the main creature). Count what their names point to. A pattern that holds only in this corner is reported as a corner pattern.

**6. Crowded words.** Across every game name on today's charts (commands 1, 2 and 9), count the words the name might use: the main noun, the action and genre words. Words in many chart names are crowded. A word in none is open, and can make us stand out.

**7. Roblox's own rules.** Read the live pages `https://create.roblox.com/docs/discovery` and `https://create.roblox.com/docs/discovery-faq` (with the `roblox-docs` skill or WebFetch). Note what they say about original titles, copy-looking titles and names that must match the gameplay. Rules on those pages are hard limits.

**8. Propose 5–8 names** built from the strong patterns, the open words and Roblox's rules. For each one:
- the patterns it uses;
- what a kid reads from the name alone;
- its weak spots;
- whether any Roblox game already uses it or something close (command 10, searching the full name and its key words).

A name already in use, crowded with copies, or likely to look like a copy of a top game is out. If an earlier name list exists, include those names in the table and judge them by the same rules.

**9. Pick one:**
- the reason, in one line;
- what the icon has to show to cover the name's weak spots;
- a starting choice and the result that would change it. For example: "if the icon's click rate in the first week is below the average for similar games, test <name 2>".

## Output

Write `docs/ideas/name-research.md`, following `.claude/rules/readable-docs.md`. Explain every term the first time it is used. In this order:
1. the data date, and why a new name is needed;
2. the drill-down table;
3. the patterns, with counts, and each team idea tested;
4. our own corner;
5. crowded and open words;
6. Roblox's rules;
7. the name options table;
8. the pick;
9. sources: every chart, article and guide, with links. Then a line on what couldn't be found. No article proves that a naming style causes success; say so.

The file only proposes. Renaming the idea file, the design folder or anything else happens only after Adam picks the name.

Reply with:
- the file path;
- the 3 strongest patterns, one line each, with counts;
- what each team idea showed;
- the name options table;
- the pick and its reason.
