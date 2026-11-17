# HANDOFF.md — 인수인계 문서

> 이 문서는 **현재 상태 스냅샷**이다. 작업을 마치거나 AI를 전환할 때 **최신 상태로 덮어 갱신**한다.
> 지난 이력은 `NOTES.md`와 `git log`에 있다. 규칙은 `AGENTS.md`를 따른다.
> 모든 항목은 실제 파일, Git, Studio를 확인한 결과로 적는다. 확인하지 못한 것은 "미확인"이라고 표시한다.
> 이 문서만 읽고도 이전 대화 없이 개발을 이어갈 수 있게 쓰는 것이 목표다.

---

## H. 인수인계 시점 (먼저 읽기)

| 항목 | 내용 |
|---|---|
| 마지막 작업 AI | **Codex** — 환생·변종 2인 검증, 테스트 훅 2개, 도감과 기본 리더보드 겹침 수정 |
| 작업 시점 | 2026-11-17 |
| 다음 작업 AI | **Codex: G-0 지시서(환생·변종 2인 로컬 테스트)를 그대로 실행.** 그다음 **전체 서버 순위표**(OrderedDataStore, 계획 승인 먼저). 서버 최대 인원은 2026-11-17 사용자가 Creator Hub에서 50 → 8로 바꿈 |
| 게임 이름 | 마이오비 (Studio place 이름) / **주력: 로봇 고물상 타이쿤**(멀티플레이). 부가: 실험실 탈출 오비, 로봇 작업장(꼬마 로봇 연구소) |
| Place ID | `77293997616106` |
| Universe ID (GameId) | `10777081510` |
| 소유 | 개인 계정 (CreatorType = User) |
| Studio 인스턴스 ID | 2026-11-16 기준 `c45b95a2-fc62-4fb8-907e-0df1421a14db`. **실행할 때마다 바뀐다.** 새 세션에서 `list_roblox_studios`로 다시 조회하고, placeId가 위 값인 인스턴스만 사용한다 |
| Studio 모드 | 작업 종료 시 **Edit 모드** (Play 테스트 종료함) |
| 로컬 폴더 | `C:\RobloxProjects\MyObby` |
| Git | `main` 브랜치, `origin/main`(https://github.com/Ssungmin-Park/MyObby, 공개)과 동기화. 시작할 때 `git status`, `git log --oneline -5`로 다시 확인 |
| 마지막 게임 수정 | 2026-11-17 Codex. `Junkyard`에 음수 UserId용 Studio 테스트 훅 2개 추가. `JunkyardHud`에서 도감을 보는 동안 기본 리더보드를 숨김. Studio와 `src/` 스크립트 18개 체크섬 일치. |
| Studio 저장 상태 | `persistedToCloud = true`. **2026-11-17 Studio 업데이트로 재시작된 뒤에도 3-2까지의 스크립트 18개(체크섬 일치)·고물상 맵(받침대 14칸)·Remote 6개가 모두 남아 있어 클라우드 저장을 간접 확인했다.** AI는 저장·Publish하지 않는다 |
| Studio API 접근 | **켜짐** (2026-11-17 사용자가 파일 → 체험 설정 → 보안에서 켬. 새 Studio에서는 "게임 설정"이 "체험 설정"으로 바뀜). Studio Play는 실제 게임과 같은 DataStore를 쓴다 |
| 실제 저장 데이터 | 테스트로 **사용자 본인 키**에 값이 남아 있다: `Progress_v1` = Stage 11, `RobotLab_v1` = 부품 10·삐삐 Lv.1, `Junkyard_v1` = 돈 약 31·받침대 삐삐/너트/스펀지(일반 세트 완성). 지우려면(RemoveAsync) 사용자 승인 필요 |
| 백업 상태 | 스크립트 18개(Script·ModuleScript·LocalScript)는 `src/`에서 관리하고 Studio와 체크섬 일치(2026-11-17 3-2 반영 후). 맵 생성 코드: 연구소 `tools/build-robot-lab.luau` → `tools/expand-robot-lab.luau`, 고물상 `tools/build-junkyard.luau`. 백업: `ServerStorage/ObbyServer_backup`, `StagesBackup`, `RobotLabV1Backup` |
| 게임 공개 상태 | 확인하지 않았고 바꾸지 않았다. AI는 Publish하지 않는다 (AGENTS.md §8 규칙 9) |

---

## A. 프로젝트 개요

- **2차 방향 전환 (2026-11-17 사용자 결정, 최신):** 로봇 작업장은 "혼자 하는 게임이라 재미없다". 사용자가 원하는 것은 **여럿이 함께 오래 하는 게임 + 상점(다른 플레이어 방해/나에게 도움) + 도감 수집(완성 보상 포함)**. 사용자가 예로 든 인기 장르("~를 건설하세요", "~스쿼드를 만드세요"류)는 흐름만 참고하고 이름·캐릭터·맵은 따라 하지 않는다. 그래서 **"로봇 고물상 타이쿤"**을 새 주력 모드로 만들고 있다(B-11).
  - 루프: 가운데 컨베이어에 흐르는 고장 난 로봇을 **돈으로 구매**(모두가 같은 벨트를 보며 경쟁) → 머리 위에 들고 **내 기지 받침대**에 배치 → **초당 수입**이 금고에 쌓임 → 금고를 밟아 수령 → 더 비싼 로봇.
  - 멀티: 남의 기지 로봇 **훔치기**, 주인이 쫓아가 **붙잡기**, **방어막**(60초). 희귀 로봇 등장·도감 세트 완성은 서버 전체 알림.
  - 도감: 18종 6등급. 등급 3종을 모두 모으면 **영구 수입 배수 + 머리 위 칭호**.
  - 승인된 단계: 1) 핵심(완료, 2인 테스트만 남음) 2) 저장·오프라인 수입 3) 상점(방해·방어·도움 아이템, Robux 상품), 서버 이벤트, 협력 목표 4) 환생·변종·비주얼.
- **1차 방향 전환 (2026-11-17 사용자 결정):** 점프맵보다 **오래 접속해 있을 수 있는 주제**를 원한다. Codex가 제안한 "꼬마 로봇 연구소"를 장시간 플레이용 **로봇 작업장**(수집·성장형)으로 키우기로 했다. 기존 오비는 그대로 두고 연구소 입구로 연결한다.
- **로봇 작업장 핵심 루프:** 구역에서 부품 줍기 → 수거함에 넣기 → 고장 난 로봇 신호 찾기 → 수리대에 맡기기(부품 + **실제 시간**) → 수리한 로봇이 **계속 부품을 벌어 줌**(보관함) → 업그레이드·새 구역 열기 → 더 희귀한 로봇. 오래 머물게 하는 장치: 실시간 수리 대기, 자동 수입, 12종 도감과 4개 등급, 같은 로봇 재수리로 레벨업(최대 5), 업그레이드 4종, 구역 3곳.
- **오비 구조 (기존):** 시작 발판(Stage 0) → 체크포인트 1~10 → 체크포인트 11(EXIT) = 탈출. 죽으면 마지막 체크포인트에서 1초 뒤 부활. 리더보드에 Stage 표시.
- **개발 목표:** 출시 가능한 게임 + 공개 GitHub 저장소를 포트폴리오로 활용.
- **단계:** 1단계 그레이박스(재미 검증) → 2단계 시스템(저장, 수익화) → 3단계 비주얼.
- **현재 완성도:** 오비 그레이박스 + 로봇 작업장 1단계(핵심 루프·업그레이드)를 플레이할 수 있다. 오비 진행 저장은 구현했고 실제 DataStore 검증이 남았다. 로봇 작업장 저장(`RobotLab_v1`)과 오프라인 수입을 구현했고 가짜 저장소로 검증했다. **실제 DataStore 재접속은 Studio API 접근 거부로 미검증.**

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

프로젝트 스크립트 9개의 바이트 크기와 체크섬이 Studio와 `src/`에서 일치한다.

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
- **DataStore 2개:** 오비 `Progress_v1` (`ProgressSave`, B-1b), 로봇 작업장 `RobotLab_v1` (`RobotLabSave`, B-10). `DataStoreService`를 쓰는 곳은 이 두 모듈뿐이다.
- 확인한 Studio 테스트에서는 API 접근 거부로 쓰기가 발생하지 않았다. 운영 저장소의 실제 데이터 유무는 미확인이다.
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

### B-11. 로봇 고물상 타이쿤 (2026-11-17, 1단계)

**모드 전환:** 플레이어 속성 `Mode` = `"Junkyard"`(기본, 접속 시 설정) 또는 `"Obby"`. `Respawn`은 Mode가 Junkyard면 아무것도 안 하고, `Junkyard` 스크립트가 자기 기지 `Spawn`으로 보낸다. 고물상 `ObbyPortal` → 오비(현재 Stage 체크포인트), 오비 시작 발판의 `JunkyardPortal`(Workspace/Junkyard 안에 있음) → 내 기지. 로봇 작업장 입구(시작 발판·EXIT)는 그대로.

**맵 `Workspace/Junkyard`** (X 290~510, Z 0~200, 바닥 윗면 Y 40.5, `tools/build-junkyard.luau`)
- `Belt`: Z 100, X 315→485 (속성 `StartPos`, `EndPos`). 양옆 `BeltRail`, 시작 `BeltStart`(고물 투입구), 끝 `BeltEnd`.
- `Bases/Base1~8` (2026-11-17 6→8개): 북쪽 1~3·7(Z 23~57, 입구 +Z), 남쪽 4~6·8(Z 143~177, 입구 −Z), X 340/400/460, 7·8은 X 520. 바닥은 X 290~550로 넓힘. **서버 최대 인원 8명: 2026-11-17 사용자가 웹 Creator Hub → 구성 → 플레이스 → 마이오비 → 최대 방문자 수에서 50 → 8로 바꿈(Studio 체험 설정에는 이 항목이 없다).** 속성 `Index`, `Front`, `Center`, `OwnerUserId`, `OwnerName`, `Vault`, `LockedUntil`. 자식: `Floor`, `Wall`(높이 12 — 점프로 못 넘음, 뒷벽에 이름판 `Sign`), `Shield`(기지 전체를 덮는 ForceField 상자, 잠기면 반투명 0.5), `Pads/Pad1~10`(각 `RobotPrompt`, 1.5초 누르기), `Vault`(밟으면 수령, `Amount` 빌보드), `LockButton`(`LockPrompt`), `Spawn`(투명).
- `ObbyPortal`(298, 42.5, 100), `JunkyardPortal`(오비 시작 발판 −X쪽).

**설정 `ReplicatedStorage/Modules/JunkyardConfig`** — 6등급(일반·고급·희귀·에픽·전설·신화: 벨트 확률 600/250/100/40/9/1, 가격 25/100/500/2.5K/15K/100K, 초당 1/4/15/60/300/1500, 세트 보너스 +5/10/15/25/40/100%), 로봇 18종(등급별 3), 시작 돈 50, 벨트 2.5초 간격·초속 4, 받침대 10, 판매 50%, 운반 중 걷기 11, 훔치기 1.5초, 붙잡기 거리 6, 방어막 60초+쿨타임 60초. **로봇 id는 저장 키가 될 예정이라 바꾸지 않는다.**

**벨트 `ServerScriptService/JunkyardBelt`** (ModuleScript) — 서버는 `{id, robotId, spawnTime}`만 기록하고 `JunkyardBelt` RemoteEvent로 "Add"/"Remove"/"Snapshot"을 보낸다. 위치 = 시작 + 방향 × 속도 × (서버 시간 − spawnTime). 클라이언트가 같은 공식으로 그린다(서버 파트 복제 없음 → 렉 적음). 전설·신화가 나오면 서버 전체 알림.

**서버 `ServerScriptService/Junkyard`** (Script)
- 접속 시 빈 기지 배정(6개 모두 차면 오비 모드 + 안내), 돈 50, leaderstats에 `돈`·`초당` 추가(Leaderstats가 만든 뒤).
- `JunkyardAction` 요청: `"Buy"(itemId)` — 운반 중 아님, 기지 있음, 서버 공식 위치에서 14스터드 이내, 돈 충분, 아직 안 팔림 → 돈 차감, 머리 위에 로봇(용접, 걷기 11). `"Lock"` — 방어막.
- 0.2초마다: 운반 중인 플레이어가 **내 기지 안**이면 빈 받침대(도둑 예약석 제외)에 배치 → 도감 등록. 훔친 로봇이면 주인이 6스터드 안에 오면 **원래 받침대로 복귀**. 잠긴 기지 안의 다른 사람은 입구 밖으로 이동. 1초마다 기지 수입 × 도감 배수를 금고에 적립.
- 받침대 프롬프트: 주인 → **팔기**(가격 50%), 다른 사람 → **훔치기**(방어막 아님, 운반 중 아님, 내 기지 있음). 훔치면 그 받침대는 예약석(되돌아올 자리). 도둑이 죽거나 나가면 원래 주인에게 복귀. 주인이 나가면 훔쳐 가던 로봇은 도둑 것.
- 산 로봇은 죽어도 계속 들고 있다(새 캐릭터에 다시 붙임). 로봇을 든 채로는 오비 포털 이용 불가.
- 플레이어 속성(클라이언트 표시용): `Mode`, `BaseIndex`, `Money`, `Income`, `Multiplier`, `Catalog`(JSON 배열), `Carrying`, `CarryStolen`, `LockedUntil`, `LockCooldownUntil`.
- `JunkyardNotify`: `"Info"`/`"Alert"`/`"Global"`/`"Money"` 알림.
- **저장 `ServerScriptService/JunkyardSave`** (ModuleScript, 2026-11-17)
  - **저장 형식 (바꾸지 말 것):** DataStore `Junkyard_v1`, 키 `Player_<UserId>`, 값 `{ version = 1, data = { money, catalog = {id=true}, pads = {["받침대 번호"] = 로봇 id} }, lastSeen, lock }`.
  - `RobotLabSave`와 같은 세션 잠금·불러오기 실패 시 저장 안 함·알 수 없는 형식 보존·값 정리(없는 로봇·잘못된 받침대 번호 제거, 받침대 로봇은 도감에 추가, 돈 0~1e15).
  - 고물상 데이터는 돈·도감·기지에 흩어져 있어 `track(player, getData)`로 저장 때마다 `Junkyard`의 `snapshot(state)`를 부른다. snapshot은 금고 돈을 돈에 합치고, 들고 있던 **산** 로봇은 빈 받침대에 넣거나(없으면 산 값 환급), 도둑이 들고 가는 중인 예약석은 넣지 않는다(주인이 나가면 도둑 것이 되므로 중복 방지).
  - 퇴장: `Junkyard`가 `JunkyardSave.finish(player)`를 기지를 비우기 **전에** 부른다(값을 즉시 모으고 저장은 따로 진행, lock 해제). 60초 자동 저장, `BindToClose`.
  - 불러오기: 기지가 배정된 플레이어만. 불러오는 동안(`Loading` 속성) 구매·훔치기 막음. 성공 → 돈·도감(배수·칭호)·받침대 복원, **오프라인 수입 = 초당 수입 × 50% × 경과(최대 3시간)**을 금고에 넣고 알림. 실패·잠김 → 기본값으로 플레이, `SaveOff` 속성, HUD "⚠ 저장 안 됨".
  - 떠나 있는 동안 기지는 서버에서 비워지므로 아무도 훔칠 수 없다. 기지 6개가 꽉 차서 기지가 없는 플레이어는 불러오지도 저장하지도 않는다.

**클라이언트 `StarterPlayerScripts/JunkyardHud`** — 잠긴 기지마다 위에 "🛡 방어막 N초" 빌보드(모두에게 보임, 300스터드), 왼쪽 위 패널(돈, 초당·도감 배수, 운반 상태, 방어막 버튼, 도감 버튼), 도감 창(18칸 + 세트 보너스 진행), 위쪽 알림, 벨트 로봇 직접 그리기와 구매 프롬프트, 받침대 버튼 문구(내 기지 "팔기 +금액" / 남의 기지 "훔치기"). Mode가 Junkyard일 때만 보인다.

### B-14. 로봇 고물상 4단계: 환생과 변종 (2026-11-17, 구현 · 성공 경로 미검증)

**목적:** "끝"이 없던 게임에 반복 목표를 준다. 끝까지 가면 처음부터 다시 하되 더 빠르게 성장하고, 새 수집 목표(변종)와 자랑거리(머리 위 표시·리더보드)를 얻는다.

**로봇 키:** 기본 로봇 `"Pippi"`, 변종 `"Pippi@Gold"`. 받침대·운반·저장(`pads`)에 이 키를 쓴다. `Config.splitKey/getRobot/rarityOf/variantOf/isValidKey/robotIncome/robotValue/robotName`가 키를 받는다. **벨트에는 기본 로봇만 흐른다(모두에게 같음)** → 살 때(`buy`) 서버가 `Config.rollVariant(환생 단계)`로 변종을 정한다. 희귀 로봇 비 선물도 같은 방식.

**설정 (`JunkyardConfig`)**
- 환생 조건: 돈 `RebirthBaseCost`(100만) × `RebirthCostGrowth`(3)^현재 단계 + 도감에 `RebirthRequiresRarity`(신화) 1종 이상. 운반 중이면 불가.
- 환생 보상: 수입 × `rebirthMultiplier` = 1 + 0.5 × 단계(영구), 머리 위 `rebirthMark`(⭐1~4, 💎5~9, 🌈10+).
- 변종 `Variants`: 금색 ✨(환생 1+, 15%, 수입·가치 ×3, 페이지 완성 +25%), 다이아 💎(3+, 5%, ×10, +50%), 무지개 🌈(5+, 1%, ×30, +100%). 희귀한 것부터 굴린다.
- 초보 보호 `ProtectionGap` = 2: 환생 단계가 2 이상 높은 사람은 내 로봇을 훔칠 수 없다.

**서버 (`Junkyard`)**: `JunkyardAction "Rebirth"` → 돈·받침대 로봇·금고·업그레이드 초기화, 도감·변종 도감·무료 EMP·Robux 혜택·환생 단계 유지, 전체 알림, 즉시 저장. 도감 배수 = 기본 세트 보너스 + 변종 페이지 보너스(`recomputeMultiplier`). 수입 = 로봇 수입(변종 배수) × 도감 배수 × 환생 배수 × 수입 2배 패스. 리더보드에 `환생` 열. 받침대 파트에 `RobotKey` 속성(클라이언트 판매 가격 표시용). 플레이어 속성 `Rebirth`, `VariantCatalog`(JSON).

**저장 (`JunkyardSave`)**: Data에 `rebirth`(0~1000), `variantCatalog` 추가. 받침대 값은 변종 키 허용(`isValidKey`), 받침대의 변종은 기본·변종 도감 모두에 넣는다. 옛 데이터는 환생 0·변종 도감 비어 있음으로 읽힌다(version 1 유지).

**클라이언트 (`JunkyardHud`)**: 상점 `⭐ 환생` 탭(조건·보상·다음 해금 변종 표시, **4초 안에 두 번 눌러야 실행**), 도감 창 페이지 버튼(기본 → 금색 → 다이아 → 무지개), 패널 "도감 x… · 환생 ⭐N", 변종 로봇은 변종 색 + Sparkles.

**테스트 (2026-11-17, Claude Code)**
- 단위 16항목 PASS: 키 나누기, 변종 수입·가치(금색 삐삐 3/75), 잘못된 키, 이름 표시, 환생 비용 1M→3M→9M, 배수 1.5/2.0, 머리 표시, 변종 확률(환생 0: 없음, 1: 금색 14.8%, 5: 무지개 0.95%·다이아 4.9%), 페이지 보너스, 저장 정리(변종 받침대 허용·잘못된 변종 제거·도감 동기화·환생 소수→정수·옛 데이터 기본값).
- Play(데이터 변경 없음): 리더보드 `환생=0`, 패널 "환생 ⭐0", 돈 부족 환생 요청 거절("965.2K 더 필요")·돈 그대로, 상점 환생 행 표시, 받침대 "팔기 +250"(RobotKey), 에러 0.
- **Codex 2인 로컬 테스트 (2026-11-17, 음수 UserId만):**
  - A 자동 테스트 통과. Player1이 신화 오메가·테스트 자금으로 환생 1 달성. 머리 위 ⭐1, 리더보드 1, 돈 50, 받침대·금고 0, 업그레이드 기본값, 기존 도감과 무료 EMP 5회 유지, Player2에게 전체 알림 수신. 다시 환생하면 필요 금액 300만을 안내하고, 운반 중 환생도 거절함.
  - B 실제 구매에서 환생 1인 Player1 금색 5/20, 환생 0인 Player2 변종 0/20. 금색 키·색·Sparkles·도감 등록·판매 문구와 실수령 37 확인(기본 삐삐 판매 12, 금색은 기본 가치의 3배에 판매율을 적용하고 내림). 20회 표본으로 확률을 추정하지 않음. 실제 다이아·무지개 구매는 미검증.
  - D 자동 테스트 통과. 단계 차이 2에서 높은 쪽 훔치기 거절·초보 보호 알림 확인. 반대 방향과 차이 1에서 허용. 훔친 금색 로봇이 주인의 붙잡기로 복귀함.
  - E 자동 테스트 통과. 금색 도감 18종, 기본 도감 배수 대비 +0.25 확인. 빈자리가 없을 때 팔기 프롬프트로 자리를 확보함.
  - 금색 도감 페이지 진입과 18/18 표시를 직접 확인했다. 좁은 테스트 창에서 기본 리더보드가 도감 상단 버튼을 가리는 현상을 재현했다. 도감 표시 중 플레이어 목록을 숨기고 도감이 닫히거나 HUD가 비활성화되면 이전 설정을 복원하는 수정 적용. 수정 후 재시험과 재접속 복원을 위해 2인 테스트 재실행 요청 중.
  - 첫 세션 로그에 모델 경로를 잘못 조회한 테스트 명령 오류 1건이 있었으며 경로를 고쳐 변종 장식 확인을 통과했다. 게임 스크립트 오류·경고는 서버와 양쪽 클라이언트에서 관찰하지 못했다.
  - Studio 전용 `DebugGiveRobot`·`DebugSetRebirth`는 음수 UserId에만 적용한다. Studio와 `src/` 스크립트 18개 일치. `Junkyard` 54416 B / 695026141, `JunkyardHud` 31506 B / 222537563.

### B-13. 로봇 고물상 3-2: Robux 상품 (2026-11-17, 코드 완료 · 상품 id 미입력)

**상품 (`JunkyardConfig`)** — `id`가 0이면 상점에 "준비 중"이고 결제창을 띄우지 않는다. 사용자가 만든 뒤 id를 넣는다. `robux`는 화면 표시용 예상 가격(실제 가격은 Creator Dashboard 값).
| 종류 | 키 | 이름 | 효과 | 예상 가격 |
|---|---|---|---|---|
| 게임패스 | `DoubleIncome` | 💰 수입 2배 | 기지 수입 ×2 (`IncomePassMultiplier`) | 399 |
| 게임패스 | `VipBase` | 👑 VIP 기지 | 방어막 +30초, 충전 시간 ×0.5, 머리 위 `[👑 VIP]` | 249 |
| 게임패스 | `OfflineBoost` | 🌙 오프라인 수입 강화 | 오프라인 수입 50%→100%, 최대 3→8시간 | 149 |
| 개발자 상품 | `EmpPack` | ⚡ EMP 5개 | 무료 EMP 5회(`empCharges`, 저장됨). EMP를 쓸 때 돈 대신 먼저 차감 | 49 |
| 개발자 상품 | `InstantShield` | 🛡 즉시 방어막 | 충전 중이어도 방어막 켜기, 켜져 있으면 시간 이어 붙임 | 25 |
| 개발자 상품 | `RareRain` | ✨ 희귀 로봇 비 | 서버 전체 60초 동안 희귀 이상 가중치 ×5, 산 사람 이름 전체 알림, workspace 속성 `RainUntil`. **+ 산 사람에게 희귀 이상 로봇 1개 확정 선물**(희귀 66.7·에픽 26.7·전설 6.0·신화 0.7%, `Config.rainGiftOdds`, 받침대가 꽉 차면 그 로봇 가격만큼 돈) — 경쟁 게임에서 "남만 좋아지는" 느낌을 줄이려고 사용자 승인 후 추가 | 99 |

**등록된 개발자 상품 id (2026-11-17 사용자 생성, Roblox 조회로 확인: 판매 중):** `InstantShield` = 3732684298 (25 R$), `EmpPack` = 3732684191 (49 R$), `RareRain` = 3732684420 (99 R$). 상점 버튼에 실제 가격 표시 확인. 상품 설명은 비어 있음(사용자가 Creator Hub에서 입력 예정). **게임패스 3종은 사용자가 보류** → 상점에 "준비 중". **2026-11-17 사용자가 Studio 테스트 구매로 결제창 표시와 효과 적용을 직접 확인했다**(실제 Robux 차감 없는 Studio 테스트 결제).

**희귀 로봇 비 확정 선물 테스트 (2026-11-17, Studio 훅):** 받침대 로봇 2→3(루미, 희귀), 도감 추가, 돈 변화 없음, 비 60초, 상점에 확정 선물 확률 표시, 에러 0. 받침대가 꽉 찬 경우의 돈 지급은 코드 검토만.

**계획에서 바꾼 점:** VIP 기지는 계획의 "받침대 +4" 대신 "방어막 +30초·충전 절반·VIP 표시"로 했다(맵 기지에 받침대 15칸 이상 둘 자리가 없음).

**결제 처리 `ServerScriptService/JunkyardStore`** (ModuleScript)
- `MarketplaceService.ProcessReceipt`는 이 모듈 한 곳에서만 설정한다(`Junkyard`가 `JunkyardStore.start({grantProduct, onPassOwned})` 호출).
- 영수증 기록: DataStore `Receipts_v1`, 키 `Receipt_<PurchaseId>`, 값 `{ userId, product, at }`. 흐름: 기록 있음 → `PurchaseGranted` / 플레이어 없음·로딩 중·지급 실패·기록 확인 실패 → `NotProcessedYet`(Roblox가 다시 보냄) / 지급 → 기록 → `PurchaseGranted`. 기록 저장만 실패하면 `NotProcessedYet`이라 재시도 때 **다시 지급될 수 있다**(Roblox 권장 흐름과 같은 알려진 한계).
- 게임패스: 접속해 저장 데이터를 불러올 때 `UserOwnsGamePassAsync`로 확인(`checkPasses`), 게임 안에서 사면 `PromptGamePassPurchaseFinished`로 바로 적용. 게임패스 보유는 저장하지 않는다(매번 Roblox에 확인).
- 지급 후 `JunkyardSave.saveNow(player)`로 바로 저장.
- 플레이어 속성: `Passes`(JSON 배열), `EmpCharges`.
- **Studio 전용 테스트 훅**(`RunService:IsStudio()`일 때만 연결, Codex의 `DebugGiveMoney`와 같은 방식): 서버에서 `workspace:SetAttribute("DebugMoneyUserId", userId)` 후 `DebugGrantProduct` = 상품 키, `DebugGivePass` = 게임패스 키.

**클라이언트**: 상점에 `💎 Robux` 탭. 버튼은 `PromptGamePassPurchase`/`PromptProductPurchase`만 띄우고 지급은 서버가 한다. 희귀 로봇 비 행에 등급별 확률 공개(평소 → 비: 일반 60→37.5%, 고급 25→15.6%, 희귀 10→31.2%, 에픽 4→12.5%, 전설 0.9→2.8%, 신화 0.1→0.3%). EMP 행은 무료 EMP가 있으면 "⚡ 무료 사용". 패널에 "✨ 희귀 로봇 비! N초".

**테스트 (2026-11-17, Claude Code, Play 1인)**
- 영수증 처리 단위 테스트(복제본 + 가짜 영수증 저장소 + 가짜 지급 함수) 7항목 PASS: 첫 결제 지급·기록, 같은 영수증 재지급 없음, 지급 실패 → NotProcessedYet·기록 없음, 기록 확인 실패 → 지급 안 함, 기록 저장 실패 → NotProcessedYet, 모르는 상품 id, 서버에 없는 플레이어.
- Studio 전용 훅으로 효과 확인: EMP 5개 → 무료 EMP 0→5, 무료 EMP 사용 시 돈 그대로·4개 남음·충전 시작 / 즉시 방어막 90초(+다시 사면 179초로 이어 붙음) / 희귀 로봇 비 60초·패널 표시 / 수입 2배 초당 2.1→4.2 / VIP 칭호 `[👑 VIP] [일반 수집가]` / 상점 Robux 탭 6행·"준비 중"·확률 공개 표시 / 클라이언트 에러 0.
- **미검증:** 실제 결제창(상품 id 필요), 오프라인 수입 강화의 실제 적용(오래 기다려야 함), VIP 충전 시간 절반의 실제 적용, 무료 EMP 재접속 유지(코드상 저장됨), 모바일 화면.
- 테스트로 사용자 본인 `Junkyard_v1`에 무료 EMP 4개가 남았다(게임패스는 테스트 훅이라 저장 안 됨).

### B-12. 로봇 고물상 3-1: 게임 돈 상점·희귀 로봇 열차 (2026-11-17, 구현 완료·테스트 일부)

**설정 (`JunkyardConfig`)**
- 영구 업그레이드 `Config.Upgrades` (단계 0 = 기본, 저장됨): `Pads` 받침대 10→12→14 (5천/5만), `Shoes` 걷기 16→19→22 (3천/3만), `ShieldTime` 방어막 60→90→120→150초 (1천/1만/10만), `Alarm` 경보기 (5천), `Fence` 레이저 울타리 (2만). 함수 `upgradeValue(id, level)`, `upgradeCost(id, level)`.
- 소모 아이템 `Config.Items` (저장 안 됨, 가격 = max(최저가, 초당 수입 × 초)): `EMP`(최저 500, ×60초) — 주변 10스터드 다른 사람 3초 기절(걷기 0·점프 0), 훔쳐 가던 로봇은 주인에게 복귀, 쿨타임 30초 / `Gloves` 도둑 장갑(최저 1000, ×90초) — 5분간 훔치기 1.5→0.6초. 함수 `itemPrice(id, income)`.
- 열차: `TrainEvery` 600초마다 `TrainDuration` 30초 동안 희귀 이상만 1초 간격.

**서버**
- `JunkyardEvents`(Script): 열차 타이머. workspace 속성 `NextTrainAt`, `TrainUntil`. **테스트용**: 서버에서 `workspace:SetAttribute("DebugTrainNow", true)` 하면 바로 출발.
- `JunkyardBelt`: `startTrain(duration)`, `trainActive()`. 열차 중에는 `TrainRarities`만 뽑고 `TrainInterval` 간격.
- `Junkyard`: `JunkyardAction`에 `"Upgrade"(id)`, `"Item"(id)` 추가. `applySpeed`(기절 > 울타리 느려짐 8 > 운반 11+신발 보너스 절반 > 신발). `padLimit`/`setPadLocks`(열리지 않은 받침대 11~14는 어둡고 반투명, 배치 불가). 경보기·울타리는 0.2초 틱에서 "다른 사람이 기지에 새로 들어온 순간" 처리(경보: 주인에게 `JunkyardNotify("Alarm", 글, 침입자 UserId)`, 같은 침입자 10초 간격). 방어막 지속은 `ShieldTime` 단계. **받침대 팔기·훔치기는 `PromptButtonHoldBegan`~`Triggered` 사이 실제 누른 시간을 검증**(장갑이면 0.6초, 아니면 1.5초, 0.25초 여유).
- 플레이어 속성 추가: `Upgrades`(JSON), `GlovesUntil`, `EmpReadyAt`, `StunnedUntil`.
- 저장: `JunkyardSave` Data에 `upgrades` 추가(옛 데이터는 0단계), 받침대 번호 허용 1~`MaxPads`(14). 형식 version은 1 그대로(추가 필드).

**클라이언트 (`JunkyardHud`)**: 패널에 `🛒 상점` 버튼과 열차 남은 시간 줄. 상점 창(탭 ⚡방해/🛡방어/💪도움, 행마다 설명·현재→다음 값·가격 버튼, 돈 부족하면 빨간 버튼). 경보 알림을 받으면 침입자 캐릭터를 6초 동안 빨간 Highlight(벽 너머 보임). EMP 기절 표시. 장갑 착용 시 남의 받침대 프롬프트 HoldDuration을 0.6으로.

**3-1 테스트 상태:** F의 Codex 추가 검증 참고. 팔기·2인 훔치기·상점 5종 1단계 구매와 복원·EMP·장갑·경보기·울타리·열차 확인. 모바일 상점 UI와 최고 단계는 미검증.

### B-10. 로봇 작업장 (꼬마 로봇 연구소 확장, 2026-11-17)

**맵 `Workspace/RobotLab`** (Codex v1 + Claude 확장, X 120~180 / Z −10~126, 바닥 Y 40)
| 구역 | Z 범위 | 내용 |
|---|---|---|
| 연구실 (Lab) | −10~28 | 도착점 `Arrival`, 수리대 `Repair`, 수거함 `Deposit`, 업그레이드 4종(`Upgrade_Bag/Detector/RepairSlots/RepairSpeed`, 안내 범위 4.5), 오비 출구 `Return` |
| 부품 창고 (Warehouse) | 28~60 | 처음부터 열림. 출구 쪽에 `Unlock_Greenhouse` |
| 실험 온실 (Greenhouse) | 60~92 | 부품 40개로 열기. 안쪽에 `Unlock_Scrapyard` |
| 폐품 처리장 (Scrapyard) | 92~126 | 부품 250개로 열기 (이번에 추가) |
- `SpawnPoints/<구역>/PointN`: 부품 더미·로봇 신호가 나타나는 보이지 않는 표식(Lab 1, 나머지 구역 각 10).
- 입장: 오비 시작 발판의 `Enter`, EXIT의 `EnterAtExit`. 구역 잠금은 "부품·로봇이 안 나옴" 방식(벽으로 막지 않음).

**설정 `ReplicatedStorage/Modules/RobotLabConfig`** (ModuleScript, 서버·클라이언트 공용) — 등급 4종(수리비·수리 시간·분당 수입), 로봇 12종, 구역 3곳(열기 비용·더미 수·더미 가치·등급 확률), 업그레이드 4종(단계별 비용·값), 각종 시간·거리. **id(영문 키)는 저장 데이터에 들어갈 예정이라 바꾸지 않는다.**

**서버 `ServerScriptService/RobotLab`** (Script) — 모든 판정 담당
- 플레이어별 세션: 저장 대상 `data`(parts, storage, robots{id→레벨}, repairs{robotId, finishAt=os.time}, upgrades{id→레벨}, zones, tutorialDone) + 접속 중 상태(bag, carrying, signal, piles, respawns).
- 부품 더미는 **플레이어마다 따로** 생성(구역별 6개, 주우면 12초 뒤 재생성). 로봇 신호도 플레이어별 1개(튜토리얼은 연구실의 삐삐, 무료·15초 수리).
- 1초마다: 수리 완료(첫 수리 → 도감 등록, 중복 → 레벨업, 최고 레벨 → 수리비 환급), 도우미 수입을 보관함에 적립(상한 = 분당 수입×60분, 최소 30), 더미·신호 재생성, 연구소 안이면 상태 전송.
- 장치(ProximityPrompt): 거리·생존 재확인, 0.25초 연타 방지. 원격 `RobotLabAction`: `"Collect"(pileId)`는 거리 10 이내, `"PickUp"`은 거리 10 이내만 인정. 1초 20회 초과 요청 무시. 그 밖의 요청·잘못된 값은 무시.
- 오비로 복귀(`Return`)하거나 캐릭터가 바뀌면 연구소 밖 상태가 되고, 같은 서버 세션 동안 데이터는 유지된다.

**클라이언트 `StarterPlayer/StarterPlayerScripts/RobotLabHud`** (LocalScript) — 표시와 요청만
- `RobotLabState`로 받은 상태로 HUD(부품·가방·보관함, 도감 수·분당 수입, 수리 현황 카운트다운, 지금 할 일, 탐지기 거리, 메시지)와 도감 창(버튼)을 그린다.
- 부품 더미·고장 난 로봇은 **이 플레이어 화면에만** 만든다(`workspace.RobotLabLocal`). 더미에서 수평 4.5스터드 안에 들어가면 자동 줍기 요청(0.3초마다 재시도). 로봇은 프롬프트로 줍는다. 탐지기 범위 안이면 로봇 위에 신호 표시.
- 업그레이드·구역·수리대 프롬프트 문구에 이 플레이어의 비용을 표시(클라이언트에서만 바뀜).

- **연구실 전시대 (3단계):** 연구실 뒤쪽(X 126~156, Z 18·24)에 12칸. 수리한 로봇은 등급 색과 "이름 Lv.N", 아직 없는 로봇은 반투명 "??? · 등급". 이 플레이어 화면에만 만든다.
- **안내선 (3단계):** 발밑에서 목표까지 빛나는 Beam. 운반 중+부품 충분 → 수리대 / 가방 가득 → 수거함 / 운반 중+부품 부족 → 가방으로 충분하면 수거함, 아니면 가장 가까운 부품 더미 / 튜토리얼 로봇 / 탐지기 범위 안의 신호. 자유 탐색 중과 목표 5스터드 안에서는 끈다.
- 남은 구역을 열 부품이 모이면 목표 문구로 알려 준다.
- **레벨업 수리비:** 이미 가진 로봇을 또 수리하면 `기본 수리비 × (1 + 현재 레벨 × LevelCostStep)` (일반 8 → 16 → 24 → 32 → 40). 최고 레벨이면 기본 수리비(환급액과 같음).

**Remote**: `ReplicatedStorage/Remotes/RobotLabState`(서버→클라이언트), `RobotLabAction`(클라이언트→서버, 서버에서 검증).
**저장 `ServerScriptService/RobotLabSave`** (ModuleScript, 2026-11-17)
- **저장 형식 (바꾸지 말 것):** DataStore `RobotLab_v1`, 키 `Player_<UserId>`, 값 `{ version = 1, data = Data, lastSeen = os.time(), lock = { job, at } 또는 없음 }`. `Data` = parts, storage, robots{id→레벨}, repairs{robotId, finishAt}, upgrades{id→레벨}, zones{id→true}, tutorialDone.
- **세션 잠금:** 불러올 때 `UpdateAsync`로 이 서버의 lock을 남긴다. 다른 서버의 lock이 120초 안에 갱신됐으면 5초 간격으로 최대 30초 기다리고, 그래도 잠겨 있으면 이번 접속은 저장하지 않는다. 120초 넘은 lock은 꺼진 서버의 것으로 보고 가져온다. 60초 자동 저장이 lock을 갱신한다. 저장할 때 lock이 다른 서버로 넘어가 있으면 쓰지 않고 그 플레이어 저장을 멈춘다(`lostLock`).
- **불러오기 실패·잠김·알 수 없는 형식(표가 아님, version > 1):** 기본 데이터로 플레이는 되지만 저장하지 않는다. HUD 제목에 "⚠ 저장 안 됨". 알 수 없는 형식은 덮어쓰지 않는다.
- **정리(sanitize):** 없는 로봇·업그레이드·구역 id 제거, 레벨·단계를 허용 범위로, 음수·NaN 부품은 0, 수리 목록은 수리대 수까지, 보관함은 상한까지.
- **저장 시점:** 60초 자동, 퇴장(lock 해제), 서버 종료 `BindToClose`(최대 25초 대기, 진행 중 저장 수 `inFlight`까지 기다림). 요청 오류는 3회 재시도.
- **오프라인:** 불러올 때 `(지금 − lastSeen) × 분당 수입`을 보관함 상한(분당 수입 × 240분)까지 더하고, 그사이 끝난 수리를 처리해 "떠나 있는 동안 …" 메시지로 알려 준다.
- **저장하지 않는 것:** 가방 속 부품, 운반 중인 로봇, 부품 더미 위치(접속할 때 새로 생김). 튜토리얼 완료는 삐삐를 수리대에 맡길 때 기록한다(운반 중에 나가면 다음 접속에 다시 나타나게).
- 오비 `ProgressSave`·`Progress_v1`은 바꾸지 않았다.

---

## C. 진행 중인 개발

- **로봇 고물상 타이쿤 (주력):** 1단계(F ⑮·⑯), 2단계 저장(F ⑰) 완료. **3-1(게임 돈 상점·열차)은 구현·Studio 반영까지 끝났고 기능 테스트가 대부분 남았다(B-12).** 그다음 3-2 Robux 상품, 3-3 협력 거대 로봇.

- **로봇 작업장:** 1단계(핵심 루프·업그레이드, F ⑪)와 2단계(저장·오프라인 수입, F ⑫) 구현·자동 테스트 완료. 실제 DataStore 재접속 검증 완료(F ⑭). **남은 것: 실제 걷기·모바일 확인, 밸런스·연출(3단계).**
- **기존 오비:** `ProgressSave` 구현 및 모의 저장소 검증 완료(`0eceb0d`). 실제 저장·재접속 검증은 Studio API 접근 거부로 중단돼 있다.
- **보류:** 오비 스테이지 스킵, Robux 상품·보상형 광고, 출시용 비주얼과 사운드.

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
| 1 | 연구소의 클라우드 저장 여부 미확인 | MCP에서 현재 Edit 모델과 클라우드 place 연결 확인 | Ctrl+S 후 저장 완료 표시 확인 | **사용자 확인 필요** |
| 2 | 실제 모바일 기기·터치 조작 미검증 | 자동 테스트는 순간이동 방식 | — | 미검증 |
| 3 | ~~진행 저장의 실제 DataStore 동작 미검증~~ | 원인: 사용자가 설정 위치를 못 찾음(새 Studio는 파일 → 체험 설정 → 보안) | 2026-11-17 설정을 켠 뒤 실제 재접속 테스트 통과(F ⑭) | **해결** |
| 3b | Studio API 접근이 꺼져 있으면 Play 시작 때 불러오기를 3번 시도하느라 약 3초 동안 경고 로그가 나오고 시작 발판에 머문다 | 의도된 재시도 | — | 정상 동작. 실제 서버에서는 해당 없음 |
| 4 | 오비 전체 맵(파트·모델)은 Git에 백업이 없음 | Rojo 미사용, 스크립트는 `src/`에서 관리 | 연구소 맵은 `tools/build-robot-lab.luau`로 재생성 가능 | 오비 맵은 Studio 버전 기록과 `ServerStorage`의 일부 백업 참고 |
| 5 | 체크포인트 1~10에 옛 속성 `Stage`(숫자)가 남아 있음 | 이전 단일 스크립트의 흔적. 현재 스크립트는 이름으로 판정하므로 무해 | — | 정리 선택 사항 (삭제 전 승인) |
| 6 | `ServerStorage` 백업 2개 남아 있음 | 의도된 백업 | — | 삭제 여부는 사용자 결정 |
| 7 | Claude Code GitHub 플러그인 커넥터 연결 실패 | 토큰 환경 변수 없음 | gh CLI로 대체 | 의도적 미사용 |
| 8 | Codex의 Roblox Studio MCP 연결 | 현재 인스턴스의 Place ID와 Universe ID를 대조했다 | 구조 확인과 Play 테스트 | 확인 완료. 새 세션마다 인스턴스 다시 조회 |
| 9 | Lighting에 템플릿 기본 효과(Bloom, DepthOfField 등)가 켜져 있음 | 템플릿 기본값 | — | 3단계 비주얼 때 결정 |

해결됨: 이전 문서의 "최신 테스트에서 탈출 메시지 미확인" → 2026-11-16 재테스트에서 **클라이언트 표시 확인**(F 참고). 이전 테스트에서는 확인 시점이 4초 표시 시간을 넘겼던 것으로 본다.

---

## F. 테스트 상태

### 2026-11-17 Codex 3-1 추가 검증

- 실제 팔기 프롬프트를 1.8초 눌렀을 때 서버 `PromptButtonHoldBegan` 1회와 `Triggered`를 관찰했다. 로봇이 판매되고 돈이 12 늘었다. 팔기 이벤트 연결은 정상이다.
- Studio 전용 서버 훅을 `Junkyard`에 추가했다. 서버에서 `DebugMoneyUserId`를 대상 UserId로 설정하고 `DebugGiveMoney`를 양의 정수(최대 100만)로 설정하면 해당 플레이어에게 지급한다. 서버 속성 변경만 사용하며 실서버에서는 연결하지 않는다.
- 사용자 본인에게 테스트 돈 40000을 지급하고 업그레이드 5종을 각 1단계 구매했다. 받침대 12칸, WalkSpeed 19, 방어막 남은 시간 89.6초를 확인했다.
- Play 종료 후 재접속해 업그레이드 5종 모두 1단계 복원, WalkSpeed 19, Pad12 사용 가능, SaveOff false를 확인했다. 판매 결과와 테스트 자금·구매 내역은 사용자 본인의 `Junkyard_v1`에 남는다.
- 사용자가 2인 로컬 서버를 실행했다. 각 테스트 인스턴스에서 Place ID를 먼저 확인했다. 일반 훔치기(1.8초 입력), 장갑 사용 후 HoldDuration 약 0.6초와 훔치기 성공, 도둑 사망 후 원래 받침대 복귀를 확인했다.
- EMP는 상대 속도 0, 훔친 로봇 반환, 약 30초 쿨타임, 연속 요청 시 추가 차감 없음, 3초 후 속도 16 복구를 확인했다. 경보기는 주인에게 침입자 UserId 알림과 빨간 Highlight, 울타리는 침입자 속도 8을 확인했다.
- DebugTrainNow로 30초 열차를 실행해 희귀 이상 30개, 마지막 출현 간격 1.001초, 종료 알림을 확인했다. 기존 벨트의 일반 로봇은 그대로 흘러가며 새 출현분만 열차 등급을 적용한다.
- 준비 단계의 벨트 항목 조회 및 소수값 정확 비교로 테스트 명령 assertion이 발생했다. 실제 벨트 Snapshot을 받아 구매하고 장갑 시간을 오차 허용으로 검사한 재시험은 통과했다. 게임 스크립트 런타임 오류는 관찰되지 않았다.
- 수정한 Junkyard는 41136 B, 체크섬 19761485로 Studio Edit와 src가 일치한다. 모바일 상점 UI, 업그레이드 최고 단계, 모든 엣지 케이스는 미검증이다.

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

**⑨ 2026-11-16 연구소·상점 및 오비 회귀 테스트 (Codex)** — 시작 및 EXIT 입장, 발견·수리 순서, 도감 3/3, 구매 2종, 잔액 부족·중복 구매·배터리 없이 루미 발견 차단, 기존 Stage와 위치로 복귀, 같은 세션 재입장 보존을 실제 프롬프트 이벤트로 확인했다. 기존 오비의 진행·리스폰·장애물 및 클라이언트 탈출 메시지도 확인했다. 낙사 직후 체크포인트 3으로 이동하는 첫 검사에서 부활 위치 보정과 겹쳐 재실행했고, 캐릭터가 체크포인트 2에서 안착한 뒤 3~11을 통과했다. 콘솔에는 기존 DataStore 접근 거부 경고와 골인 로그만 있었다. 자동 이동으로 검증했으며 실제 걷기 동선·모바일 조작은 미검증이다.

**⑩ 2026-11-16 Claude Code 전환 직전 확인 (Codex, MCP Edit 읽기)** — Place ID와 Universe ID 일치, 스테이지 10개·체크포인트 11개, 체크포인트 10 라벨과 11의 `IsFinish`, 장애물 태그 4종을 확인했다. 연구소는 하위 객체 70개와 상호작용 9개(입구 2, 복귀 1, 수리대 1, 로봇 3, 상품 2)가 있고, 백업 스크립트는 비활성 상태이며 스테이지 백업 7개가 있다. Studio와 `src/`의 스크립트 9개 모두 바이트 크기 및 체크섬 일치. 직전 Play 테스트 결과는 ⑨에 기록했다.

**⑪ 2026-11-17 로봇 작업장 1단계 테스트 (Claude Code, Play, 클라이언트에서 실제 프롬프트·원격 사용)**

| 항목 | 결과 |
|---|---|
| 입장 → HUD 표시, 연구실 도착, 창고 부품 더미 6개와 튜토리얼 로봇 표시 | PASS |
| 튜토리얼: 삐삐 줍기 → 수리대(무료, 15초) → 도감 1/12, 분당 수입 1.0 | PASS |
| 부품 더미: 걸어서/서서 줍기 → 가방 증가, 12초 뒤 재생성, 수거함에 넣으면 부품으로 | PASS (빠르게 지나치면 놓치던 문제를 재시도 0.3초·서버 거리 10으로 고침) |
| 두 번째 신호(볼트, 일반): 줍기 → 수리대 안내문 "부품 8개" → 45초 수리 → 도감 2/12, 수입 2.0 | PASS |
| 보관함 적립과 수거함에서 받기 | PASS |
| 부품 부족 시 업그레이드·구역 열기 거절 메시지 / 15개 모은 뒤 탐지기 2단계, 안내문 갱신(45스터드, 다음 50개) | PASS |
| 업그레이드 장치 간격 6스터드에서 옆 장치 안내가 뜨던 문제 → 안내 범위 4.5로 수정 후 정상 | PASS |
| 보안: 멀리서 줍기 요청 60건, 잘못된 값("abc", 숫자 action, 없는 action "GiveParts") → 모두 무시 | PASS |
| 오비 복귀 → HUD·로컬 표시 숨김, 시작 발판 / 재입장 시 같은 서버 세션 데이터 유지 | PASS |
| 오비 회귀: 체크포인트 3칸 진행, 낙사 후 체크포인트 3에서 리스폰(거리 0.00) | PASS |
| 클라이언트·서버 에러 | 없음 (기존 DataStore 접근 거부 경고만) |
| Studio ↔ `src/` 스크립트 10개 크기·체크섬 | 일치 |

**⑫ 2026-11-17 로봇 작업장 저장 테스트 (Claude Code, Play)**

가짜 저장소를 넣은 `RobotLabSave` 복제본으로 실행(실제 DataStore는 건드리지 않음). 16항목 모두 PASS:
새 플레이어(기본 데이터·lock 남김), 저장 후 같은 값 복원(부품·레벨·업그레이드·구역·튜토리얼·수리 목록·lastSeen), 퇴장 저장 시 lock 해제, 다른 서버 lock → 기다린 뒤 locked·데이터 그대로, lock 빼앗긴 뒤 저장 → lostLock·덮어쓰지 않음, 120초 넘은 lock 가져오기, 표가 아닌 값 → 불러오기·저장 모두 failed·그대로, version 2 → failed, 망가진 필드 정리(음수 부품·NaN·레벨 99·없는 로봇·문자열 값·수리 목록 초과), 오프라인 10분 → +40(분당 4), 하루 → 상한 240에서 멈춤, lastSeen 없음 → 0, 요청 2번 실패 후 성공, 3번 실패 → failed·쓰기 없음.

실제 게임 흐름(API 접근 거부 상태): 불러오기 3회 실패 → HUD "⚠ 저장 안 됨", 튜토리얼·수집·수리·수거함·도감 등록 정상, 오비 진행·낙사 리스폰(거리 0.00) 정상, 클라이언트 에러 0. 콘솔에는 예상한 접근 거부·테스트 경고만. Studio ↔ `src/` 스크립트 11개 체크섬 일치.

**아직 안 한 것:** 실제 DataStore로 저장 → 재접속 복원, 두 서버 사이 이동, 실제 오프라인 시간 경과.

**⑭ 2026-11-17 실제 DataStore 재접속 테스트 (Claude Code, 사용자가 API 접근을 켠 뒤)**

| 항목 | 결과 |
|---|---|
| Play 시작 시 `Progress_v1`, `RobotLab_v1` 읽기 | 성공 (불러오기 2초, 경고 없음). 오비는 기존 값 없음 → Stage 0, 작업장은 새 레코드 + 이 서버 lock 생성 |
| 1차 접속: 오비 Stage 3, 작업장 튜토리얼(삐삐 수리)·부품 10 → Play 종료 | 저장됨: `RobotLab_v1` = 부품 10, 삐삐 Lv.1, tutorialDone, lastSeen. 이전 lock은 해제돼 다음 접속이 기다리지 않음 |
| 2차 접속 | 오비 Stage 3, 체크포인트 3 위에서 시작(거리 0.00) / 작업장 부품 10·도감 1/12·전시대 "삐삐 Lv.1"·튜토리얼 대신 창고 신호 | 
| Stage 11까지 진행 → 종료 → 3차 접속 | Stage 11, EXIT 위(거리 0.01), "탈출 성공!" **다시 뜨지 않음** |
| 출력 로그 | 경고·에러 없음 |

참고: 운반 중이던 희귀 로봇(스프링)은 설계대로 저장되지 않았다.

**⑱ 2026-11-17 로봇 고물상 3-1 기본 확인 (Claude Code, Play 1인)** — 불러오기 후 돈 161·업그레이드 모두 0·걷기 16, Pad11 투명도 0.7(잠김), 돈 부족 시 방어막 강화·EMP 요청 거절(돈 그대로), HUD "🚂 다음 희귀 로봇 열차 9:57", 클라이언트·서버 에러 없음. 나머지 기능 테스트는 미실행(B-12).

**⑲ 2026-11-17 기지 8개 (Claude Code)** — Studio 확인 결과 `Players.MaxPlayers` 60, 기지 6개라 7번째 플레이어부터 고물상 불가였다. 기지 3·6을 복제해 X+60에 7·8 추가, 바닥 확장, 안내 문구에서 숫자 제거. 1인 Play: 기지 7·8 위에 서도 떨어지지 않음, 에러 없음. 7~8명 동시 배정은 미검증(코드는 Bases 폴더의 모든 기지를 읽음).

**⑰ 2026-11-17 로봇 고물상 저장 (Claude Code)**
- 가짜 저장소 15항목 PASS: 새 플레이어(돈 50, lock), 저장·불러오기 같은 값, 퇴장 시 lock 해제, 다른 서버 lock → locked, lock 빼앗긴 저장 → lostLock, 만료 lock 가져오기, 알 수 없는 형식 보존, 망가진 값 정리(음수 돈, 없는 로봇, 받침대 번호 0·11·2.5·문자, 받침대 로봇 도감 추가), NaN 돈 → 0, 오프라인 1시간 = 18000(초당 10)·하루 = 3시간치 54000·lastSeen 없음 0, 요청 실패 재시도.
- 실제 DataStore: 1차 접속에서 일반 로봇 2개 배치 + 세 번째를 든 채로 종료(돈 3, 금고 약 28) → 재접속 시 돈 31, 받침대 1 삐삐·2 너트·**3 스펀지(들고 있던 로봇)**, 도감 3종 → **일반 세트 완성 x1.05, 칭호 [일반 수집가]**, 오프라인 수입 금고 10, 불러오기 1초, 경고 없음.
- 2인 실행 확인 안 한 것: 훔친 로봇이 재접속 후에도 도둑 쪽에 남는지, 도둑질 도중 주인이 나간 경우.

**⑮ 2026-11-17 로봇 고물상 1단계 (Claude Code, Play 1인)**

| 항목 | 결과 |
|---|---|
| 접속 → Mode Junkyard, 기지 1 배정, 기지 스폰(340, _, 49), HUD 표시, 리더보드 Stage·돈 50·초당 0 | PASS |
| 벨트: 로봇 6개 표시, 1초에 4.00스터드 이동 | PASS |
| 일반 로봇 구매 → 돈 50→25, 머리 위 운반 모델, 걷기 11 | PASS |
| 기지 안 진입 → 받침대 자동 배치, 초당 1, 도감 등록 알림 | PASS |
| 5초 후 금고 6 → 금고 밟기 → 돈 +6 | PASS |
| 내 받침대 프롬프트 "삐삐 / 팔기 +12 / 1.5초" → 팔기 후 돈 +12, 프롬프트 꺼짐 | PASS |
| 방어막: 버튼 → "방어 중 60초", 방패 투명도 0.5, 다시 누르면 "이미 켜져 있음" | PASS |
| 오비 포털 → Mode Obby, 저장된 Stage 11 체크포인트, HUD 숨김 / 고물상 포털 → Mode Junkyard, 기지 스폰 | PASS |
| 고물상에서 사망 → 기지 스폰 / 오비 모드 사망 → 체크포인트 11(거리 0.01) | PASS |
| 클라이언트·서버 경고·에러 | 없음 |
| Studio ↔ `src/` 스크립트 체크섬 | 일치 |

**⑯ 2026-11-17 2인 로컬 서버 테스트 (사용자 직접 + Claude)**
- 사용자 확인(체크리스트 1~5): 각자 기지 배정, 구매·배치, 훔치기(도둑 머리 위 운반·주인 알림), 도둑 기지 배치, 주인 붙잡기 → 복귀, 방어막 밀어내기·훔치기 거절 — **모두 됨**.
- Claude 확인(6): 두 클라이언트가 같은 벨트 로봇(id 190)을 같은 서버 시각에 구매 요청 → Player3만 구매(돈 363→338), Player4는 돈 변화 없음. 이때 실패한 쪽에 알림이 없어 "다른 사람이 먼저 샀어요" 알림을 추가했다.
- 사용자 피드백 반영: ① 방어막이 켜졌는지 잘 안 보임 → 입구 막대만 보이던 방패를 **기지 전체를 덮는 상자**로 바꿈 ② 남은 시간을 모름 → 잠긴 기지 위에 **"🛡 방어막 N초"** 큰 빌보드(모두에게) ③ 벽을 점프로 넘을 수 있음(의도 아님) → **벽 높이 6 → 12**. 이 세 가지는 Studio·`src/` 반영과 체크섬만 확인했고, 실행 화면 확인은 다음 Play에서 필요.
- 참고: 2인 테스트 창(서버 1, 클라이언트 2)은 테스트가 실행된 뒤 잠시 지나면 Studio MCP 목록에 이름 없이 나타난다. `get_studio_state`로 Server/Client를 구분해 조작할 수 있다.

**미검증:** 도둑 사망 시 복귀(코드 경로만), 벽 높이·방어막 상자·남은 시간 빌보드의 실제 화면, 도감 세트 완성 보너스·칭호·전체 알림(시간이 오래 걸려 미실행), 전설·신화 등장 알림.

**렉 측정:** 이번 Play에서 클라이언트 FPS 15였지만 **벨트를 숨겨도 15로 같았고**, 벨트 모델 17개 이동 비용은 프레임당 0.04ms. 게임 코드가 원인이 아니라 Studio 창이 포커스를 잃어(사용자가 다른 창 사용 중) 렌더링이 느려진 것으로 본다(이전 측정은 60 FPS). Studio 메모리 2.8GB.

**⑬ 2026-11-17 로봇 작업장 3단계 일부 (Claude Code)**
- 밸런스 시뮬레이션(파이썬, 1분 주기 근사): 원래 값은 일반 로봇 중복 수리가 싸서 30분 만에 분당 수입 ~30, 온실은 40~48분에야 열림 → 레벨업 수리비 배수 추가, 온실 60→40. 조정 후 30분에 도감 5~7종·분당 11~17, 온실 18~30분, 2시간에 도감 9~10종. 근사 모델이라 실제 플레이로 다시 확인해야 한다.
- Play 테스트: 입장 시 전시대 12칸(0/12)과 튜토리얼 로봇으로 안내선 / 삐삐 운반 중 → 수리대로 안내선 / 수리 완료 → 전시대 "삐삐 Lv.1" / 다음 로봇 운반 중 부품 0 → 가장 가까운 부품 더미로 안내선, 수리대 안내 "볼트 맡기기 (부품 8개)" / 오비 복귀 시 전시대·안내선 숨김 / 클라이언트 에러 0. 레벨업 수리비는 무작위 신호라 실행으로 확인하지 못했고 코드 검토만 했다.
- Studio ↔ `src/` 스크립트 11개 체크섬 일치.

검증 한계: 이동은 순간이동과 `Humanoid:MoveTo`로 했다. 에픽·전설 로봇(20분·90분 수리), 온실·처리장 열기 성공, 레벨업·최고 레벨 환급, 여러 플레이어 동시 접속은 아직 직접 확인하지 않았다.

### 아직 테스트하지 않은 항목
- 실제 모바일 기기 터치 조작, 저사양 기기 성능
- 로봇 작업장: 실제 서버 두 곳 사이 이동(세션 잠금 대기), 몇 분 이상의 실제 오프라인 수입, 접속 중 수리가 오프라인에 끝나는 경우 (모두 가짜 저장소 테스트는 통과)
- 로봇 작업장: 실제 플레이어의 걷기 동선과 안내 이해도, 장시간 밸런스(업그레이드·구역 비용), 에픽·전설 수리, 구역 열기 성공, 레벨업, 여러 명 동시 접속
- 60초 자동 저장(실제 저장소에서 시간 경과로 확인한 적 없음)
- 여러 플레이어가 동시에 접속했을 때 (Mover 발판 동시 탑승, 리더보드)
- 실제 서버(공개 게임)에서의 네트워크 지연 상황

---

## G. 다음 개발 계획 (우선순위 순)

### G-0. Codex 지시서: 환생·변종(B-14) 2인 로컬 테스트 (2026-11-17 Claude Code 작성, 사용자가 Codex에게 넘김)

**Codex 진행 기록.** 환생·구매·초보 보호·금색 도감 18종 테스트 결과는 B-14에 있다. Player1 재접속 비교 기준은 환생 2, 금색 도감 18종, 금색 받침대 `Pad2=Quasar@Gold`, `Pad7=Sponge@Gold`, `Pad10=Nut@Gold`, 무료 EMP 5회다. 다음 테스트에서 새 Player1의 `SaveOff`가 false인지와 이 값들의 복원을 확인한다. 기본 리더보드 겹침 수정은 도감 열기·금색 페이지 이동·닫기 순으로 재시험한다.

**0. 시작 전 (필수)**
1. AGENTS.md, 이 HANDOFF(특히 B-11~B-14)를 읽는다. `git status`, `git log --oneline -5`로 미커밋 변경이 없는지 확인한다(있으면 멈추고 사용자에게 알림).
2. `list_roblox_studios`에서 placeId `77293997616106`("마이오비") 인스턴스만 쓴다.
3. Studio 스크립트와 `src/`가 같은지 체크섬(`h=(h*31+byte)%1000000007`)으로 확인한다. Codex 수정 반영 후 기대값(바이트/체크섬)은 `ServerScriptService/Junkyard` 54416/695026141, `JunkyardSave` 13463/583590408, `ReplicatedStorage/Modules/JunkyardConfig` 15470/977588474, `StarterPlayerScripts/JunkyardHud` 31506/222537563. 다르면 작업하지 말고 보고한다.

**1. 절대 지킬 것**
- 사용자 본인 계정 저장 키(`Junkyard_v1`의 `Player_<사용자 UserId>`)는 건드리지 않는다. 테스트는 Studio 로컬 서버의 테스트 플레이어(Player1/Player2, UserId 음수)로만 한다.
- DataStore 삭제(RemoveAsync)·형식 변경 금지. 테스트 키(`Player_-1`, `Player_-2`)도 승인 없이 지우지 않는다.
- Publish, `save_place`, 공개 설정 변경 금지(저장은 사용자 Ctrl+S). 파괴적 git 명령 금지. 기존 스크립트 통째 재작성 금지.

**2. 먼저: Studio 전용 테스트 훅 2개 추가**
현재 훅은 `DebugMoneyUserId` + `DebugGiveMoney`(1회 최대 1,000,000), `DebugGrantProduct`, `DebugGivePass`, `DebugTrainNow`뿐이라 "신화 로봇 도감 등록"과 "환생 단계 지정"을 할 수 없다. `ServerScriptService/Junkyard` 맨 아래 `if game:GetService("RunService"):IsStudio() then` 블록 안에, 기존 `DebugGrantProduct`와 같은 모양으로 추가한다.
- `DebugGiveRobot`(문자열 로봇 키, 예 `"<신화 id>"`, `"Pippi@Gold"`): 대상은 `DebugMoneyUserId` 플레이어. `Config.isValidKey(key)`일 때만. 빈 받침대가 있으면 `freePad` → `setPadRobot` → `addToCatalog` → `refreshIncome`(희귀 로봇 비 선물 코드와 같은 순서). 처리 뒤 속성을 nil로.
- `DebugSetRebirth`(정수 0~20): `state.rebirth`를 그 값으로 바꾸고 `syncRebirth(state)`, 도감 배수 재계산(`recomputeMultiplier`), `refreshIncome` 호출(실제 함수 이름은 코드에서 확인). 처리 뒤 속성을 nil로.
- 둘 다 `IsStudio()` 안에만 둔다. `ChangeHistoryService` 기록으로 감싸 반영하고, 같은 변경을 `src/ServerScriptService/Junkyard.server.luau`에 적용한 뒤 바이트·체크섬 일치를 확인한다.
- 신화 로봇 id는 `JunkyardConfig.Robots`에서 `rarity == "Mythic"`인 것을 찾는다.

**3. 테스트 방법**
- Studio 테스트 탭 → "클라이언트 및 서버", 플레이어 2명. 서버 확인·훅 설정은 `execute_luau` Server, 화면 확인은 Client.
- 훅 예(Server): `workspace:SetAttribute("DebugMoneyUserId", Player1.UserId)` 후 `workspace:SetAttribute("DebugGiveRobot", "<신화 id>")`.
- 행동은 클라이언트에서 실제 Remote/Prompt로 한다. 환생: `ReplicatedStorage.Remotes.JunkyardAction:FireServer("Rebirth")`. 훔치기: 상대 기지 받침대의 `RobotPrompt`를 실제로 발동(서버에서 Triggered를 흉내 내지 않음, 누르기 시간 검증이 있음). 캐릭터 이동은 서버 `PivotTo`.

**4. 테스트 항목 (각각 PASS/FAIL + 근거)**
- A. 환생 성공(Player1): 돈 ≥ 1,000,000 + 도감 신화 1종 → Rebirth → 환생=1, 머리 위 ⭐1, 리더보드 "환생" 1, 돈 50, 받침대 로봇 0, 금고 0, 업그레이드 초기화, 도감·무료 EMP 유지, 전체 알림. 바로 다시 Rebirth → 거절(필요 3,000,000). 로봇 운반 중 환생 → 거절.
- B. 변종 구매(Player1, 환생 ≥1): 벨트 로봇 여러 번 구매 → 금색 약 15%. 받침대 키 `"id@Gold"`, 변종 색 + Sparkles, 판매 가격 3배, `VariantCatalog` 속성 기록, HUD 도감 금색 페이지 표시. 필요하면 `DebugSetRebirth` 5로 다이아·무지개 확인. 환생 0인 Player2는 20회 이상 사도 변종이 절대 안 나와야 한다.
- C. 저장: Player1 퇴장 → 재입장 후 환생 단계·변종 도감·받침대의 변종 로봇 유지.
- D. 초보 보호: Player1 환생 2, Player2 환생 0 → Player1이 Player2 로봇 훔치기 거절 + "초보 보호" 알림. Player2가 Player1 로봇 훔치기는 허용. 환생 차이 1이면 허용.
- E. 변종 페이지 완성: `DebugGiveRobot`로 금색 18종을 채운다(받침대가 모자라면 팔면서 진행, 변종 도감은 남음) → 도감 배수 +0.25.
- F. 서버·클라이언트 출력 로그 에러·경고 0.

**5. 문제가 생기면** 필요한 부분만 고치고, Studio 반영 → `src/` 체크섬 일치 → 같은 항목 재테스트. 수치·규칙 변경처럼 설계를 바꿔야 하는 문제는 고치지 말고 사용자에게 먼저 보고한다.

**6. 끝나면**
1. Play를 멈춘다.
2. 이 HANDOFF의 B-14 "테스트"에서 미검증 항목을 결과로 바꾼다("자동 테스트 통과"/"미검증" 구분). 맨 위 표(마지막 작업 AI, 다음 작업 = 전체 서버 순위표, 계획 승인 먼저)를 갱신하고 이 G-0 지시서는 "완료"로 표시한다.
3. NOTES.md에 한두 줄 추가. 통과하면 README의 "환생·변종"을 [x]로.
4. `git status`, `git diff --stat`으로 의도한 파일만인지, 민감 정보(토큰·쿠키·키)가 없는지 확인 → 커밋(예 `[Codex] 환생·변종 2인 테스트 + Studio 테스트 훅`) → `git push`.
5. 사용자에게 한국어로 결과 표, 고친 것, Studio에서 확인할 것, Ctrl+S 저장 안내.

**참고 — 서버 최대 인원:** ✅ 2026-11-17 사용자가 8로 설정 완료(구성 → 플레이스 → 마이오비 → 최대 방문자 수). 아래는 당시 안내: Studio의 체험 설정에는 이 항목이 없다(사용자 확인). 웹 Creator Hub(create.roblox.com) → 내 작품 → 이 체험 → 왼쪽 "장소(Places)" → 장소 선택 → "액세스(Access)"의 최대 방문자 수(Maximum Visitor Count)/서버 크기에서 8로 저장한다. 커뮤니티 보고 기준 경로이며 화면이 다를 수 있다. 8로 저장이 안 되면 사용자에게 알리고, 코드 쪽은 9번째부터 "기지가 꽉 찼다" 안내가 이미 있으므로 급하지 않다.

### 로봇 고물상 타이쿤 (주력, 최우선)
1. **2인 로컬 서버 테스트:** Studio 테스트 탭 → "클라이언트 및 서버"(플레이어 2명) 시작. 훔치기 → 도둑 기지 배치 / 주인이 붙잡기 → 복귀 / 도둑 사망 → 복귀 / 방어막 중 훔치기 거절·밀어내기 / 같은 벨트 로봇을 둘이 동시에 사기.
2. ✅ **2단계 저장** 완료 (B-11 저장, F ⑰).
3. **3-1 마무리 테스트 (다음 AI가 가장 먼저):** 돈이 부족하면 테스트가 어려우니, Studio Play 중 **서버**에서 플레이어 돈을 늘리는 방법이 필요하다(현재 디버그 명령 없음). 방법 제안: `Junkyard` 스크립트에 Studio에서만 동작하는 테스트 훅(`RunService:IsStudio()`일 때 workspace 속성 `DebugGiveMoney`)을 추가하거나, 금고에 쌓이길 기다린다. 확인 목록: ① 업그레이드 5종 구매 → 효과(받침대 12칸 열림·걷기 19·방어막 90초·경보기 알림+빨간 표시·울타리 느려짐) ② 업그레이드가 재접속 후 유지(Junkyard_v1 upgrades) ③ EMP(2인 로컬 서버: 맞은 사람 3초 정지, 훔친 로봇 복귀, 쿨타임 30초) ④ 도둑 장갑(0.6초 훔치기) ⑤ **일반 팔기·훔치기가 누르기 시간 검증 후에도 정상인지**(`PromptButtonHoldBegan`이 서버에서 오는지 꼭 확인. 안 오면 팔기·훔치기가 모두 막히므로 검증 코드를 고쳐야 함) ⑥ `DebugTrainNow`로 열차 → 30초간 희귀 이상만·1초 간격·알림 ⑦ 모바일에서 상점 창 크기.
4. ✅ **3-2 Robux 상품 코드 완료**(B-13). 남은 것: 사용자가 상품을 만들고 id 입력 → 실제 결제 테스트. 원래 계획: 게임패스(수입 2배 399, VIP 기지 249, 오프라인 수입 강화 149)·개발자 상품(EMP 5개 49, 즉시 방어막 25, 서버 전체 희귀 로봇 비 99). 사용자가 Creator Dashboard에서 상품을 만들고 ID를 알려 줘야 한다. 구매 처리 `ProcessReceipt`는 서버에서만, 영수증 중복 지급 방지 기록 필수. 확률 변경 상품은 확률 공개.
5. **3-3 협력 거대 로봇**: 서버 전체 기부 진행 막대 → 완성 시 10분 서버 수입 2배, 상위 기부자 공지.
6. (예전 계획) **3단계 상점·이벤트 원안:** 방해(EMP 기절, 빠른 도둑), 방어(방어막 연장, 레이저 울타리), 도움(수입 2배·행운·받침대 추가·이동 속도), 서버 전체("희귀 로봇 비"), 10분마다 희귀 로봇 열차, 서버 협력 거대 로봇. Robux 상품 등록은 사용자가 Creator Dashboard에서.
4. **4단계:** ✅ 환생·변종 구현(B-14, 2인 테스트는 G-0). 남은 것: 비주얼·사운드. (서버 최대 인원 8명 ✅ 사용자 설정)
5. 기존 오비·로봇 작업장 정리 여부는 고물상이 자리 잡은 뒤 사용자와 결정(삭제 금지, 보관).


### 로봇 작업장 다음 작업 (우선순위 순)

**참고한 장르 사례 (Codex 조사):** 성장으로 탐색 범위를 넓히는 Bee Swarm Simulator, 구역 탐색·수집의 Find the Chomiks, 실시간 성장으로 재접속 목표를 주는 Grow a Garden. 메커니즘만 참고하고 이름·캐릭터·맵은 오리지널로 유지한다.

**A. 2단계 — 저장과 오프라인 수입 ✅ 구현 완료 (2026-11-17, B-10 저장 참고). 실제 DataStore 검증만 남음. 아래는 당시 계획 기록**
- 목표: 나갔다 와도 부품·도감·레벨·업그레이드·구역·수리 중인 로봇이 유지되고, 떠나 있던 동안 도우미 수입이 쌓인다.
- 방향: 새 ModuleScript(예: `ServerScriptService/RobotLabSave`), 새 DataStore(예: `RobotLab_v1`, 키 `Player_<UserId>`). 오비 `Progress_v1`과 **분리**한다. 저장 대상은 `RobotLab`의 `Data` 타입 그대로 + `lastSeen`(os.time). `ProgressSave`와 같은 안전 원칙(pcall 재시도, 불러오기 실패 시 저장 안 함, 서버 종료 시 저장). 다만 부품은 **쓰면 줄어드는 값**이라 "큰 값만 저장" 규칙은 쓸 수 없다 → 세션 잠금 또는 버전 번호 방식 검토.
- 오프라인 수입: `(지금 − lastSeen) × 분당 수입`을 보관함 상한까지. 상한(현재 60분)은 오프라인용으로 따로 둘지 결정(예: 8시간).
- 수리: `finishAt`이 os.time 기준이라 저장만 하면 오프라인 중에도 완료된다.
- 테스트: Studio API 접근이 거부 중이므로 `ProgressSave`처럼 가짜 저장소 주입 테스트를 먼저 한다.

**B. 3단계 — 실제 플레이 확인과 다듬기 (일부 완료: 전시대·안내선·밸런스 1차, ⑬)**
- 사용자가 PC·모바일에서 직접 걸어서 튜토리얼 → 첫 일반 로봇 → 온실 열기까지 해 보고 막히는 곳 확인.
- 수리한 로봇을 연구실에 세워 두기(눈에 보이는 성장), 효과음·알림, 밸런스(첫 30분 동안 무엇을 할 수 있는지) 조정.
- 연구소와 오비의 관계 정리: 오비 완주 보상(예: 부품)을 줄지 사용자와 결정.

### 0순위 — 작업 환경 확인 (매 세션)
- **목표:** 올바른 게임과 최신 상태에서 시작.
- **방법:**
  1. `AGENTS.md`와 이 문서를 읽는다.
  2. `git status`, `git log --oneline -5`를 확인한다.
  3. **Codex라면 Roblox Studio MCP 연결부터 확인한다** (E-8). 없으면 사용자에게 알리고 Studio 작업은 하지 않는다 (AGENTS.md §6 "Studio MCP를 쓸 수 없을 때").
  4. `list_roblox_studios`로 인스턴스 ID를 새로 받고 placeId `77293997616106`을 확인한다.
  5. Studio에는 체크포인트 10 라벨이 올바르게 표시된다. 마지막 클라우드 저장 여부는 사용자에게 확인한다 (E-1).
  6. 스크립트 11개 크기(또는 체크섬)가 `src/`와 같은지 확인한다 (`ReplicatedStorage/Modules/RobotLabConfig` 포함).
- **완료 조건:** 위 항목에서 이상이 없거나, 이상한 점을 사용자에게 보고함.

### ✅ 1순위 — 진행 저장 실제 검증 (2026-11-17 완료, F ⑭). 아래는 당시 계획 기록
- **목표:** 실제 DataStore로 "저장 → 재접속 → 이어하기"를 확인하고 진행 저장을 완료로 기록.
- **먼저 할 일:** 사용자와 함께 API 접근 설정을 확인한다. 확인 방법: Play 중 Server에서 `DataStoreService:GetDataStore("Progress_v1"):GetAsync("Player_0")`을 `pcall`로 호출해 (작업장 `RobotLab_v1`도 같은 방법으로 함께 검증. 테스트 키는 사용자 본인 키만) Error code 7이 사라졌는지 본다 (읽기만, 쓰기 없음). 계속 막히면 스크린샷으로 "Enable Studio Access to API Services" 스위치와 Save 여부를 확인한다.
- **전제:** Studio Game Settings → Security → "Enable Studio Access to API Services" 설정을 사용자와 확인한다. Studio는 실제 게임과 같은 저장소를 쓰며 현재 데이터 유무는 미확인이다. 아래 시나리오는 쓰기 후 Stage가 남는 테스트이므로 대상 키와 예상 최종 값을 먼저 사용자와 확인한다.
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
