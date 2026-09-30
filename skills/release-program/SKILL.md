---
name: release-program
description: "Upload a MARU launcher (or other managed program) build or a maru-updater zip and release it to the TEST track with this plugin's MARU MCP tools — hash, presigned upload, register, test release, verify. Use when the user asks to release, deploy, publish, upload, or roll back a launcher/updater build on test, or says 런처 릴리스, 런처 배포, 업데이터 배포, 테스트 트랙에 올려, 새 버전 올려줘, 테스트 릴리스, 롤백해줘."
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
3. **Build.** Follow the project's build documentation. For the WinUI launcher, the publish must keep `PublishTrimmed=false` and `PublishReadyToRun=false`; either one produces an installer that installs and then dies silently. The updater artifact is a zip with `maru-updater.exe` at its root.
4. **Hash and size, locally.**
   - PowerShell: `Get-FileHash -Algorithm SHA256 <file>` and `(Get-Item <file>).Length`
   - bash: `sha256sum <file>` and `stat -c %s <file>` (macOS: `shasum -a 256`, `stat -f %z`)
5. **Prepare, then upload immediately.** Call `prepare_program_upload` (or `prepare_updater_upload`) with the file name, the exact size in bytes, and the local path. Run the returned command right away — `curl_windows_powershell` in Windows PowerShell, `curl_posix` in bash — and check its exit code.
   - The URL is signed for that exact size and lives 10 minutes. If it expires, call `prepare_*` again.
   - In Windows PowerShell use `curl.exe`, never `curl` (an alias of `Invoke-WebRequest`). The returned command already does.
   - The URL is a credential while it lives. Do not print it again or paste it anywhere else.
6. **Register and compare.** Call `register_program_version` (or `register_updater_version`) with the returned `s3_key`, the version numbers, and your local `expected_sha256` / `expected_size`. The server hashes the uploaded object itself; the tool reports `hash_matches` and `size_matches`.
   - On any mismatch: **stop and report. Do not release.** The version row stays but reaches no device unless released; re-upload under a new version number.
   - `ALREADY_EXISTS` means that version number (or that upload) is already registered — go back to step 2.
7. **Release to test.** Call `release_program_test` (updater on the test server: `release_updater_test`). Claude Code asks for approval because the tool is marked destructive — let the user approve it. On the production server the updater has no pin tool: stop here and go to step 9.
8. **Verify.** Call `verify_program_test_release` with the program and version ids. Success means the database test pin **and** the public test manifest both show this version and its hash. A version string alone is not proof — the manifest falls back to prod when no test pin exists. For the updater, confirm with `list_updater_versions` that the new version is `pinned`.
9. **Report.** Give the version, the server hash, and what is pinned where. Close with: promotion to prod is done by a person in admin-web (launcher: promote; production updater: pin).

## Rolling back

Release the previous version id to test with the same step 7 tool. Versions are never deleted by these tools, so every earlier build stays available to re-pin.

## When a call fails

- **403 / "not a platform admin"** — the account may log in but lacks the role; releases need a platform admin. Say so; do not retry.
- **The MCP server asks to log in again** — the connection was revoked or expired. The user re-authenticates with `/mcp` → the MARU server → Authenticate.
- **Anything else** — report the tool's error text as-is and stop before any further release step.
