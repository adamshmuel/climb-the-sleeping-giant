---
name: top-games-library
description: The shared library of real gameplay screenshots and summaries of the top Roblox games in references/top-games/ - when to refresh it and how to fill it (Bing image search, curl, summaries). Use when comparing the game with the top games, judging the viral test, or when the library is empty or older than 3 months.
---

# Top games library: `references/top-games/`

Real gameplay screenshots and summaries of the top Roblox games, shared by every agent. It is ignored by git, because other games' pictures belong to those games.

```
references/top-games/
  last-search.txt      date of the last full search (YYYY-MM-DD)
  <game-name>/
    shot-01.jpg ...    real gameplay screenshots
    summary.md         the game's gameplay, explained
```

| State | Do |
|---|---|
| Empty or missing | a full search |
| `last-search.txt` older than 3 months | a full search, replacing the old folders |
| Otherwise | use it, and add any game you need that isn't there |

## Full search

1. **Games:** the top 20 of `top-playing-now` (`roblox-trends` skill, commands 1 and 2, skip sponsored games), plus any games the current work needs, such as an idea's competitors.
2. **Screenshots**, for each game:
   - In the built-in browser, open `https://www.bing.com/images/search?q=<game name> roblox gameplay screenshots`. Not Google: it shows a robot check, and agents never complete such checks.
   - Collect the full-size links with the browser's `javascript_tool`:
     ```js
     [...document.querySelectorAll('a.iusc')].map(a => JSON.parse(a.getAttribute('m')).murl)
     ```
   - Download them with `curl` into the game's own folder, then look at every picture. Keep only real in-game screens that show the world and the buttons. Delete posters, title cards and broken files.
   - Keep at least 5 per game. If fewer, search again with "<game name> roblox screenshot" or "<game name> roblox ui".
3. **Summary**, for each game: web search "<game name> roblox gameplay explained", read the best 2-3 results, and write `summary.md`: the core loop (the action players repeat), progression, what's sold, why players come back, and how it looks. Source links at the bottom.
4. Write today's date into `last-search.txt`.

If a browser tool isn't loaded, load it with `ToolSearch` (for example `select:mcp__Claude_Browser__navigate,mcp__Claude_Browser__javascript_tool`). If it still won't load, stop and tell the main chat which tool is missing.
