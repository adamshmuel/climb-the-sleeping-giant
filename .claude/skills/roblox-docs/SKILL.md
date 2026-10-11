---
name: roblox-docs
description: Look up current official Roblox documentation (Engine API classes, datatypes, enums, globals, libraries, creator guides). Use before writing or explaining any Roblox API usage instead of relying on memory. Repairs its own URL table if Roblox moves the docs.
---

# Roblox docs lookup

The docs are served as clean markdown at `create.roblox.com/docs/...md`. Never guess API names or signatures from memory: look them up.

## URL table

| Kind | URL pattern | Last verified |
|------|-------------|---------------|
| Class | `https://create.roblox.com/docs/reference/engine/classes/<ClassName>.md` | 2026-10-06 |
| Datatype | `https://create.roblox.com/docs/reference/engine/datatypes/<TypeName>.md` | 2026-10-06 |
| Enum | `https://create.roblox.com/docs/reference/engine/enums/<EnumName>.md` | 2026-10-06 |
| Global | `https://create.roblox.com/docs/reference/engine/globals/<GlobalName>.md` | 2026-10-06 |
| Library | `https://create.roblox.com/docs/reference/engine/libraries/<lib>.md` | 2026-10-06 |
| Guide | `https://create.roblox.com/docs/<path>.md` (e.g. `scripting/events/remote.md`) | 2026-10-06 |
| Engine index | `https://create.roblox.com/docs/reference/engine/llms.txt` | 2026-10-06 |
| Site/guide index | `https://create.roblox.com/docs/llms.txt` | 2026-10-06 |
| Plain-language search | `https://create.roblox.com/docs/api/search/<url-encoded question>` (JSON: `results[].title/url/summary`) | 2026-10-11 |
| Deprecated APIs | `https://create.roblox.com/docs/reference/engine/deprecated.md` | 2026-10-06 |
| Locale fallback | same paths with `/docs/en-us/...` | 2026-10-06 |

## Lookup

1. Don't know the exact name or page? Ask the official search in plain words, then open the top `url` (add nothing, it already ends in `.md`):
   `curl -s "https://create.roblox.com/docs/api/search/$(jq -rn --arg q 'how to secure remote events' '$q|@uri')" | jq -r '.results[:5][] | "\(.title) | \(.url)"'`
   Or search the index:
   `curl -s https://create.roblox.com/docs/reference/engine/llms.txt | grep -i <term>`
   (guides: `curl -s https://create.roblox.com/docs/llms.txt | grep -i <term>`)
2. Check the page exists:
   `curl -s https://create.roblox.com/docs/reference/engine/classes/RemoteEvent.md -o /dev/null -w '%{http_code}'`
3. Read only what you need:
   `curl -s https://create.roblox.com/docs/reference/engine/classes/RemoteEvent.md | grep -n -i -A8 OnServerEvent`
   Fetch the whole page only when the section isn't enough. Members inherited from a superclass live on the superclass page (e.g. `Anchored` is on `BasePart`, not `Part`).

The MCP `http_get` tool (from the Studio MCP `rbx-docs-search` skill) works on the same URLs. Prefer it when it succeeds. As of 2026-10-06 it fails with "HttpRequest.Url is not trusted", so curl is the default.

## Self-heal when a URL fails (anything other than 200)

A missing page returns a clean 404. On a non-200 response:

1. **Search the matching `llms.txt` index** for the name. Each index line gives the canonical path, e.g. `- [RemoteEvent](/docs/reference/engine/classes/RemoteEvent.md)`. If the path shown differs from the table pattern, the pattern has moved.
2. **If the index itself fails**, try the `/docs/en-us/...` form, then WebSearch `site:create.roblox.com <name>` and WebFetch the result to find the new page or index location.
3. **Confirm the new URL returns 200** with the status check above.
4. **If a pattern moved** (not just one renamed or removed API), edit the URL table in this file: replace the row's pattern, set its date to today, and tell the user what changed (old → new).
5. **If nothing resolves**, say the docs couldn't be reached and that the answer is from memory and unverified. Never present a guessed API as checked.

A single missing page whose name isn't in the index usually means the API was renamed or removed. Check `deprecated.md` before touching the table.
