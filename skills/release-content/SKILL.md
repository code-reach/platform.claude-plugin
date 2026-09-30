---
name: release-content
description: "Upload a new build of a MARU content (application, video or webview package) owned by your vendor organization and release it to the TEST track with this plugin's MARU MCP tools — create version, local hash, upload script, complete, test release, check status. Use when the user asks to upload, release, deploy, publish or roll back a content build or package on test, or says 콘텐츠 올려줘, 콘텐츠 새 버전, 콘텐츠 배포, 테스트 트랙에 올려, 테스트 릴리스, 패키지 업로드, 롤백해줘."
---

# Release a Content Build to the Test Track

Ship a new build of a content your organization owns through the MARU MCP tools this plugin provides, and stop at the **test** track. The order below is also the checklist: each step exists because skipping it has a concrete failure.

The tools appear only for accounts that manage a vendor organization (owner or admin) or are platform admins. Refer to them by their short names below.

## What these tools will not do — and you must not work around

- **Release to prod, change visibility (published/hidden), archive, delete, or edit the content's page.** These reach customers or cannot be undone, so a person does them in the console. The server refuses them for AI tokens (`DELEGATED_NOT_ALLOWED`). Do not try another route — tell the user it is theirs to do.
- **Create a content.** A content is registered by a person in the console; these tools only add versions to an existing one.
- **Handle `web` or `stream` contents.** Those have no package; the tools answer `UNSUPPORTED_RUNTIME`.
- **Send the file as a tool argument.** The file goes from this machine straight to storage with presigned URLs; the tools only prepare and confirm it.

## Procedure

1. **Find the content.** Call `list_my_contents` and pick the content by `key` or name. Note its `id`, `runtime` (`application`, `video`, `webview`) and `status`. If it is `hidden` or archived, tell the user now: test devices cannot install it until a person changes that in the console. Tell the user in one line which environment this is — the MCP server is `maru-test` on the test server and `maru` on production. On production, add that a test release still reaches real devices whose release track is `test`.
2. **Choose the version string.** Call `list_content_versions` (for `application`, with the `platform`). Pick a string not used yet — at most 30 characters, free-form, and it cannot be reused even after a failed upload. Match the build's own version when it has one.
3. **Hash and size, locally.**
   - PowerShell: `Get-FileHash -Algorithm SHA256 <file>` and `(Get-Item <file>).Length`
   - bash: `sha256sum <file>` and `stat -c %s <file>` (macOS: `shasum -a 256`, `stat -f %z`)
4. **Create the version.** Call `create_content_version`.
   - `application`: `platform` and `exe` (the executable's path inside the package, e.g. `Game.exe`) are required; `exec_args` and `exec_param` are optional.
   - `video` / `webview`: `platform_list` is required.
   - `is_mandatory` makes devices take this version without the option to skip it. Set it only after the user confirms.
5. **Prepare, then upload immediately.** Call `prepare_content_upload` with the file name, the exact size in bytes, the local path, and `shell` — `powershell` for Windows PowerShell, `posix` for bash (Git Bash, Linux, macOS). It answers with `mode` (`single`, or `multipart` for application packages of 100MB or more) and the script for that shell (`script_windows_powershell` or `script_posix`); a big multipart script is long, so ask for one shell only.
   - Write the script to a temporary file, run it (`powershell -NoProfile -ExecutionPolicy Bypass -File <tmp>.ps1` or `bash <tmp>.sh`), then delete the file. Paths with spaces, quotes, brackets or non-ASCII characters are handled by the script — pass the real path.
   - The script checks every upload against its MD5. `single` prints `UPLOAD_OK etag=…`; `multipart` prints `PARTS_JSON=[…]` on its last line — keep that line for step 6.
   - The scripts contain upload credentials. Do not print them, show them to the user, or keep the temporary file.
   - **403 "Request has expired"**: the single URL lives 10 minutes, and part URLs can expire early. Call `prepare_content_upload` again for the same version and run the new script. For a multipart upload, first call `abort_content_upload` with the old `upload_id`.
   - **The script fails or is cancelled midway** (multipart): call `abort_content_upload`, then prepare again.
6. **Complete and compare.** Call `complete_content_upload` with `s3_key`, your local `sha256` and `size_bytes`; for multipart add `upload_id` and `parts` (the array after `PARTS_JSON=`). The launcher verifies downloads against this SHA-256.
   - `size_matches: false`: **stop and report. Do not release.** A confirmed version cannot be re-uploaded — create a new version and upload again.
7. **Release to test.** Call `release_content_test` (`application`: with the version's `platform`). Claude Code asks for approval because the tool is marked destructive — let the user approve it.
8. **Check.** Call `get_content_release_status`. Success means the test pin for that platform shows this version, its `package_hash` equals your local SHA-256, and `package_ready` is true. Read `warnings` out loud to the user. Whether devices actually received the version is not observable yet.
9. **Report.** Give the version, the SHA-256, and what is pinned where. Close with: promotion to prod is done by a person in the console.

## Rolling back

Release the previous version id to test with `release_content_test`. These tools never delete versions, so every earlier build stays available to re-pin.

## When a call fails

- **403 / "must be owner or admin"**: the account is not owner or admin of the content's organization. Say so; do not retry.
- **`DELEGATED_NOT_ALLOWED`**: the action is reserved for a person in the console. Say so; do not look for another way.
- **`ALREADY_EXISTS`**: the version string is taken for this content (and platform). Go back to step 2.
- **The MCP server asks to log in again**: the connection was revoked or expired. The user re-authenticates with `/mcp` → the MARU server → Authenticate.
- **Anything else**: report the tool's error text as-is and stop before any further release step.
