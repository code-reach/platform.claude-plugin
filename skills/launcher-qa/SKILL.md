---
name: launcher-qa
description: "Drive and verify the MARU launcher running on this PC through this plugin's `launcher` MCP tools — check a screen, reproduce a bug, confirm a UI change, measure an animation, run an install/launch loop. Use when the user asks to test, check, look at, or exercise the launcher (런처 확인해줘, 런처에서 테스트, 런처 화면 봐줘, 런처 스크린샷, 런처 돌려봐, 설치 테스트, 런처 QA), or when a change to the launcher's web UI or native shell needs to be seen working in the real launcher rather than only type-checked."
---

# Launcher QA

Test the MARU launcher that is running on this PC with the `launcher` MCP tools. The tools are the same bridge calls the launcher's web UI makes, plus observation; each rule below exists because skipping it cost real time in a session.

The launcher must already be running — these tools attach to it, they do not start it. If `launcher` shows as failed in `/mcp`, start the launcher and run `/mcp reconnect all`.

## Know what you are driving

- **It is usually the user's own window.** Everything you click happens on their screen. When you are done with a check, put the screen back where it was (close the panel you opened, clear the search box, `navigate` back).
- **Do not press anything that saves or destroys** unless the user asked for that exact action: "변경사항 적용", "삭제", basket delete, `uninstall`, `reset_data`, `quit`. Opening a panel or a popover is fine; committing it is not.
- **Which build decides which tools exist.** Test builds have the test helpers (`eval_js`, `get_console`, `get_bridge_trace`, `emit_event`, `set_device_report`, `reset_data`, `wait_for` with a `js` condition). Production builds do not — the tool list you were given is the truth. Some test builds talk to live services, so installs and play records can land in real data.

## The loop

1. **Where is it:** `get_route`, and `get_state` when install/launch state matters.
2. **Act:** `navigate`, `set_settings`, `install`, `launch`, or `eval_js` for a click.
3. **Wait, don't sleep:** action tools return `eventCursor`; pass it as `since` to `wait_for` (`event`, `route`, or `js` condition). Never emulate waiting with `setTimeout` inside `eval_js` — the tool's result is lost when the expression times out, and you learn nothing about *why* it took long.
4. **Observe:** `screenshot` for what it looks like, `eval_js` for what it *is* (text, sizes, computed styles), `get_console` for errors, `get_events` / `get_bridge_trace` / `get_log_tail` for what happened underneath.
5. **Restore** the screen (see above) and report what you measured, not what you expected.

## `eval_js` that actually works

- **Check once per session:** run `eval_js` with `Promise.resolve(1)`. If it returns `1`, promise results are awaited. If it returns `{}`, the launcher is an older build that drops promise results: write `await <expr>` at the top level instead of returning a promise (an async IIFE included), and treat `wait_for` with a `js` condition as unavailable — it can never pass there.
- **Clicking:** find the element by `aria-label`, visible text, or a stable class fragment (`[class*="basket_chip"]` — CSS-module class names carry a hash), then `.click()`. Prefer `aria-label`; it is translated but stable within a language.
- **Typing into a React input:** a plain `input.value = …` is invisible to React. Use the native setter, then dispatch `input`:
  ```js
  const input = document.querySelector('input[placeholder*="검색"]');
  Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set.call(input, "ㅌ");
  input.dispatchEvent(new Event("input", { bubbles: true }));
  ```
- **Focus events need a foreground window.** `input.focus()` does nothing useful while the launcher window is behind another window; a popup that opens on focus will not open. Drive the same state through an `input` event, or ask the user to bring the window forward.
- **Measuring motion:** sample `getComputedStyle` once per animation frame with a timestamp and return the series. One read proves nothing; a start value, a decaying middle, and an end value do. Keep the samples under a few dozen lines.
- **Sizes in design units:** the web scales by `--dp` on `:root`; divide `getBoundingClientRect()` values by `parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--dp"))` to compare with the 1920×1080 design.

## When something looks wrong, check these before the code

| Symptom | Likely cause | What to do |
|---|---|---|
| `get_log_tail` shows `unknown bridge method: <name>` | The web (dev server) is newer than the launcher exe — a new bridge method was added but the exe was not rebuilt. Native rejects it; the UI shows its generic failure copy | Report it as a stale build, not a bug in the feature. The exe must be rebuilt with the launcher closed (a running exe is locked) |
| A setting "saved" but has no effect (e.g. a new preference field) | Same stale exe: native dropped the field it does not know, the UI still shows what it just sent | `get_preferences` shows what native actually stored; compare with what the UI shows |
| `Application Error … must be used within …Provider` right after a code change | A development build that loads its web UI from a dev server broke on a hot reload (a shared module was re-executed). Development builds only | `eval_js` → `location.reload()`, then continue. Not a code defect |
| Click on a search box does nothing | Window not in foreground; focus event never fired | See *Focus events* above |
| `wait_for` with `js` always times out, even on `1 === 1` | Older launcher build — see the `Promise.resolve(1)` check above | Poll with `eval_js` and top-level `await` instead |
| Fullscreen launcher, want to see 4:3 / 16:9 | Fullscreen follows the monitor; only windowed mode has a fixed ratio | `set_settings { screenMode: "windowed", windowAspectRatio: "4:3" }` when `get_preferences` lists `windowAspectRatio`; restore afterwards |

## Reporting

Say which build you drove (from `get_debug_info`: `env`, `profile`, `launcherVersion`) and whether a check was done on the real launcher or only by type-check / static harness. "Verified in the running launcher" and "typecheck passes" are different claims; make the one that is true.
