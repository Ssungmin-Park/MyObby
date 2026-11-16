# HANDOFF.md — 인수인계 문서

> 이 문서는 **현재 상태 스냅샷**이다. 작업을 마치거나 AI를 전환할 때 **최신 상태로 덮어 갱신**한다.
> 지난 이력은 `NOTES.md`와 `git log`에 있다. 규칙은 `AGENTS.md`를 따른다.
> 모든 항목은 실제 파일, Git, Studio를 확인한 결과로 적는다. 확인하지 못한 것은 "미확인"이라고 표시한다.
> 이 문서만 읽고도 이전 대화 없이 개발을 이어갈 수 있게 쓰는 것이 목표다.

---

## H. 인수인계 시점 (먼저 읽기)

| 항목 | 내용 |
|---|---|
| 마지막 작업 AI | **OpenAI Codex** (Studio·저장소 접근 재확인, 비점프형 콘셉트 조사). 마지막 게임 코드는 Claude Code가 수정했다 |
| 작업 시점 | 2026-11-16 |
| 다음 작업 AI | Codex 또는 Claude Code. 저장은 Studio API 접근 설정 확인 후 G 1순위 검증을 재개한다. 비점프형 콘셉트는 G의 시안과 첫 구현 범위를 사용자와 확정한다 |
| 게임 이름 | 마이오비 (Studio place 이름) / 콘셉트명 "실험실 탈출" |
| Place ID | `77293997616106` |
| Universe ID (GameId) | `10777081510` |
| 소유 | 개인 계정 (CreatorType = User) |
| Studio 인스턴스 ID | 2026-11-16 기준 `c45b95a2-fc62-4fb8-907e-0df1421a14db`. **실행할 때마다 바뀐다.** 새 세션에서 `list_roblox_studios`로 다시 조회하고, placeId가 위 값인 인스턴스만 사용한다 |
| Studio 모드 | 마지막 확인 시 **Play 모드** — 사용자가 직접 플레이 중(Stage 6). AI는 멈추지 않고 Server로 읽기만 했다. 다음 AI는 편집 전에 모드를 확인하고, Play를 멈춰야 하면 사용자에게 알린다 |
| 로컬 폴더 | `C:\RobloxProjects\MyObby` |
| Git | `main` 브랜치, `origin/main`(https://github.com/Ssungmin-Park/MyObby, 공개)과 동기화. 시작할 때 `git status`, `git log --oneline -5`로 다시 확인 |
| 마지막 수정 | **진행 저장 구현 (사용자 승인 후).** Studio에 `ServerScriptService/ProgressSave`(ModuleScript) 추가, `Leaderstats` 수정(불러오기 연결), `Respawn`·`Finish`의 leaderstats 대기 시간 5초/10초 → 30초. ChangeHistoryService로 기록(Ctrl+Z 가능) |
| Studio 저장 상태 | place는 클라우드 저장 place(`persistedToCloud = true`)다. 사용자가 Studio를 다시 시작한 뒤에도 `ProgressSave`와 수정한 스크립트 3개가 그대로 있었다 → **진행 저장 코드는 클라우드에 저장된 것으로 보인다**(간접 확인). AI는 저장·Publish를 하지 않았다 |
| Studio API 접근 | **여전히 거부됨.** 기존 Play 세션에서 Codex가 `Progress_v1`의 `Player_0` 읽기를 확인했으며 Error code 7 (`Studio access to APIs is not allowed`)이 반환됐다. 쓰기는 시도하지 않았다. Security 탭에서 설정과 저장 여부를 확인해야 한다 |
| 백업 상태 | 스크립트: `src/`(Git, GitHub)에 7개 모두 있고 Studio와 내용이 같다(체크섬 일치). 맵(파트·모델): **Git에 백업 없음**, Studio 클라우드에만 있다. 옛 버전은 `ServerStorage`에 백업 |
| 게임 공개 상태 | 확인하지 않았고 바꾸지 않았다. AI는 Publish하지 않는다 (AGENTS.md §8 규칙 9) |

---

## A. 프로젝트 개요

- **콘셉트:** "실험실 탈출" 오비(장애물 코스). 실험실에 갇힌 플레이어가 레이저 복도, 회전 레이저, 움직이는 화물 발판, 보안문을 지나 EXIT까지 탈출한다.
- **핵심 플레이 구조:** 시작 발판(Stage 0) → 체크포인트 1~10을 순서대로 밟음 → 체크포인트 11(EXIT) = 탈출. 죽으면 마지막 체크포인트에서 1초 뒤 부활. 오른쪽 위 리더보드에 현재 Stage 표시.
- **개발 목표:** 출시 가능한 게임 + 공개 GitHub 저장소를 포트폴리오로 활용.
- **단계:** 1단계 그레이박스(재미 검증) → 2단계 시스템(저장, 수익화) → 3단계 비주얼.
- **현재 완성도:** **1단계 그레이박스 완료, 2단계 시작.** 코스 전체를 처음부터 끝까지 깰 수 있다. 사용자가 직접 플레이해 "난이도 적당"을 확인했다(기기 미기록). 진행 저장은 구현했지만 실제 DataStore 재접속 테스트가 남았다. 색·재질·사운드·상점은 없다.

### 코스 배치 (Studio 실측)
| 체크포인트 | 위치 (X, Y, Z) | 구간 |
|---|---|---|
| 시작 SpawnLocation | 0, 40, 0 | |
| 1 | 0, 40, 41 | 감방: 기본 점프 (1–3) |
| 2 | 0, 40, 80.8 | |
| 3 | 0, 40, 122 | |
| 4 | 0, 42.5, 172 | 레이저 복도: 낮은 레이저 바 (4–5) |
| 5 | 0, 45, 221.7 | |
| 6 | 0, 47.5, 273 | 실험실: 회전 레이저 (6) |
| 7 | 0, 53.5, 333 | 화물 창고: 움직이는 발판 (7–8) |
| 8 | 0, 59.5, 392.5 | |
| 9 | 0, 65.5, 454 | 보안문 2개 + 레이저 (9) |
| 10 | 0, 76, 530 | 종합 (10) |
| 11 (EXIT, `IsFinish = true`) | 0, 76, 545 | 골인 |

- `KillZone`: Y=20, 크기 2048×1×2048. 코스 아래 전체를 덮는 낙사 판정 바닥.
- 캐릭터 기본값: JumpHeight 7.2, WalkSpeed 16 (UseJumpPower = false). 평지 최대 점프 약 8.7스터드. 발판 간격 3 → 6스터드, 높이차 0 → 1.75스터드.

---

## B. 현재 구현된 기능

활성 스크립트 7개(Script 5, ModuleScript 1, LocalScript 1)는 `--!strict`이며, 로컬 `src/`와 바이트 크기 및 체크섬이 일치한다 (2026-11-16).

### B-1. 리더보드 — `ServerScriptService/Leaderstats` (Script, 1691 B)
- 플레이어가 들어오면 `leaderstats`(Folder)와 `Stage`(IntValue, 0)를 만든다.
- `ProgressSave.loadAsync`로 저장된 Stage를 불러와 **`leaderstats`를 플레이어에 붙이기 전에** 값을 넣는다. 그래야 Finish가 복원된 11을 "방금 탈출"로 착각하지 않는다.
- 불러오기에 성공하면 `ProgressSave.track`으로 저장 대상에 등록한다. 실패하면 Stage 0으로 플레이는 가능하지만 이번 접속은 저장하지 않는다(경고 로그).
- 불러오는 동안 `leaderstats`가 없으므로 Checkpoints는 진행을 판정하지 않는다. 불러오는 중 나간 플레이어는 무시한다.
- 의존: `ProgressSave`. **`Checkpoints`, `Respawn`, `Finish`가 이 `leaderstats.Stage`를 읽고 쓴다** → 이름 변경 금지.

### B-1b. 진행 저장 — `ServerScriptService/ProgressSave` (ModuleScript, 6230 B)
- **저장 형식 (바꾸지 말 것):** DataStore `Progress_v1`, 키 `Player_<UserId>`, 값 `{ Stage = 정수 }`. 허용 범위는 0 ~ Checkpoints의 최대 번호(현재 11).
- `loadAsync(userId)`: `GetAsync` + `pcall`, 최대 3회(1초, 2초 대기). 값 없음 → 0. 실패나 이상한 형식 → nil.
- `saveAsync(userId, stage)`: `UpdateAsync`로 **기존 값보다 높을 때만** 쓴다. 기존 값의 형식이 이상하면 덮어쓰지 않는다. 최대 3회 시도.
- `start()`: Leaderstats가 한 번 호출. 60초 자동 저장, `PlayerRemoving` 저장, `game:BindToClose` 저장(최대 25초 대기)을 켠다. 같은 플레이어의 저장이 겹치지 않게 `saving` 표시를 쓴다.
- `setStoreForTest(fake)`: 테스트용 가짜 저장소 주입. 게임 코드에서는 쓰지 않는다.
- 진행은 늘어나기만 하므로(Checkpoints 규칙) "저장된 값보다 클 때만 저장"으로 충분하다. 나중에 **진행을 낮추는 기능**(예: 처음부터 다시 하기)을 넣으면 이 규칙을 같이 바꿔야 한다.

### B-2. 체크포인트 진행 — `ServerScriptService/Checkpoints` (Script, 1756 B)
- `Workspace/Checkpoints`의 각 파트에 `Touched`를 연결한다. **파트 이름(숫자)이 곧 스테이지 번호**다.
- 살아 있는 플레이어 캐릭터가 밟고, `번호 == 현재 Stage + 1`일 때만 Stage를 올린다 → 건너뛰기(순간이동 핵)와 뒤로 가기를 막는다.
- 새로 추가되는 체크포인트도 `ChildAdded`로 자동 연결된다.
- 의존: `Workspace/Checkpoints`, `leaderstats.Stage`.

### B-3. 리스폰 — `ServerScriptService/Respawn` (Script, 2130 B)
- `Players.RespawnTime = 1`로 설정한다. Studio 편집 화면에서는 기본값 3으로 보이지만 실행하면 이 스크립트가 1로 바꾼다(Play 중 1 확인).
- `Workspace/KillZone`에 닿으면 사망 처리한다.
- 캐릭터가 생길 때 `leaderstats`를 최대 30초 기다린 뒤(진행 불러오기 시간 포함) Stage 번호의 체크포인트 위(+3스터드)로 `PivotTo`한다. Stage 0이거나 체크포인트를 못 찾으면 `SpawnLocation`으로 보낸다.
- 의존: `Workspace/Checkpoints`, `KillZone`, `SpawnLocation`, `leaderstats.Stage`.

### B-4. 장애물 — `ServerScriptService/Hazards` (Script, 4036 B)
CollectionService 태그와 Attribute로 동작한다. Studio 실측 태그 개수는 KillPart 8, Spinner 2, Mover 4, TimedDoor 2이다.

| 태그 | 붙는 대상 | 동작 | 속성 (기본값) |
|---|---|---|---|
| `KillPart` | BasePart (레이저, 회전 막대) | 닿으면 Health = 0 | 없음 |
| `Spinner` | Model (Stage 6: 40°/s, Stage 10: 55°/s) | 안의 `HingeConstraint`를 Motor로 돌려 `Bar` 회전 | `SpeedDeg` (40) |
| `Mover` | Model (Stage 7, 8×2, 10) | 안의 `PrismaticConstraint`를 Servo로 `Platform` 왕복 | `Range` (6), `Speed` (4), `StartSign` (1), `Pause` (1) |
| `TimedDoor` | BasePart (Stage 9, 2개) | 서버 시간 기준으로 열림/닫힘 반복. 열리면 CanCollide false, Transparency 0.85 | `Period` (3), `Offset` (0) |

- 움직이는 파트는 `SetNetworkOwner(nil)`로 서버가 물리를 계산한다.
- 새 장애물 종류는 `bindTag(태그, setup함수)` 한 줄로 추가한다.

### B-5. 골인 — `ServerScriptService/Finish` (Script, 1515 B)
- 플레이어의 `Stage.Changed`를 감시하다가 값이 `IsFinish = true`인 체크포인트 번호(현재 11)가 되면 서버 로그 `[Finish] 이름 탈출 성공`을 남기고 `Remotes.Escaped:FireClient(player)`를 보낸다.
- `leaderstats`를 최대 30초 기다린다(진행 불러오기 시간 포함).
- 의존: `ReplicatedStorage/Remotes/Escaped`, `Workspace/Checkpoints`의 `IsFinish` 속성, `leaderstats.Stage`.

### B-6. 탈출 메시지 — `StarterPlayer/StarterPlayerScripts/EscapeMessage` (LocalScript, 908 B)
- `Escaped` 이벤트를 받으면 `PlayerGui`에 `EscapeMessage` ScreenGui를 만들어 "탈출 성공!"을 4초 동안 보여 준다. 표시만 담당.

### B-7. Remote
- `ReplicatedStorage/Remotes/Escaped` (RemoteEvent): **서버 → 클라이언트 전용.** 클라이언트에서 서버로 보내는 Remote는 하나도 없다.

### 시스템 연결 흐름
```
입장 → Leaderstats → ProgressSave.loadAsync(저장된 Stage) → leaderstats 붙임 → Respawn(그 Stage 위치로 이동)
퇴장 / 60초마다 / 서버 종료 → ProgressSave가 더 높아진 Stage만 저장
체크포인트 밟음 → Checkpoints(Stage+1)
     └ Stage가 11이 되면 → Finish → Remotes.Escaped → EscapeMessage("탈출 성공!")
레이저(KillPart) 또는 KillZone 닿음 → 사망 → 1초 뒤 Respawn(마지막 체크포인트)
Hazards → Spinner·Mover·TimedDoor 계속 구동
```

### B-8. 데이터 저장 및 플레이어 진행
- **DataStore `Progress_v1`을 쓴다** (B-1b). `DataStoreService`를 쓰는 곳은 `ProgressSave` 하나뿐이다.
- 2026-11-16 현재 실제 저장소에 쓰인 데이터: **없는 것으로 본다.** Studio API 접근이 꺼져 있어 Studio 테스트는 모두 실패 경로(저장 안 함)로 끝났고, 게임은 아직 공개 서버에서 돌린 적이 없다(미확인).
- 키 이름·데이터 형식은 이제부터 바꾸지 않는다. 바꿔야 하면 마이그레이션 계획을 먼저 승인받는다 (AGENTS.md §7).

### B-9. 그 밖의 Studio 객체
| 위치 | 내용 |
|---|---|
| `Workspace/Stages/Stage01~10` | 스테이지별 Model (발판, 레이저, Spinner/Mover 모델, 문) |
| `Workspace/Baseplate` | 템플릿 기본 바닥 (Y=-8) |
| `Lighting` | 템플릿 기본 효과 Sky, Atmosphere, Bloom, SunRays, DepthOfField |
| `StarterGui`, `StarterPack`, `ReplicatedFirst`, `SoundService`, `Teams` | 비어 있음 |
| `ServerStorage/ObbyServer_backup` | 옛 단일 스크립트 (Disabled, 2622 B, `--!strict` 없음). **백업. 승인 없이 삭제 금지** |
| `ServerStorage/StagesBackup/Stage04~10` | 장애물을 넣기 전 스테이지. **백업. 승인 없이 삭제 금지** |

---

## C. 진행 중인 개발

- **진행 중인 작업:** 진행 저장 — **구현 완료, 실제 DataStore 재접속 테스트 대기.**
  - 중단 위치: Studio API 접근이 계속 거부되어 G 1순위 테스트를 시작하지 못했다. 사용자에게 Game Settings → Security 탭 스크린샷을 요청한 상태. 코드는 더 고칠 계획이 없다.
- **신규 개발 후보:** 사용자가 점프 없이 오래 플레이할 수 있는 ‘키우기’·‘찾기’ 주제를 요청했다. G에 조사 결과와 시안을 기록했다. 맵·스크립트 변경은 승인 대기 중이다.
- **마지막 구현 작업 (Claude Code):**
  1. 사용자가 Codex 설계안을 승인 → `ProgressSave` 구현, Studio 반영, 가짜 저장소 테스트 13개 통과, 기존 회귀 테스트 통과 (커밋 `0eceb0d`).
  2. 실제 저장 테스트를 3번 시도 → 모두 API 접근 거부로 중단. 저장소에는 아무것도 쓰지 않았다.
  3. Studio 실제 상태를 다시 확인하고 이 문서를 갱신했다.
- **미완성 부분:** 진행 저장 실제 검증, 스테이지 스킵 상품, 보상형 광고, 3단계 비주얼.

---

## D. 주요 설계 결정

| 결정 | 이유 | 지켜야 할 원칙 |
|---|---|---|
| 테마 "실험실 탈출" | 일반 오비는 포화 상태여서 테마·이야기형으로 차별화. 레이저/화물/보안문 장애물이 테마와 맞음 | 오리지널 설정만 사용 |
| 체크포인트는 "바로 다음 번호만" 인정 | 순간이동 핵으로 건너뛰기를 서버에서 차단. 코스가 일직선이라 정상 플레이에 영향 없음 | 진행 판정은 서버에서만 |
| 골인 = `Checkpoints/11` + `IsFinish` | 기존 체크포인트·리스폰 로직 재사용. 리더보드 11 = 탈출 | 체크포인트 이름과 `IsFinish` 변경 금지 |
| 장애물은 태그 + Attribute | 스크립트 수정 없이 레벨 디자인 반복. 초보 사용자도 태그만 붙여 추가 가능 | 새 장애물도 이 방식 우선 |
| 움직이는 물체는 Constraint + 서버 소유 | CFrame 트윈은 캐릭터를 태우지 못함. 서버 소유로 모두에게 같은 위치 | 트윈으로 바꾸지 않기 |
| 보안문은 `GetServerTimeNow` 하나의 시계 | 문끼리 박자가 맞고 클라이언트 간 차이 없음 | |
| 레이저는 색 없이 `Transparency 0.4` | 1단계 규칙(색·재질 금지)을 지키면서 위험 구분 | 3단계에서 비주얼 적용 |
| 역할별 스크립트 분리 | 한 스크립트가 커지면 수정 위험이 큼 | 새 기능은 새 스크립트 또는 기존 역할 확장 |
| 원본은 Studio, `src/`는 거울 (Rojo 미사용) | 초보 사용자 환경 단순화 | Studio 수정 후 같은 작업 안에서 `src/` 갱신 |
| GitHub는 git + gh (플러그인 커넥터 미사용) | 커넥터는 토큰 환경 변수가 필요. gh는 브라우저 로그인으로 동작 | |
| 공개 저장소 | 포트폴리오 목적 | 비밀 정보 커밋 금지 |
| 수익화 방향 (미구현) | 스테이지 스킵 Developer Product(뒤로 갈수록 비싸게) + 꾸미기 게임패스 + 보상형 광고 | pay-to-win 금지 |

---

## E. 발견된 오류와 문제

**현재 알려진 게임 버그: 없음.** 아래는 미확인 항목과 알려진 한계다.

| # | 내용 | 재현 / 원인 | 시도한 것 | 상태 |
|---|---|---|---|---|
| 1 | Studio 저장 여부 미확인 | AI는 저장 여부를 알 수 없음 | 사용자에게 Ctrl+S 안내 | **사용자 확인 필요** |
| 2 | 실제 모바일 기기·터치 조작 미검증 | 자동 테스트는 순간이동 방식 | — | 미검증 |
| 3 | 진행 저장의 실제 DataStore 동작 미검증 | Studio API 접근이 꺼져 있어 실제 저장소 호출이 거부됨 (`StudioAccessToApisNotAllowed`) | 가짜 저장소로 로직 테스트, 실패 경로 확인. 사용자가 설정을 켰다고 한 뒤 3번 재시도(Studio 재시작 포함) → 모두 거부 | **설정 확인 필요** (스크린샷 요청 중) |
| 3b | Studio API 접근이 꺼져 있으면 Play 시작 때 불러오기를 3번 시도하느라 약 3초 동안 경고 로그가 나오고 시작 발판에 머문다 | 의도된 재시도 | — | 정상 동작. 실제 서버에서는 해당 없음 |
| 4 | 맵(파트·모델)은 Git에 백업이 없음 | Rojo 미사용, 스크립트만 `src/`로 내보냄 | — | 알려진 한계. Studio의 버전 기록(File → Version History)에 의존 |
| 5 | 체크포인트 1~10에 옛 속성 `Stage`(숫자)가 남아 있음 | 이전 단일 스크립트의 흔적. 현재 스크립트는 이름으로 판정하므로 무해 | — | 정리 선택 사항 (삭제 전 승인) |
| 6 | `ServerStorage` 백업 2개 남아 있음 | 의도된 백업 | — | 삭제 여부는 사용자 결정 |
| 7 | Claude Code GitHub 플러그인 커넥터 연결 실패 | 토큰 환경 변수 없음 | gh CLI로 대체 | 의도적 미사용 |
| 8 | Codex의 Roblox Studio MCP 연결 | 현재 인스턴스의 Place ID와 Universe ID를 대조했다 | 구조 확인과 Play 테스트 | 확인 완료. 새 세션마다 인스턴스 다시 조회 |
| 9 | Lighting에 템플릿 기본 효과(Bloom, DepthOfField 등)가 켜져 있음 | 템플릿 기본값 | — | 3단계 비주얼 때 결정 |

해결됨: 이전 문서의 "최신 테스트에서 탈출 메시지 미확인" → 2026-11-16 재테스트에서 **클라이언트 표시 확인**(F 참고). 이전 테스트에서는 확인 시점이 4초 표시 시간을 넘겼던 것으로 본다.

---

## F. 테스트 상태

### 실제로 실행한 테스트

**① 2026-11-16 회귀 테스트 (Claude Code, Play 모드에서 서버 자동 테스트)**

| # | 항목 | 결과 |
|---|---|---|
| 1 | 입장 시 Stage 0 | PASS |
| 2 | 체크포인트 1 → 2 진행 | PASS |
| 3 | 건너뛰기 방지 (2에서 5 → 2 유지) | PASS |
| 4 | 뒤로 가기 방지 | PASS |
| 5 | 레이저(KillPart) 닿으면 사망 | PASS |
| 6 | 마지막 체크포인트에서 리스폰 (거리 0.0) | PASS |
| 7 | KillZone 낙사 | PASS |
| 8 | Mover 이동 (X 0.8 → 6.0) | PASS |
| 9 | Spinner 회전 (−19° → 37°) | PASS |
| 10 | TimedDoor 두 문 엇갈림 | PASS |
| 11 | EXIT 도달 시 Stage 11 + 서버 로그 | PASS |

**② 2026-11-16 인수인계 검증 (Claude Code)**

| 항목 | 결과 |
|---|---|
| Play 중 `Players.RespawnTime` = 1 | PASS |
| 체크포인트 1~11 순서대로 → Stage 0 → 11 | PASS |
| 클라이언트 `PlayerGui.EscapeMessage` 생성, 문구 "탈출 성공!" | **PASS** (이번에 확인) |
| 출력 로그 | `[Finish] … 탈출 성공`만 있고 에러·경고 없음 |
| Studio 스크립트 ↔ `src/` 내용 비교 (6개, 크기 + 체크섬) | 모두 일치 |

**③ 사용자 직접 플레이:** 처음부터 끝까지 플레이, 난이도 적당 (2026-11-16, 기기 미기록).

**④ 2026-11-16 Codex 회귀 테스트:** 초기 Stage 0, 체크포인트 순서·건너뛰기·역행 판정, 레이저 사망, Stage 2 리스폰(수평 오차 1스터드 미만), KillZone 사망, Mover 이동, Spinner 회전, 보안문 교대, Stage 11과 클라이언트 탈출 메시지를 확인했다. `RespawnTime`은 1초였고, 출력에는 골인 로그만 있었다. 메시지는 첫 조회에서 검출되지 않아 클라이언트 감시를 먼저 시작한 뒤 EXIT를 다시 밟아 확인했다. 테스트를 종료하고 Edit 모드로 돌아왔다.

**⑤ 2026-11-16 진행 저장 테스트 (Claude Code, Play 모드)**

가짜 저장소(`setStoreForTest`)를 넣은 `ProgressSave` 복제본으로 실행. 실제 DataStore는 건드리지 않았다.

| 항목 | 결과 |
|---|---|
| 새 플레이어 불러오기 = 0 | PASS |
| 3 저장 후 다시 불러오기 = 3 | PASS |
| 낮은 값(2) 저장 시 3 유지, 쓰기 없음 | PASS |
| 높은 값(11) 저장 | PASS |
| 이상한 형식(`Stage = "x"`) → 불러오기 nil, 덮어쓰지 않음 | PASS |
| 범위 밖(99) → nil | PASS |
| 읽기 2번 실패 후 3번째 성공 (재시도 대기 3.0초) | PASS |
| 읽기 3번 모두 실패 → nil | PASS |
| 저장 3번 모두 실패 → false, 기존 값 유지 | PASS |
| 저장 1번 실패 후 성공 | PASS |
| 실제 실패 경로: Studio API 접근 꺼짐 → 3회 시도 후 Stage 0, 저장 안 함, 게임 정상 진행 | PASS |
| 기존 회귀 테스트 1~11 (Stage 0 시작, 진행, 건너뛰기·역행 방지, 레이저·KillZone 사망, 리스폰 거리 0.00, Mover, Spinner, TimedDoor, Stage 11) | PASS |
| 클라이언트 "탈출 성공!" | PASS (클라이언트 감시를 먼저 켠 뒤 EXIT를 다시 밟아 확인. 처음 조회는 4초가 지나 놓침) |
| 출력 로그 | 예상한 경고(API 접근 거부, 가짜 오류)와 골인 로그만. 다른 에러 없음 |

**⑥ 2026-11-16 실제 DataStore 테스트 시도 (Claude Code)** — 사용자가 설정을 켰다고 한 뒤 Play 3회(마지막은 Studio 재시작 후). 3회 모두 `GetAsync`가 `Studio access to APIs is not allowed`로 거부되어 **테스트하지 못함**. 게임은 Stage 0으로 정상 진행(실패 경로 재확인). 쓰기 없음.

**⑦ 2026-11-16 상태 재확인 (Claude Code, 사용자 Play 중 Server 읽기)** — 스크립트 7개 크기·체크섬이 `src/`와 일치, 태그 수(KillPart 8, Spinner 2, Mover 4, TimedDoor 2), 체크포인트 11, 스테이지 10, ServerStorage 백업 2개 그대로. DataStore 접근은 여전히 거부.

**⑧ 2026-11-16 Codex 확인 (기존 Play 세션 유지)** — Place ID·Universe ID 일치. 스크립트 7개 바이트 크기·체크섬 일치, 체크포인트 10 라벨과 11의 `IsFinish`, 스테이지 10개, 장애물 4종, 백업 2개 확인. 저장소 읽기 요청은 Error code 7로 거부됐다. 새 플레이테스트와 쓰기는 없었다.

**아직 안 한 것:** 실제 DataStore에 저장 → 다시 Play → 같은 체크포인트에서 시작. Stage 11 복원 시 탈출 메시지가 다시 뜨지 않는지. 60초 자동 저장.

### 실패한 테스트
- 없음.

### 아직 테스트하지 않은 항목
- 실제 모바일 기기 터치 조작, 저사양 기기 성능
- 여러 플레이어가 동시에 접속했을 때 (Mover 발판 동시 탑승, 리더보드)
- 실제 서버(공개 게임)에서의 네트워크 지연 상황

---

## G. 다음 개발 계획 (우선순위 순)

### 새 콘셉트 시안 — 꼬마 로봇 연구소 (승인 대기)

- **핵심 플레이:** 걸어서 고장 난 로봇을 찾고 부품을 모아 연구실에서 수리한다. 도감에 등록한 로봇이 새 탐색 기능을 열어 같은 구역에서 숨은 단서를 발견할 수 있게 한다.
- **첫 버전:** 연구실 1곳, 평지 탐색 구역 2곳, 로봇 3종, 수리대 1개, 도감. 첫 로봇은 시작 방에서 발견하고, 수리한 탐지 로봇의 신호로 다음 로봇을 찾는다. PC·모바일 모두 걸어서 목표에 도달하도록 설계한다.
- **검증:** 처음 보는 사람이 설명 없이 첫 로봇을 찾고 수리하는지, 첫 수리 후 스스로 두 번째 로봇을 찾으러 가는지 확인한다.
- **참고 사례:** 성장으로 탐색 범위를 넓히는 [Bee Swarm Simulator](https://www.roblox.com/games/1537690962/Bee-Swarm-Simulator), 구역 탐색과 수집을 결합한 [Find the Chomiks](https://www.roblox.com/games/7031179594/Find-the-Chomiks), 성장·수확으로 재접속 목표를 주는 [Grow a Garden](https://www.roblox.com/games/126884695634066/Grow-a-Garden).
- **다음 AI:** 콘셉트와 프로토타입 범위를 사용자와 확정한다. 기존 오비 맵과 `Progress_v1` 저장 형식을 보존한다. 새 모드가 승인되면 로봇 도감·수리에 맞는 저장 설계를 정한다. 장르가 확정될 때까지 아래 2순위 스테이지 스킵은 보류한다.

### 0순위 — 작업 환경 확인 (매 세션)
- **목표:** 올바른 게임과 최신 상태에서 시작.
- **방법:**
  1. `AGENTS.md`와 이 문서를 읽는다.
  2. `git status`, `git log --oneline -5`를 확인한다.
  3. **Codex라면 Roblox Studio MCP 연결부터 확인한다** (E-8). 없으면 사용자에게 알리고 Studio 작업은 하지 않는다 (AGENTS.md §6 "Studio MCP를 쓸 수 없을 때").
  4. `list_roblox_studios`로 인스턴스 ID를 새로 받고 placeId `77293997616106`을 확인한다.
  5. Studio에는 체크포인트 10 라벨이 올바르게 표시된다. 마지막 클라우드 저장 여부는 사용자에게 확인한다 (E-1).
  6. 스크립트 7개 크기(또는 체크섬)가 `src/`와 같은지 확인한다.
- **완료 조건:** 위 항목에서 이상이 없거나, 이상한 점을 사용자에게 보고함.

### 1순위 — 진행 저장 실제 검증 (구현은 완료, B-1b)
- **목표:** 실제 DataStore로 "저장 → 재접속 → 이어하기"를 확인하고 진행 저장을 완료로 기록.
- **먼저 할 일:** 사용자와 함께 API 접근 설정을 확인한다. 확인 방법: Play 중 Server에서 `DataStoreService:GetDataStore("Progress_v1"):GetAsync("Player_0")`을 `pcall`로 호출해 Error code 7이 사라졌는지 본다 (읽기만, 쓰기 없음). 계속 막히면 스크린샷으로 "Enable Studio Access to API Services" 스위치와 Save 여부를 확인한다.
- **전제:** 사용자가 Studio Game Settings → Security → "Enable Studio Access to API Services"를 켠다 (AI가 바꾸지 않는다). Studio는 실제 게임과 **같은 저장소**를 쓴다. 게임은 아직 공개 전이라 기존 플레이어 데이터는 없다고 본다. 테스트는 사용자 본인 키(`Player_<사용자 UserId>`)에만 쓴다.
- **테스트 순서:**
  1. Play → 로그에 불러오기 경고 없음, Stage 0(또는 이전 저장값) 확인.
  2. 체크포인트 1 → 2 → 3 진행 → Play 종료 (퇴장/BindToClose 저장).
  3. 다시 Play → Stage 3, 체크포인트 3 위에서 시작하는지 확인.
  4. 11까지 진행 → 종료 → 다시 Play → Stage 11, EXIT 위, "탈출 성공!"이 **다시 뜨지 않는지** 확인.
  5. 출력 로그에 예상 밖의 에러가 없는지 확인.
- **테스트 후 남는 값:** 사용자 키에 Stage 11(또는 마지막 값)이 남는다. 지우려면(`RemoveAsync`) 사용자 승인을 받는다.
- **완료 조건:** 위 1~5 통과 → AGENTS.md §4에 진행 저장을 안정 기능으로 옮기고 README 로드맵을 갱신.
- 참고: [Roblox DataStore 문서 — Studio 접근](https://create.roblox.com/docs/cloud-services/data-stores#enable-studio-access)

### 2순위 — 스테이지 스킵 Developer Product
- **목표:** 막힌 플레이어가 Robux로 다음 스테이지로 넘어감 (수익화 1차).
- **대상 스크립트:** 새 Script `ServerScriptService/SkipStage` + 클라이언트 버튼 UI(`StarterGui`).
- **구현 방향:** `MarketplaceService.ProcessReceipt`는 서버에서만 처리하고, 같은 영수증을 두 번 지급하지 않는다. 지급은 Stage+1 후 그 체크포인트로 이동. 늘어난 Stage는 `ProgressSave`가 자동으로 저장한다(저장 직후 지급을 확정하려면 `ProgressSave`에 즉시 저장 함수를 추가하는 것을 검토). Checkpoints의 "다음 번호만" 규칙과 충돌하지 않게 서버에서 직접 Stage를 설정. 상품 등록(가격 설정)은 **사용자가 직접** Creator Dashboard에서 한다.
- **완료 조건:** Studio 테스트 구매로 Stage +1과 이동 확인, Stage 11에서는 구매 불가, 회귀 테스트 통과.

### 3순위 — 정리 (선택, 사용자 승인 후)
- 체크포인트 1~10의 옛 속성 `Stage` 제거 (E-5), 백업 정리 여부 결정 (E-6).

### 그다음
- 보상형 광고, 3단계 비주얼(재질·조명·사운드·썸네일).

---

## 주의사항

- 사용자는 로블록스 초보자다. 한국어로 답하고 용어를 짧게 설명한다.
- 사용자가 Studio에서 Play 중일 수 있다. Play를 멈출 때는 알린다. Play 중에도 `Server` datamodel로 읽기는 가능하다.
- 체크포인트 이름(`1`~`11`), `IsFinish`, `leaderstats.Stage`는 바꾸지 않는다.
- DataStore를 넣은 뒤에는 키 이름·데이터 형식을 바꾸지 않는다.
- AI는 Studio를 Publish하거나 게임 공개 설정을 바꾸지 않는다.
- 공개 저장소다. 토큰, API 키, 쿠키, 비밀번호를 코드나 커밋에 넣지 않는다.

## Studio 미반영 변경

`src/`만 고치고 아직 Studio에 반영하지 못한 변경을 여기에 적는다.

- (없음)
