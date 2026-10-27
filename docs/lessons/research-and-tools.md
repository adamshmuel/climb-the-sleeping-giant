# Lessons: Research and tools

About searching the web, finding reference pictures, and adding or trying tools. The map of all lessons is `docs/lessons/index.md`.

## Lesson 15: Search before guessing, and Bing works for images
- **What happened:** agents decided from memory. When they searched for pictures, Google and DuckDuckGo blocked them with "prove you're not a robot" checks, the web search tool gave only text, and store pages showed posters, not gameplay (2026-10-11).
- **Do instead:** research with the web search tool, the built-in browser and the plugin catalog before deciding. For gameplay pictures use Bing Images in the built-in browser (the steps are in `agent-workflow.md`, "Shared reference library"). Look at every picture and keep only real gameplay.
- **Who checks:** every agent.

## Lesson 16: A new tool works only after a fresh start
- **What happened:** agents couldn't use the browser because it wasn't on their allowed-tools list. Tools added to a list during a session didn't reach an agent that was already running (2026-10-11).
- **Do instead:** after adding a tool to an agent's list, test it with a freshly started agent before relying on it. If a tool is missing, load it with `ToolSearch`, and if that fails, stop and tell the main chat.
- **Who checks:** the main chat.

## Lesson 17: Don't install unknown tools
- **What happened:** the only image-search tool found (an MCP server) had no stars, no installs and an unknown author (2026-10-11).
- **Do instead:** never install a tool that isn't verified. Use what's proven (the built-in browser) and say what wasn't tested.
- **Who checks:** the main chat.

## Lesson 18: Clean up after a test, and say what's left
- **What happened:** test folders and models were built in Studio, and generated models and uploaded icons land on Adam's Roblox account as private items the tools can't delete (2026-10-11).
- **Do instead:** delete test folders and objects in the same session. Report anything left behind, such as items on Adam's account.
- **Who checks:** every agent that tests in Studio.
