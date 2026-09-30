# MARU Platform — Claude Code 플러그인

MARU 플랫폼의 MCP 도구를 Claude Code 에 붙이는 플러그인 마켓플레이스다. MARU 계정으로 로그인하면 런처·업데이터 빌드와 내 조직 콘텐츠 빌드를 올리고 **test 트랙에만** 릴리스할 수 있다.

## 설치

Claude Code v2.1.231 이상.

```
/plugin marketplace add code-reach/platform.claude-plugin
/plugin install maru@maru
```

설치하면 MCP 서버 `maru` 가 자동으로 뜬다. 처음 한 번 로그인한다.

```
/mcp  →  maru  →  Authenticate
```

브라우저에서 MARU 계정으로 로그인하고 동의하면 끝이다. 로그인은 한 번 하면 오래 유지된다(쓰는 동안 계속 연장, 최대 1년). 비대화형(`claude -p`)은 로그인 흐름을 돌릴 수 없으니 대화형 세션에서 먼저 로그인한다.

## 들어 있는 것

| 구성 | 내용 |
|---|---|
| `.mcp.json` | MCP 서버 `maru` → `https://mcp.maru-platform.com/mcp` |
| `skills/release-program` | 런처·업데이터: 빌드 → 해시 → 업로드 → 등록 → test 릴리스 → 확인 절차 |
| `skills/release-content` | 콘텐츠: 버전 생성 → 해시 → 업로드 스크립트 → 확정 → test 릴리스 → 상태 확인 절차 |

도구는 계정 권한에 따라 보이는 것이 다르다. 쓸 수 있는 권한이 없는 계정은 로그인 뒤 도구가 보이지 않는다.

| 대상 | 도구 | 보이는 계정 |
|---|---|---|
| 런처·업데이터 | `list_programs` · `list_program_versions` · `prepare_program_upload` · `register_program_version` · `release_program_test` · `verify_program_test_release` · `list_updater_versions` · `prepare_updater_upload` · `register_updater_version` | 플랫폼 관리자 |
| 콘텐츠 | `list_my_contents` · `list_content_versions` · `get_content_release_status` · `create_content_version` · `prepare_content_upload` · `complete_content_upload` · `abort_content_upload` · `release_content_test` | 벤더 조직 owner·admin, 플랫폼 관리자 |

**test 트랙이라도 실제 기기에 닿는다.** 릴리스 트랙이 `test` 인 기기는 이 서버의 test 릴리스를 받는다.

prod 승격과 업데이터 배포 버전 지정은 도구가 없다 — 런처·업데이터는 어드민, 콘텐츠는 콘솔에서 사람이 한다. 콘텐츠 노출 전환·아카이브·삭제도 같다.

## 이 저장소를 고칠 때

- 스킬은 사본이다. 원본은 테스트 환경 저장소에서 고치고 써 본 뒤 `skills/` 를 통째로 옮겨 온다. 여기서 손으로 고치지 않는다.
- 공개 저장소다. **비밀값·서버 IP·내부 호스트명·서버 경로를 넣지 않는다.** 인증 설정(`oauth`·`headers.Authorization`)도 두지 않는다 — 로그인은 서버의 OAuth 흐름이 맡는다.
- 고친 뒤 `claude plugin validate --strict .` 로 확인한다.
