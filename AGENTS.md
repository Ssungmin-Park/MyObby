# AGENTS.md — MyObby 공통 개발 지침

이 파일은 **이 프로젝트를 작업하는 모든 AI(Claude Code, OpenAI Codex 등)가 공통으로 따르는 규칙**이다.
도구별 설정은 각 도구 파일(`CLAUDE.md` 등)에 두고, 규칙은 이 파일 한 곳에서만 관리한다.

> **작업을 시작하기 전에 반드시 이 파일과 `HANDOFF.md`를 읽는다.** (§8 참고)

---

## 1. 프로젝트 목적과 게임 콘셉트

- **장르:** 로블록스 오비(장애물 코스) 게임
- **콘셉트:** "실험실 탈출" — 실험실에 갇힌 플레이어가 레이저 복도, 회전 레이저, 움직이는 화물 발판, 보안문을 지나 EXIT까지 탈출한다.
- **핵심 플레이:** 시작 발판(Stage 0) → 체크포인트 1~10을 순서대로 밟으며 점프·장애물 통과 → 체크포인트 11(EXIT) 도달 시 탈출 성공. 떨어지거나 레이저에 닿으면 마지막 체크포인트에서 다시 시작한다. 리더보드에 현재 스테이지가 보인다.
- **목적:** 출시 가능한 게임을 만드는 것, 그리고 개발 과정을 공개 GitHub 저장소에 남겨 **포트폴리오**로 쓰는 것.
- **개발 단계 계획:**
  1. **1단계 그레이박스** — 재미 검증. 색·재질·장식을 넣지 않는다. (예외: 닿으면 죽는 파트는 `Transparency 0.4`로만 구분)
  2. **2단계 시스템** — 진행 저장(DataStore), 스테이지 스킵 상품(Developer Product), 보상형 광고
  3. **3단계 비주얼** — 재질, 조명, 모델, 사운드, 썸네일/아이콘
- 현재 단계와 진행 상황은 `HANDOFF.md`에 있다.

## 2. 개발 환경과 사용 기술

| 항목 | 내용 |
|---|---|
| 엔진 | Roblox Studio (place: "마이오비", placeId `77293997616106`, universeId `10777081510`, 클라우드 저장, 소유자: 개인 계정) |
| 언어 | Luau (`--!strict`) |
| Studio 연결 | Roblox Studio MCP 서버 (Claude Code에서는 `Roblox_Studio`라는 이름). Studio 인스턴스 ID는 실행할 때마다 바뀌므로 매 세션 `list_roblox_studios`로 다시 조회한다 |
| AI 도구 | Claude Code(데스크톱 앱), OpenAI Codex(데스크톱 앱). 사용량에 따라 번갈아 사용 |
| OS | Windows 11 |
| 로컬 프로젝트 폴더 | `C:\RobloxProjects\MyObby` (두 AI 공통) |
| 버전 관리 | git (`main` 브랜치) + GitHub CLI `gh` |
| 원격 저장소 | https://github.com/Ssungmin-Park/MyObby (**공개**) |
| 동기화 도구 | 없음 (Rojo 미사용). Studio와 로컬 폴더는 **자동 동기화되지 않는다.** 스크립트는 Studio에서 `src/`로 **수동 내보내기** |

**중요 — 진짜 원본은 Studio다.**
게임이 실제로 돌아가는 코드와 맵은 Studio place(클라우드)에 있다. `src/`는 그 스크립트를 보관·공개용으로 복사한 **거울(mirror)**이다.
`src/` 파일만 고쳐서는 게임이 바뀌지 않는다.

## 3. 프로젝트 구조와 핵심 파일

### 저장소(이 폴더)

```
AGENTS.md      공통 개발 지침 (이 파일)
HANDOFF.md     인수인계 문서 — 현재 상태 스냅샷, 다음 할 일
CLAUDE.md      Claude Code 전용 설정 (AGENTS.md를 불러옴)
NOTES.md       날짜별 작업 기록 (누적 로그, 지우지 않고 아래에 추가만)
README.md      포트폴리오용 소개 페이지 (GitHub 첫 화면)
docs/screenshots/   README용 Studio 캡처
src/           Studio 스크립트의 거울 (Studio 경로 그대로)
  ServerScriptService/
    Leaderstats.server.luau   리더보드 leaderstats.Stage 생성 + 저장된 진행 불러오기
    ProgressSave.luau         진행 저장 모듈 (DataStore Progress_v1)
    RobotLab.server.luau      로봇 작업장 판정
    RobotLabSave.luau         로봇 작업장 저장 모듈 (DataStore RobotLab_v1, 세션 잠금)
    Checkpoints.server.luau   체크포인트 진행 판정 (바로 다음 번호만 인정)
    Respawn.server.luau       KillZone 낙사 + 마지막 체크포인트 리스폰 (RespawnTime 1초)
    Hazards.server.luau       태그 기반 장애물 구동 (KillPart/Spinner/Mover/TimedDoor)
    Finish.server.luau        골인(IsFinish) 도달 시 Escaped 이벤트 발송
  StarterPlayer/StarterPlayerScripts/
    EscapeMessage.client.luau "탈출 성공!" 4초 표시
.gitignore / .gitattributes   민감 파일 제외 / LF 줄바꿈 고정
```

파일 이름 규칙: Script → `.server.luau`, LocalScript → `.client.luau`, ModuleScript → `.luau`
예: `ServerScriptService/Hazards` → `src/ServerScriptService/Hazards.server.luau`

### Studio 안 구조

```
Workspace/
  Stages/Stage01~Stage10        스테이지별 Model
  Checkpoints/1~11              체크포인트 파트. 이름 = 스테이지 번호.
                                11 = EXIT(골인), 속성 IsFinish = true
  KillZone                      Y=20, 2048×2048 낙사 판정 바닥
  SpawnLocation                 시작 발판 (Y=40)
  Baseplate                     기본 바닥 (Y=-8)
ServerScriptService/            서버 Script 5개 + ModuleScript ProgressSave (위 src/와 1:1)
ReplicatedStorage/Remotes/Escaped   RemoteEvent (서버 → 클라이언트 전용)
ReplicatedStorage/Modules/RobotLabConfig   로봇 작업장 밸런스 데이터 (서버·클라이언트 공용)
ReplicatedStorage/Remotes/RobotLabState, RobotLabAction   로봇 작업장 상태(서버→클라)·요청(클라→서버, 서버 검증)
Workspace/RobotLab/             로봇 작업장 맵 (Interactions = 장치, SpawnPoints = 부품·로봇 출현 지점)
ServerStorage/RobotLabV1Backup  연구소 v1 스크립트·장치 백업 — 승인 없이 삭제 금지
StarterPlayer/StarterPlayerScripts/EscapeMessage   LocalScript
StarterGui, StarterPack, ReplicatedFirst, SoundService, Teams   비어 있음
Lighting/                       템플릿 기본 효과(Sky, Atmosphere, Bloom, SunRays, DepthOfField)만 있음
ServerStorage/
  ObbyServer_backup             옛 단일 스크립트 (Disabled) — 백업
  StagesBackup/Stage04~10       장애물 추가 전 스테이지 — 백업
```

## 4. 현재 구현된 주요 기능 (안정 기능 목록)

진행 중인 작업과 테스트 결과는 `HANDOFF.md`에 있다. 여기에는 **이미 완료되고 테스트된** 기능만 적는다.

- 스테이지 10개 + EXIT. 구간별 장애물:
  - 1–3: 기본 점프
  - 4–5: 낮은 레이저 바
  - 6: 회전 레이저
  - 7–8: 움직이는 발판
  - 9: 시간제 보안문 2개 + 레이저
  - 10: 종합
- 체크포인트: 서버 판정. 바로 다음 번호만 인정해서 뒤로 가기와 건너뛰기를 막는다.
- 리스폰: 낙사(KillZone)하거나 레이저에 닿으면 마지막 체크포인트에서 1초 뒤 부활한다.
- 리더보드: `leaderstats.Stage`. 0은 시작, 11은 탈출 완료.
- 장애물 시스템: CollectionService 태그 + Attribute
  - `KillPart`: 닿으면 사망
  - `Spinner`: Model에 `SpeedDeg` 속성. 막대 `Bar`를 HingeConstraint Motor로 돌린다.
  - `Mover`: Model에 `Range`, `Speed`, `StartSign`, `Pause` 속성. 발판 `Platform`을 PrismaticConstraint Servo로 움직인다.
  - `TimedDoor`: Part에 `Period`, `Offset` 속성. 서버 시간 기준으로 열고 닫는다.
- 골인: EXIT에 도달하면 Stage 11이 되고, 서버가 `Remotes.Escaped:FireClient`로 알려 "탈출 성공!"을 표시한다.

- 진행 저장: 오비 Stage(`Progress_v1`)와 로봇 작업장(`RobotLab_v1`)을 DataStore에 저장한다. 2026-11-17 실제 저장소로 재접속 복원을 확인했다. Studio API 접근은 **파일 → 체험 설정 → 보안**에서 켠다(켜져 있음).

**로봇 고물상 타이쿤 (현재 주력, 멀티플레이):** 접속하면 고물상 기지에서 시작한다. 가운데 컨베이어에서 로봇을 사서 기지 받침대에 두면 초당 수입, 남의 로봇 훔치기·붙잡기·방어막, 도감 세트 보너스. 플레이어 속성 `Mode`("Junkyard"/"Obby")로 어느 모드인지 구분하고 `Respawn`은 Junkyard 모드면 관여하지 않는다. Studio 경로: `Workspace/Junkyard`, `ServerScriptService/Junkyard`·`JunkyardBelt`, `StarterPlayer/StarterPlayerScripts/JunkyardHud`, `ReplicatedStorage/Modules/JunkyardConfig`, `Remotes/JunkyardBelt·JunkyardAction·JunkyardNotify`. 저장은 `ServerScriptService/JunkyardSave`(DataStore `Junkyard_v1`, 세션 잠금, 형식 변경 금지). 상세는 HANDOFF B-11.

**로봇 작업장 (꼬마 로봇 연구소 확장, 이전 주력 → 부가 모드):** 시작 발판과 EXIT에서 입장하는 비점프형 모드. 부품 줍기 → 로봇 수리(실제 시간) → 도우미 수입 → 업그레이드·구역 열기 루프. Studio 경로는 `Workspace/RobotLab`, `ServerScriptService/RobotLab`, `StarterPlayer/StarterPlayerScripts/RobotLabHud`, `ReplicatedStorage/Modules/RobotLabConfig`. 밸런스는 Config 숫자만 바꿔 조정한다. 로봇·업그레이드·구역 id는 저장 데이터 키가 될 예정이므로 바꾸지 않는다. 재접속 저장과 Robux 상품은 미구현이다. 상세는 HANDOFF B-10.

## 5. 코드 작성 규칙과 아키텍처 원칙

### 코드 규칙 (Luau)
- 스크립트 맨 위에 `--!strict`를 쓴다.
- `wait()` 대신 `task.wait()`, `spawn()` 대신 `task.spawn()`, `delay()` 대신 `task.delay()`를 쓴다.
- 주석은 **한국어**로 쓴다.
- 하나의 스크립트에 모든 걸 넣지 말고 **역할별로 나눈다**.
- DataStore 호출은 `pcall`로 감싸고, 실패하면 재시도하고 로그를 남긴다.
- Toolbox 무료 모델 중 스크립트가 들어 있는 것은 사용하지 않는다.

### 아키텍처 원칙
- **서버 권한:** 스테이지 진행, 보상, 구매 판정은 서버에서만 한다. 클라이언트가 보낸 RemoteEvent 값은 반드시 검증한다. 클라이언트는 표시만 담당한다.
- **데이터 주도 장애물:** 새 장애물은 가능하면 **태그 + Attribute**로 만든다. 레벨 디자인을 바꿀 때 스크립트를 고치지 않아도 되게 하기 위해서다.
  - 새 종류가 필요하면 `Hazards`에 `bindTag` 하나를 추가한다.
  - 역할이 크면 별도 스크립트로 나눈다.
- **이름이 곧 데이터:** `Workspace/Checkpoints`의 파트 이름이 스테이지 번호다. 골인은 `IsFinish` 속성으로 표시한다. 체크포인트 이름을 바꾸면 진행 판정이 깨진다.
- **움직이는 물체는 물리 제약으로:** 캐릭터를 태워야 하는 물체는 CFrame 트윈이 아니라 Constraint로 움직이고, `SetNetworkOwner(nil)`을 호출한다.
- **Remote 위치:** RemoteEvent / RemoteFunction은 `ReplicatedStorage/Remotes/`에 두고, 공용 모듈은 `ReplicatedStorage/Modules/`에 둔다.

### 서버와 클라이언트의 역할
| 서버 (`ServerScriptService`) | 클라이언트 (`StarterPlayerScripts`, `StarterGui`) |
|---|---|
| 스테이지 판정, 리스폰 위치, 장애물 구동, 사망 처리, (예정) 저장·구매 처리 | 화면 표시(UI, 메시지, 효과음)만 |
| 값을 결정하고 클라이언트에 알린다 | 받은 값을 보여 주기만 하고 게임 상태를 바꾸지 않는다 |

### RemoteEvent / RemoteFunction 보안
- 클라이언트 → 서버 Remote는 **아무 값이나 보낼 수 있다고 가정**한다(해킹 가능). 서버에서 타입, 범위, 플레이어 상태를 검증한다.
- 클라이언트가 "스테이지를 올려 달라", "보상을 달라"고 직접 요청하는 Remote는 만들지 않는다. 서버가 스스로 판정한다.
- 서버 → 클라이언트 `RemoteFunction:InvokeClient`는 쓰지 않는다(클라이언트가 응답하지 않으면 서버가 멈춘다).
- 현재 Remote는 `Escaped`(서버 → 클라이언트 전용) 하나뿐이다.

### DataStore 안전 원칙 (2단계부터 적용)
- **현재 사용 중인 저장 형식 (바꾸지 않는다):** DataStore `Progress_v1`, 키 `Player_<UserId>`, 값 `{ Stage = 정수 }`. DataStore는 `ServerScriptService/ProgressSave` 한 곳에서만 다룬다. 새 저장 항목이 필요하면 이 모듈을 확장하고, 형식 변경은 마이그레이션 계획을 먼저 승인받는다.
- **로봇 작업장 저장 형식 (바꾸지 않는다):** DataStore `RobotLab_v1`, 키 `Player_<UserId>`, 값 `{ version = 1, data, lastSeen, lock }`. `ServerScriptService/RobotLabSave`에서만 다룬다. 부품은 줄어드는 값이라 "큰 값만 저장"이 아니라 **세션 잠금(lock)**으로 동시 저장을 막는다. 필드를 추가할 때는 `sanitize`에 기본값을 넣어 옛 데이터도 읽히게 하고, 형식을 크게 바꿀 때는 `version`을 올리고 마이그레이션 계획을 먼저 승인받는다.
- 진행은 늘어나기만 한다는 전제로 "저장된 값보다 클 때만 저장"한다. 진행을 낮추는 기능을 넣을 때는 이 규칙을 함께 고친다.
- 저장은 `UpdateAsync` 또는 `SetAsync`를 `pcall`로 감싸고 재시도한다. 불러오기에 실패한 플레이어의 데이터는 **덮어쓰지 않는다**(빈 값으로 저장하면 진행이 사라진다).
- 퇴장(`PlayerRemoving`)과 서버 종료(`game:BindToClose`) 때 저장한다.
- Studio 테스트용 데이터와 실제 데이터를 구분할 필요가 생기면 사용자와 상의한다.
- 기존 저장 데이터를 지우거나 형식을 바꾸는 코드는 사용자 승인 없이 실행하지 않는다.

### 재사용과 변경 범위 확인
- 새 기능은 **기존 스크립트를 재사용·확장**한다. 같은 일을 하는 스크립트를 새로 만들지 않는다.
- 수정 전에 영향 범위를 확인한다. 예: `leaderstats.Stage`는 Leaderstats, Checkpoints, Respawn, Finish가 함께 쓴다. 체크포인트 이름은 Checkpoints, Respawn, Finish가 쓴다.
  - Studio에서는 `script_grep` 또는 `script_search`(Studio MCP)로 이름을 검색해 의존 스크립트를 찾는다.

### 게임 디자인 규칙
- 점프 구간은 PC와 **모바일 모두** 기본 캐릭터 점프로 깰 수 있어야 한다.
  - 기본값은 JumpHeight 7.2, WalkSpeed 16이고, 평지 최대 점프 거리는 약 8.7스터드다.
- 난이도는 스테이지가 올라갈수록 조금씩 높인다.
  - 현재 발판 간격은 3에서 6스터드, 높이차는 0에서 1.75스터드다.
  - 갑자기 어려워지는 구간을 만들지 않는다.
  - 새 장애물은 처음에 쉽게 소개하고 다음 스테이지에서 강화한다.
- 떨어지면 마지막으로 밟은 체크포인트에서 리스폰된다.
- 리더보드(leaderstats)에 현재 스테이지를 표시한다.
- 특정 인기 게임의 캐릭터, 맵, 이름을 따라 하지 않는다. 오리지널 설정만 쓴다.

## 6. 개발 및 테스트 방법

### Studio 작업 (Studio MCP 사용 가능할 때)
1. **수정 전**에 현재 구조를 먼저 확인한다 (Workspace, ServerScriptService 등).
2. **Studio가 Play 모드면** 편집할 수 없다. 사용자가 플레이 중일 수 있으니, 멈출 때는 그 사실을 알린다.
   - Play 중에 바꾼 내용은 멈추면 사라진다.
3. **Edit 모드에서 수정한다.** 스크립트나 객체를 바꿀 때는 `ChangeHistoryService` 기록으로 감싸서 사용자가 Ctrl+Z로 되돌릴 수 있게 한다.
4. **수정 후 플레이테스트**를 하고 출력 로그의 에러·경고를 확인한다.
5. 사용자에게 **Studio 저장(Ctrl+S)** 을 안내한다. 이 place는 클라우드 저장이고, AI는 저장하지 않는다.

### 회귀 테스트 체크리스트
서버 쪽에서 캐릭터를 `PivotTo`로 옮기는 자동 테스트다. 기능을 바꾼 뒤에는 관련 항목을 다시 확인한다.

1. 입장 시 `leaderstats.Stage = 0`
2. 체크포인트 1 → 2 순서대로 밟으면 Stage가 1, 2가 된다
3. 건너뛰기 방지: 2에서 5를 밟아도 2 유지
4. 뒤로 가기 방지: 2에서 1을 밟아도 2 유지
5. KillPart에 닿으면 사망
6. 마지막 체크포인트 위에서 리스폰 (수평 거리 1 미만)
7. KillZone 낙사
8. Mover 발판의 X 좌표가 변한다
9. Spinner 막대 각도가 변한다
10. TimedDoor 두 문의 `CanCollide`가 서로 반대다
11. 1~11을 순서대로 밟으면 Stage 11, 클라이언트 `PlayerGui.EscapeMessage`가 생긴다 (4초 안에 확인)
12. 출력 로그에 에러·경고 없음

**한계:** 자동 테스트는 캐릭터를 순간이동시키므로 **실제 점프 감각이나 모바일 조작은 검증하지 못한다.** 이것은 사용자가 직접 플레이해서 확인한다.

### 스크립트 내보내기 (Studio → `src/`)
- Studio의 각 스크립트 `Source`를 `src/<Studio 경로>.<종류>.luau`에 그대로 저장한다.
- 내보낸 뒤 **바이트 크기를 Studio의 `#Source`와 비교**해서 일치하는지 확인한다.
- 내용까지 비교하려면 같은 체크섬을 양쪽에서 계산한다: `h = (h * 31 + byte) % 1000000007`을 모든 바이트에 적용.
  - Studio: `string.byte(source, i)`로 계산. 로컬: Python으로 파일을 바이너리로 읽어 계산.
- 줄바꿈은 LF다 (`.gitattributes`). Studio에 Windows 기본값인 CRLF로 다시 붙여넣지 않는다.

### Studio MCP를 쓸 수 없을 때 (예: Codex에 Studio 연결이 없을 때)
- **Studio 상태를 추측해서 작업하지 않는다.** 사용자에게 Studio와 MCP 연결을 확인해 달라고 한다.
- 꼭 진행해야 하면 `src/`만 수정한다. 그리고 `HANDOFF.md`의 "Studio 미반영 변경"에 파일과 내용을 적는다.
- 사용자에게 그 스크립트를 Studio에 붙여넣어야 한다고 알린다.
- **Studio에 반영되고 플레이테스트하기 전에는 "완료"라고 기록하지 않는다.**

## 7. 기존 기능과 데이터 보호 주의사항

- **삭제·대규모 재작성 금지.** 객체·스크립트 삭제, 구조 변경, 새 시스템 추가 전에는 계획을 보여주고 사용자 승인을 받는다.
  - 기존 스크립트는 통째로 다시 쓰지 말고 필요한 부분만 고친다.
- **백업은 사용자 승인 없이 지우지 않는다:** `ServerStorage/ObbyServer_backup`, `ServerStorage/StagesBackup`.
- **체크포인트 이름(`1`~`11`)과 `IsFinish` 속성, `leaderstats.Stage` 이름은 바꾸지 않는다.** 여러 스크립트가 여기에 의존한다.
- **2단계에서 DataStore를 넣은 뒤**에는 키 이름이나 데이터 형식을 바꾸지 않는다. 바꾸면 플레이어 진행이 사라진다. 바꿔야 하면 마이그레이션 계획을 먼저 승인받는다.
- **Studio와 `src/`가 어긋나지 않게 한다.** Studio 스크립트를 바꿨으면 같은 작업 안에서 `src/`도 갱신한다.
- **민감 정보는 커밋하지 않는다.** 저장소가 **공개**이므로 다음은 절대 커밋하지 않는다: `.env`, API 키, GitHub 토큰, Roblox 쿠키(.ROBLOSECURITY), Open Cloud API 키, 비밀번호.
  - 이런 값은 코드에도 적지 않는다.
- **파괴적 Git 명령 금지 (사용자 승인 없이):** `git reset --hard`, `git push --force`, `git clean -fd`, `git checkout -- .`, `git rebase`, 브랜치 삭제, 저장소 재초기화.
- Toolbox 모델이나 외부 에셋을 넣을 때는 스크립트가 포함되어 있지 않은지 확인한다.

## 8. 모든 AI 공통 규칙 (인수인계 프로토콜)

### 핵심 협업 규칙 10가지
1. 작업 시작 전에 `AGENTS.md`와 `HANDOFF.md`를 읽는다.
2. Roblox Studio MCP로 **실제 게임 상태**를 확인한다. 문서만 믿지 않는다.
3. **Place ID를 확인한 뒤 올바른 게임만 수정한다.** `list_roblox_studios` 결과에서 placeId `77293997616106`("마이오비")인 인스턴스만 수정한다. 다른 place가 열려 있으면 건드리지 않는다.
4. 이전 AI가 구현한 기능을 무작정 재작성하지 않는다.
5. 기존 기능을 유지하면서 점진적으로 개발한다.
6. 새 기능을 구현하면 가능한 범위에서 테스트한다 (§6 회귀 테스트).
7. 주요 개발 단계가 끝날 때마다 `HANDOFF.md`를 갱신한다.
8. 테스트하지 않은 기능은 검증 완료라고 기록하지 않는다.
9. 사용자 승인 없이 게임을 초기화하거나 **외부에 공개하지 않는다.** Publish(게임 공개 배포), 공개 설정 변경, 상품 가격 등록은 사용자가 직접 하거나 명시적으로 승인한 경우에만 한다.
10. AI를 전환할 때는 진행 중인 작업, 중단 위치, 주의사항을 `HANDOFF.md`에 상세히 적는다.

### 작업 시작 시
1. `AGENTS.md`(이 파일)와 `HANDOFF.md`를 읽는다. 최근 기록이 필요하면 `NOTES.md`와 `git log`도 본다.
2. `git status`, `git log --oneline -10`으로 커밋되지 않은 변경과 최근 이력을 확인한다.
   - 커밋되지 않은 변경이 있으면 **덮어쓰지 말고** 사용자에게 먼저 알린다.
3. Studio 연결이 되면 `list_roblox_studios`로 인스턴스 ID와 placeId를 확인하고, 실제 구조와 `src/`가 HANDOFF 내용과 맞는지 확인한다.
4. **이전 AI의 작업에서 오류나 기록과 다른 점을 발견하면, 이어서 작업하기 전에 먼저 사용자에게 보고한다.**

### 작업 중
- 기존 코드와 현재 진행 상황을 확인한 뒤 작업한다.
- 기존 코드를 무분별하게 재작성하거나 삭제하지 않는다.
- 사용자 승인 없이 프로젝트 전체를 초기화하거나 파괴적인 Git 명령을 쓰지 않는다.

### 작업 완료 또는 AI 전환 시
1. Studio를 바꿨다면 `src/`로 내보내고 크기를 비교한다.
2. `HANDOFF.md`를 **현재 상태로 덮어 갱신**한다. 이력은 `NOTES.md`에 남기고, HANDOFF는 최신 상태만 담는다.
3. `NOTES.md`에 날짜와 변경 내용을 한두 줄 추가한다.
4. 필요하면 `README.md`를 갱신한다 (기능 표, 로드맵 체크박스).
5. 커밋하고 푸시한다 (§9).
6. 사용자에게 무엇을 바꿨는지, Studio에서 무엇을 확인할지 요약한다.

### 기록의 정직성
- **구현하지 않은 기능을 완료했다고 기록하지 않는다.**
- **테스트하지 않은 기능을 정상 작동한다고 단정하지 않는다.** "자동 테스트 통과", "사용자 직접 확인", "미검증"을 구분해서 적는다.
- 사용량이 다 떨어져 작업이 중간에 끊기는 경우도 있다. 그러니 큰 단계마다 HANDOFF를 갱신해 둔다.

### 소통 규칙
- 모든 답변과 코드 주석은 **한국어**로 쓴다.
- 사용자는 로블록스 개발 초보자다. 용어가 나오면 짧게 풀어서 설명한다.
- 큰 변경(새 시스템, 구조 변경, 객체 삭제) 전에는 계획을 먼저 보여주고 확인을 받는다.
- 작업이 끝나면 바꾼 내용과 사용자가 Studio에서 확인할 것을 요약한다.

## 9. Git 규칙

- 브랜치: `main` 하나를 쓴다. 큰 실험이 필요하면 사용자와 상의해서 브랜치를 만든다.
- **커밋 메시지:** 한국어로 쓰고, 앞에 작업한 AI를 표시한다.
  - 예: `[Claude] Hazards: 레이저 깜빡임 추가`, `[Codex] DataStore 진행 저장 1차 구현`
  - 본문에는 무엇을, 왜 바꿨는지 적는다.
- 큰 작업 단위가 끝날 때마다 커밋하고 `git push`한다. 원격 저장소는 공개라 푸시하면 바로 공개된다.
- 커밋 전에 `git status`와 `git diff --stat`으로 의도한 파일만 들어가는지 확인한다.
- 사용자의 커밋되지 않은 작업을 덮어쓰거나 되돌리지 않는다.
