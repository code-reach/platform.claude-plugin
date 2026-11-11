---
name: release-program
description: "Upload a MARU launcher (or other managed program) build or a MARU updater Setup installer and release it to the TEST track with this plugin's MARU MCP tools — hash, presigned upload, register, test release, verify. Use when the user asks to release, deploy, publish, upload, or roll back a launcher/updater build on test, or says 런처 릴리스, 런처 배포, 업데이터 배포, 테스트 트랙에 올려, 새 버전 올려줘, 테스트 릴리스, 롤백해줘."
---

# Release a Program to the Test Track

Ship a new build of a managed program (the launcher, …) or of maru-updater through the MARU MCP tools this plugin provides, and stop at the **test** track. The order below is also the checklist: each step exists because skipping it has a concrete failure.

The tools are this plugin's MARU MCP server tools — refer to them by their short names below. Which environment you are on is visible from the tool list: `release_updater_test` exists only on the test server.

## What these tools will not do — and you must not work around

- **Promote to prod, or pin the updater on production.** Those reach customer PCs and cannot be undone, so a person does them in admin-web. There is no tool for them on purpose. Do not try another route (admin-web automation, direct API calls with other credentials, anything else) — tell the user it is theirs to do.
- **Send the file as a tool argument.** Builds are tens of megabytes. The file goes from this machine straight to storage with a presigned URL; the tools only prepare and register it.

## Procedure

1. **Confirm the target.** Call `list_programs` and find the program's `id`, `key`, and the version currently pinned on `test` and `prod`. Tell the user in one line which environment this is. If it is the production server, add that a test release there still reaches real devices whose release track is `test`.
2. **Choose the version.** Call `list_program_versions` (for the updater, `list_updater_versions`) and pick a `major.minor.patch` higher than every existing one. Match the build's own FileVersion — a registered version number cannot be reused.
3. **Build.** Follow the project's build documentation. For the WinUI launcher, the publish must keep `PublishTrimmed=false` and `PublishReadyToRun=false`; either one produces an installer that installs and then dies silently. The updater artifact is `MaruUpdater-Setup-<v>-x64.exe`, with an optional same-build `…-x64-manifest.json`. Do not upload the old ForUpload ZIP. First installation and recovery of a broken updater service use this same installer, run by a person; later updates are installed by the updater service.
4. **Hash and size, locally.**
   - PowerShell: `Get-FileHash -Algorithm SHA256 <file>` and `(Get-Item <file>).Length`
   - bash: `sha256sum <file>` and `stat -c %s <file>` (macOS: `shasum -a 256`, `stat -f %z`)
5. **Prepare, then upload immediately.** Call `prepare_program_upload` (or `prepare_updater_upload`) with the file name, the exact size in bytes, and the local path. Run the returned command right away — `curl_windows_powershell` in Windows PowerShell, `curl_posix` in bash — and check its exit code.
   - The URL is signed for that exact size and lives 10 minutes. If it expires, call `prepare_*` again.
   - In Windows PowerShell use `curl.exe`, never `curl` (an alias of `Invoke-WebRequest`). The returned command already does.
   - The URL is a credential while it lives. Do not print it again or paste it anywhere else.
6. **Register and compare.** Call `register_program_version` (or `register_updater_version`) with the returned `s3_key`, the version numbers, and your local `expected_sha256` / `expected_size`. For the updater, upload only the Setup EXE. If its manifest is available, parse the JSON locally and pass it as `manifest` to `register_updater_version`; do not upload the manifest separately. Without it, use the installer AppVersion. The server checks MZ, hashes the uploaded object, and compares a supplied manifest filename, hash and version; the tool reports `hash_matches` and `size_matches`.
   - **Service-type programs register with the manifest.** When `list_programs` shows `install_type` `service` (e.g. assist-agent), the server needs the install target (folder, Windows service name, executable, health check) and refuses the registration without it. The flow:
     1. Upload the installer under **the exact file name the build produced** — pass it unchanged as `filename` to `prepare_program_upload`. The server matches the manifest's `package_file` against the uploaded name; a renamed upload fails with `MANIFEST_PACKAGE_MISMATCH`.
     2. Pass the same build's `…-x64-manifest.json` as `manifest` to `register_program_version` (the file content as text, or the parsed object). The server also compares its `package_hash` and `version` with the upload. Only when the build has no manifest, pass `target` (`exe_filename`, `service.dir`, `service.name`, `service.health`) — never both. Launcher-type programs pass neither; the tool refuses them on any other program type.
     3. Errors come back with the server's own text and a `hint`. `MANIFEST_PACKAGE_MISMATCH`: you used another build's manifest or renamed the installer — pair the right two files, re-upload under the original name if needed. `TARGET_MISMATCH`: this build installs to a different folder, service or executable than earlier versions — do not retry; changing it means a new program, which a person sets up in admin-web. `SERVICE_DIR_IN_USE` / `SERVICE_NAME_IN_USE`: another program owns that folder or service name — stop and report. `SERVICE_METADATA_MISSING`: the manifest lacks service info — rebuild with the current installer script.
   - A registration that failed after a successful upload does not need a new upload: call `register_program_version` again with the same `s3_key` (it works while no version row exists for that upload).
   - On any mismatch: **stop and report. Do not release.** The version row stays but reaches no device unless released; re-upload under a new version number.
   - `ALREADY_EXISTS` means that version number (or that upload) is already registered — go back to step 2.
7. **Release to test.** Get the user's approval for this version and target before calling `release_program_test` (updater on the test server: `release_updater_test`); an explicit request for that exact release is sufficient. Honor any additional Claude Code or Codex tool-approval prompt. Tool annotations alone do not guarantee a prompt. On the production server the updater has no pin tool: stop here and go to step 9.
8. **Verify.** Call `verify_program_test_release` with the program and version ids. Success means the database test pin **and** the public test manifest both show this version and its hash. A version string alone is not proof — the manifest falls back to prod when no test pin exists. For the updater, confirm with `list_updater_versions` that the new version is `pinned`.
9. **Report.** Give the version, the server hash, and what is pinned where. Close with: promotion to prod is done by a person in admin-web (launcher: promote; production updater: pin).

## Rolling back

Release the previous version id to test with the same step 7 tool. Versions are never deleted by these tools, so every earlier build stays available to re-pin.

## When a call fails

- **403 / "not a platform admin"** — the account may log in but lacks the role; releases need a platform admin. Say so; do not retry.
- **The MCP server asks to log in again** — the connection was revoked or expired. In Claude Code, use `/mcp` → the MARU server → Authenticate. In Codex CLI, run `codex mcp login <server-name>` (`maru-platform-test` or `maru-platform`) and start a new session after browser consent. In a Codex app or IDE, use that client's MCP Authenticate control. Never copy another client's tokens or session files.
- **Anything else** — report the tool's error text as-is and stop before any further release step.
