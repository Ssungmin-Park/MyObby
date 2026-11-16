# MyObby — Claude Code 전용 설정

공통 규칙(프로젝트 개요, 코드·디자인 규칙, 테스트, 보호 주의사항, 인수인계 프로토콜, Git 규칙)은 모두 `AGENTS.md`에 있다.
**이 파일에는 공통 규칙을 다시 적지 않는다.** 규칙을 바꿀 때는 `AGENTS.md`만 고친다.

@AGENTS.md

작업을 시작하면 `HANDOFF.md`도 반드시 읽는다. 다른 AI(Codex)가 마지막으로 작업했을 수 있다.

---

## Claude Code에서만 해당하는 내용

### Roblox Studio MCP (`Roblox_Studio`)
- 도구는 지연 로드된다. 처음 쓸 때 ToolSearch로 `mcp__Roblox_Studio__*` 도구를 불러온다.
- 모든 호출에 `studio_id`가 필요하다. `list_roblox_studios`로 "마이오비" 인스턴스를 찾는다.
- `execute_luau`의 `datamodel_type`
  - Edit 모드에서는 `Edit`을 쓴다.
  - Play 중에는 `Server` 또는 `Client`를 쓴다. Play 중에는 `Edit`이 거부된다.
  - Play 중에도 `Server`로는 읽기(구조·스크립트 확인)가 가능하다. 사용자의 플레이를 멈추지 않아도 된다.
- 대량 생성·수정은 한 번에 너무 크게 하지 않는다. 필요하면 나눠서 실행하고 `task.wait()`를 넣는다.
- `screen_capture`는 Edit 모드에서만 된다. 동시에 여러 개를 요청하면 시간 초과가 나니 **하나씩** 찍는다.
  - 캡처 이미지는 도구 결과 폴더에 jpg로 저장된다. 필요하면 `docs/screenshots/`로 복사한다.

### GitHub
- GitHub 플러그인 커넥터는 쓰지 않는다. 환경 변수 `GITHUB_PERSONAL_ACCESS_TOKEN`이 없어서 연결에 실패하고, 그대로 둔다.
- 업로드는 `git`과 `gh`로 한다. `gh`는 Ssungmin-Park 계정으로 로그인되어 있다.
  - 셸의 PATH에 `gh`가 없으면 `C:\Program Files\GitHub CLI\gh.exe`를 직접 실행한다.
- 커밋 메시지는 `[Claude] `로 시작하고(AGENTS.md §9), 끝에 시스템이 지정한 Co-Authored-By 줄을 붙인다.

### 사용량 소진에 대비
- 큰 단계가 끝날 때마다 `HANDOFF.md`를 갱신하고 커밋한다. 작업이 갑자기 끊겨도 Codex가 이어받을 수 있게 하기 위해서다.
