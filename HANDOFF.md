# HANDOFF.md — 인수인계 문서

> 이 문서는 **현재 상태 스냅샷**이다. 작업을 마치거나 AI를 전환할 때 **최신 상태로 덮어 갱신**한다.
> 지난 이력은 `NOTES.md`와 `git log`에 있다. 규칙은 `AGENTS.md`를 따른다.
> 모든 항목은 실제 파일, Git, Studio를 확인한 결과로 적는다. 확인하지 못한 것은 "미확인"이라고 표시한다.
> 이 문서만 읽고도 이전 대화 없이 개발을 이어갈 수 있게 쓰는 것이 목표다.

---

## H. 인수인계 시점 (먼저 읽기)

| 항목 | 내용 |
|---|---|
| 마지막 작업 AI | **Claude Code** (Claude Opus 5.5) — 로봇 작업장 1단계(핵심 루프), 2단계(저장·오프라인 수입), 3단계 일부(전시대·안내선·밸런스). 그 전: Codex (연구소 첫 버전) |
| 작업 시점 | 2026-11-17 |
| 다음 작업 AI | Codex 또는 Claude Code. 사용자 직접 플레이(PC·모바일) 피드백을 받아 3단계 다듬기. 실제 저장 재접속 검증은 끝났다(F ⑭) |
| 게임 이름 | 마이오비 (Studio place 이름) / 실험실 탈출 오비와 꼬마 로봇 연구소 |
| Place ID | `77293997616106` |
| Universe ID (GameId) | `10777081510` |
| 소유 | 개인 계정 (CreatorType = User) |
| Studio 인스턴스 ID | 2026-11-16 기준 `c45b95a2-fc62-4fb8-907e-0df1421a14db`. **실행할 때마다 바뀐다.** 새 세션에서 `list_roblox_studios`로 다시 조회하고, placeId가 위 값인 인스턴스만 사용한다 |
| Studio 모드 | 작업 종료 시 **Edit 모드** (Play 테스트 종료함) |
| 로컬 폴더 | `C:\RobloxProjects\MyObby` |
| Git | `main` 브랜치, `origin/main`(https://github.com/Ssungmin-Park/MyObby, 공개)과 동기화. 시작할 때 `git status`, `git log --oneline -5`로 다시 확인 |
| 마지막 게임 수정 | 2026-11-17 Claude Code: **3단계 일부** — `RobotLabHud`에 연구실 전시대·안내선·구역 열기 안내, `RobotLabConfig` 온실 60→40·레벨업 수리비 배수(`LevelCostStep`), `RobotLab` `repairCost` 레벨 반영. 그 전: **저장 추가** — `ServerScriptService/RobotLabSave`(신규 ModuleScript), `RobotLab`(불러오기·저장 연결), `RobotLabHud`("저장 안 됨" 표시), `RobotLabConfig`(보관함 상한 4시간, 수입 함수 공용화). 그 전: 로봇 작업장 확장. `ReplicatedStorage/Modules/RobotLabConfig`(신규), `Remotes/RobotLabState`·`RobotLabAction`(신규), `ServerScriptService/RobotLab`·`RobotLabHud` 교체, `Workspace/RobotLab`에 폐품 처리장·`SpawnPoints`·장치 7개 추가. v1 스크립트와 고정 로봇·상점 장치는 `ServerStorage/RobotLabV1Backup`으로 옮김(삭제 없음). 모두 ChangeHistoryService 기록(Ctrl+Z 가능) |
| Studio 저장 상태 | `persistedToCloud = true`인 클라우드 place다. **로봇 작업장 확장·저장 추가의 클라우드 저장(Ctrl+S) 여부는 미확인** — 사용자에게 저장을 요청했다 |
| Studio API 접근 | **켜짐** (2026-11-17 사용자가 파일 → 체험 설정 → 보안에서 켬. 새 Studio에서는 "게임 설정"이 "체험 설정"으로 바뀜). Studio Play는 실제 게임과 같은 DataStore를 쓴다 |
| 실제 저장 데이터 | 테스트로 **사용자 본인 키**에 값이 남아 있다: `Progress_v1/Player_12007797600` = Stage 11, `RobotLab_v1/Player_12007797600` = 부품 10·삐삐 Lv.1·튜토리얼 완료. 지우려면(RemoveAsync) 사용자 승인 필요 |
| 백업 상태 | 스크립트 11개는 `src/`에서 관리하고 Studio와 체크섬 일치. 연구소 맵은 `tools/build-robot-lab.luau`(v1) → `tools/expand-robot-lab.luau`(확장) 순서로 다시 만들 수 있다. 연구소 v1은 `ServerStorage/RobotLabV1Backup`, 오비 옛 버전은 `ServerStorage`에 있다 |
| 게임 공개 상태 | 확인하지 않았고 바꾸지 않았다. AI는 Publish하지 않는다 (AGENTS.md §8 규칙 9) |

---

## A. 프로젝트 개요

- **방향 전환 (2026-11-17 사용자 결정):** 점프맵보다 **오래 접속해 있을 수 있는 주제**를 원한다. Codex가 제안한 "꼬마 로봇 연구소"를 장시간 플레이용 **로봇 작업장**(수집·성장형)으로 키우기로 했다. 기존 오비는 그대로 두고 연구소 입구로 연결한다.
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
