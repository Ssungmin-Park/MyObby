# MyObby — 프로젝트 안내 (Claude Code용)

## 프로젝트 개요
- 장르: 로블록스 오비(장애물 코스) 게임
- 현재 단계: **1단계 그레이박스 프로토타입** — 재미 검증이 목적. 색·재질·장식은 아직 넣지 않는다.
- 다음 단계 예정: 2단계 시스템(데이터 저장, 상점) → 3단계 비주얼(재질, 조명, 모델, 사운드)

## 소통 규칙
- 모든 답변과 코드 주석은 **한국어**로 작성한다.
- 나는 로블록스 개발 초보자다. 용어가 나오면 짧게 풀어서 설명한다.
- 큰 변경(새 시스템 추가, 구조 변경, 객체 삭제) 전에는 계획을 먼저 보여주고 확인을 받는다.
- 작업이 끝나면 무엇을 바꿨는지, 내가 Studio에서 무엇을 확인하면 되는지 요약한다.

## 도구
- Roblox Studio는 MCP 서버 `Roblox_Studio`로 연결되어 있다.
- 수정 전에는 항상 현재 구조(Workspace, ServerScriptService 등)를 먼저 확인한다.
- 수정 후에는 플레이테스트를 실행하고 출력 로그의 에러·경고를 확인한 뒤 보고한다.
- Studio가 연결되지 않으면 추측해서 진행하지 말고 나에게 Studio와 MCP 스위치를 확인하라고 알린다.

## 폴더 구조 규칙 (Studio 안)
- `Workspace/Stages/Stage01 ~ StageNN` : 스테이지별 장애물 파트를 Model로 묶는다
- `Workspace/Checkpoints/` : 체크포인트 파트 (이름 = 스테이지 번호, 예: `1`, `2` …)
- `ServerScriptService/` : 서버 로직 (체크포인트, 리스폰, 리더보드)
- `ReplicatedStorage/Remotes/` : RemoteEvent / RemoteFunction
- `ReplicatedStorage/Modules/` : 공용 ModuleScript
- `StarterPlayer/StarterPlayerScripts/` : 클라이언트 전용 스크립트(UI, 입력)

## 코드 규칙 (Luau)
- 가능하면 스크립트 맨 위에 `--!strict`를 쓴다.
- `wait()` 대신 `task.wait()`, `spawn()` 대신 `task.spawn()`을 쓴다.
- 게임 판정(스테이지 진행, 보상)은 **서버에서만** 처리한다. 클라이언트에서 온 RemoteEvent 값은 반드시 검증한다.
- DataStore 호출은 `pcall`로 감싸고 실패 시 재시도/로그를 남긴다.
- Toolbox의 무료 모델 중 스크립트가 들어 있는 것은 사용하지 않는다.
- 하나의 스크립트에 모든 걸 넣지 말고 역할별로 나눈다.

## 게임 디자인 규칙
- 점프 구간은 PC와 **모바일 모두**에서 깰 수 있는 거리로 만든다 (기본 캐릭터 점프 기준).
- 난이도는 스테이지가 올라갈수록 조금씩 높인다. 갑자기 어려워지는 구간을 만들지 않는다.
- 떨어지면 마지막으로 밟은 체크포인트에서 리스폰된다.
- 리더보드(leaderstats)에 현재 스테이지를 표시한다.

## 작업 기록
- 큰 작업이 끝날 때마다 이 폴더의 `NOTES.md`에 날짜와 변경 내용을 한두 줄로 추가한다.

## GitHub 연동 (포트폴리오)
- 이 폴더는 공개 GitHub 저장소와 연결되어 있다. 업로드는 `git` + GitHub CLI(`gh`)로 한다. (GitHub 커넥터는 쓰지 않음)
- Studio 스크립트는 `src/` 아래에 Studio 경로 그대로 내보낸다.
  - Script → `.server.luau`, LocalScript → `.client.luau`, ModuleScript → `.luau`
  - 예: `ServerScriptService/Hazards` → `src/ServerScriptService/Hazards.server.luau`
- 큰 작업이 끝나면 다음 순서로 진행한다: 스크립트 내보내기 → 크기 비교로 Studio와 같은지 확인 → `NOTES.md` 기록 → 필요하면 `README.md` 갱신 → 커밋 → 푸시.
- 커밋 메시지는 한국어로, 무엇을 왜 바꿨는지 한 줄 요약 + 필요하면 본문.
- 공개 저장소이므로 토큰·비밀번호·개인 정보는 절대 커밋하지 않는다.
