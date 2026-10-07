---
name: roblox-trends
description: Fetch live Roblox charts (Top Trending, Up-and-Coming, Top Playing Now, Fun with Friends, Top Revisited) with player counts, genres, subgenres, creation dates and descriptions, plus a game's game-pass prices, badge award counts, icons and store thumbnails, and DevForum discussions. Use when researching what's popular or growing on Roblox right now. Repairs its own URL table if Roblox changes the addresses.
---

# Roblox trends

Live chart data from Roblox. The addresses are **unofficial and undocumented**, so check every response and self-heal if one breaks. Always state the date the data was fetched, because charts change daily. Never invent player numbers.

## URL table

| Data | URL | Limits | Last verified |
|------|-----|--------|---------------|
| Charts | `https://apis.roblox.com/explore-api/v1/get-sorts?sessionId=<uuid>` | `sessionId` required (400 without it). ~60–100 games per list | 2026-10-06 |
| Game details | `https://games.roblox.com/v1/games?universeIds=<id,id,...>` | **max 50 ids** per request (more returns 400) | 2026-10-06 |
| Game passes | `https://apis.roblox.com/game-passes/v1/universes/<id>/game-passes?passView=Full&pageSize=100` | one universe per request, **max 100** per page (`nextPageToken`) | 2026-10-06 |
| Badges | `https://badges.roblox.com/v1/universes/<id>/badges?limit=100&sortOrder=Asc` | one universe per request, `limit` must be 10/25/50/100 (`nextPageCursor`) | 2026-10-06 |
| Game icons | `https://thumbnails.roblox.com/v1/games/icons?universeIds=<id,id,...>&size=512x512&format=Png` | returns image URLs; download each with curl | 2026-10-07 |
| Game thumbnails | `https://thumbnails.roblox.com/v1/games/multiget/thumbnails?universeIds=<id,id,...>&countPerUniverse=10&size=768x432&format=Png` | `1920x1080` returns 400, use `768x432` | 2026-10-07 |
| DevForum search | `https://devforum.roblox.com/search.json?q=<url-encoded query>` | ~50 topics per search | 2026-10-06 |
| Fallback page | `https://www.roblox.com/charts` | HTML only, use WebFetch | 2026-10-06 |

Chart lists (`sortId`): `top-trending`, `up-and-coming`, `top-playing-now`, `fun-with-friends`, `top-revisited`.

Fields used:
- Charts games: `name`, `universeId`, `playerCount`, `genreL1`, `totalUpVotes`, `totalDownVotes`, `isSponsored`
- Details: `genre_l1`, `genre_l2` (subgenre), `created`, `updated`, `visits`, `playing`, `favoritedCount`, `description`
- Game passes: `gamePasses[].name`, `price`, `isForSale`
- Badges: `data[].name`, `statistics.awardedCount`
- Icons: `data[].targetId`, `imageUrl`, `state` (use only `Completed`)
- Thumbnails: `data[].universeId`, `thumbnails[].imageUrl`, `state`
- DevForum: `topics[].title`, `slug`, `id`, `posts_count`

## Commands

Quote URLs (zsh treats `?` as a wildcard). Sponsored games are ads, so skip them.

**1. Fetch the charts** (expect `200`):
```bash
curl -s "https://apis.roblox.com/explore-api/v1/get-sorts?sessionId=$(uuidgen)" -o /tmp/sorts.json -w '%{http_code}\n'
```

**2. Games in one list** as `name | genre | players | upvote %`:
```bash
jq -r '.sorts[] | select(.sortId=="up-and-coming") | .games[] | select(.isSponsored|not) | "\(.name) | \(.genreL1) | \(.playerCount) | \(if (.totalUpVotes+.totalDownVotes)>0 then (100*.totalUpVotes/(.totalUpVotes+.totalDownVotes)|floor) else "-" end)%"' /tmp/sorts.json
```

**3. Genre summary,** with the top genres per list by total players:
```bash
jq -r '.sorts[] | select(.games) | .sortId as $s | [.games[] | select(.isSponsored|not)] | group_by(.genreL1) | map({g: .[0].genreL1, n: length, p: (map(.playerCount)|add)}) | sort_by(-.p)[:4][] | "\($s) | \(.g) | \(.n) games | \(.p) players"' /tmp/sorts.json
```

**4. Details for one list,** with subgenre, creation date and description, newest first. Use ≤50 ids per request; for more, split into batches.
```bash
ids=$(jq -r '[.sorts[] | select(.sortId=="up-and-coming") | .games[] | select(.isSponsored|not) | .universeId][:50] | join(",")' /tmp/sorts.json)
curl -s "https://games.roblox.com/v1/games?universeIds=$ids" | jq -r '.data | sort_by(.created) | reverse[] | "\(.name) | \(.genre_l1) > \(.genre_l2) | created \(.created[:10]) | \(.description[:80] | gsub("\n";" "))"'
```

**5. Monetization of one game:** what it sells and at what price. Set `id` to a `universeId` from step 2.
```bash
curl -s "https://apis.roblox.com/game-passes/v1/universes/$id/game-passes?passView=Full&pageSize=100" | jq -r '.gamePasses[] | select(.isForSale) | "\(.name) | \(.price) Robux"'
```

**6. Player funnel of one game:** how many players earned each badge, most first.
```bash
curl -s "https://badges.roblox.com/v1/universes/$id/badges?limit=100&sortOrder=Asc" | jq -r '.data | sort_by(-.statistics.awardedCount)[] | "\(.name) | \(.statistics.awardedCount) players"'
```

**7. Developer discussion** on a topic, e.g. a subgenre plus `retention` or `monetization`:
```bash
curl -s "https://devforum.roblox.com/search.json?q=$(jq -rn --arg q 'tycoon retention' '$q|@uri')" | jq -r '.topics[:10][] | "\(.title) | \(.posts_count) posts | https://devforum.roblox.com/t/\(.slug)/\(.id)"'
```

**8. Look of a set of games:** download icons and thumbnails into a folder (`out`), then view the images. Set `ids` to comma-separated `universeId`s.
```bash
mkdir -p "$out"
curl -s "https://thumbnails.roblox.com/v1/games/icons?universeIds=$ids&size=512x512&format=Png" | jq -r '.data[] | select(.state=="Completed") | "\(.targetId) \(.imageUrl)"' | while read id url; do curl -s -o "$out/$id-icon.png" "$url"; done
curl -s "https://thumbnails.roblox.com/v1/games/multiget/thumbnails?universeIds=$ids&countPerUniverse=10&size=768x432&format=Png" | jq -r '.data[] | .universeId as $u | .thumbnails | to_entries[] | select(.value.state=="Completed") | "\($u)-thumb\(.key) \(.value.imageUrl)"' | while read name url; do curl -s -o "$out/$name.png" "$url"; done
```

## Reading the signals

- **Growing:** genres or subgenres that are strong in `up-and-coming`.
- **Breakout:** a game created in the last few weeks that is already in the charts.
- **Big but crowded:** genres that dominate `top-playing-now`. There's lots of demand, but also lots of competition.
- **Sticky:** `top-revisited` shows what keeps players coming back.
- **Social:** `fun-with-friends` shows what people play together.
- **Quality:** a low upvote % on a popular game means players want a better version of it.
- **Pricing:** game-pass names and prices show what players of a genre already pay for (cosmetics, boosts, access).
- **Drop-off:** the first badge is usually given on joining. Compare later badges to it. A big drop shows where most players quit.
- **Lessons:** DevForum posts are opinions, not data. Use them to explain the numbers, never as numbers.

## Self-heal when something fails

A failure is a status other than 200, a `jq` error, or empty or missing fields (e.g. no `sorts`, no `genreL1`).

1. **Retry once** with a fresh `sessionId`.
2. **WebSearch** for the current address, e.g. `roblox explore-api get-sorts`, `roblox games api universeIds`, and Roblox's open-cloud or legacy API docs.
3. **Confirm the new address** returns 200 and has the fields this skill uses (adjust the `jq` field names if they were renamed).
4. **Edit this file:** update the URL table row (address, limits, today's date) and the commands. Tell the user what changed (old → new).
5. **Fallback:** WebFetch `https://www.roblox.com/charts` for names and genres only. Say that the data is partial.
6. **If nothing works,** say that live trend data is unavailable. Never fill the gap from memory.
