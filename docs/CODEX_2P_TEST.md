# Codex 지시서: 로봇 고물상 타이쿤 2인 테스트 (2026-11-19 Claude Code 작성)

> **이 문서는 "로봇 고물상 타이쿤"(폴더 `C:\RobloxProjects\MyObby`, placeId `77293997616106`) 전용이다.**
> 지금 Codex가 함께 만들고 있는 **새 게임(문방구 캐릭터 시험장, `new-game-prototype/`, `docs/NEW_GAME_DESIGN.md`)과는 관계없다.**
> 이 테스트 중에는 새 게임 파일을 열거나 고치거나 커밋하지 않는다. 새 게임 Studio 창이 열려 있으면 그 창에는 명령을 보내지 않는다.

## 0. 지킬 것
- `AGENTS.md`와 `HANDOFF.md`(특히 H표, B-28~B-48)를 먼저 읽는다.
- **사용자 본인 저장 데이터를 쓰지 않는다.** 2인 테스트는 Studio "클라이언트 및 서버" 로컬 테스트의 **음수 UserId 계정(-1, -2)**으로만 한다. 이 계정들의 저장(`Junkyard_v1`의 `Player_-1`·`Player_-2`)에는 시험 값이 남아도 된다.
- 게시(Publish)·저장(`save_place`)·공개 설정은 하지 않는다. 저장은 사용자가 Ctrl+S로 한다.
- 버그를 찾으면 작고 확실한 것만 고친다. 고칠 때는 Studio 수정 → `src/` 내보내기 → 크기·체크섬 대조(AGENTS §6). 크거나 애매하면 고치지 말고 기록한 뒤 사용자에게 보고한다.
- 커밋은 **바꾼 파일만** `git add <경로>`로 한다. `git add -A`나 `git add .`는 쓰지 않는다. `new-game-prototype/`와 `docs/NEW_GAME_DESIGN.md`가 함께 들어가지 않게 한다. 커밋 메시지는 `[Codex] `로 시작한다.

## 1. 시작 확인
1. `git status --short`, `git log --oneline -5`. 고물상 파일(`src/`, `HANDOFF.md` 등)에 커밋 안 된 변경이 있으면 멈추고 사용자에게 알린다. `new-game-prototype/`·`docs/NEW_GAME_DESIGN.md` 변경은 새 게임 작업이므로 그대로 둔다.
2. `list_roblox_studios`에서 **placeId `77293997616106`인 창만** 쓴다.
3. Edit 상태에서 스크립트 12개의 크기·체크섬(`h = (h*31 + byte) % 1000000007`)이 아래와 같은지 확인한다. 다르면 작업하지 말고 보고한다.

| Studio 경로 | 바이트 | 체크섬 |
|---|---|---|
| ReplicatedStorage.Modules.JunkyardConfig | 33152 | 326552697 |
| ReplicatedStorage.Modules.JunkyardRobotModel | 31723 | 315473285 |
| ServerScriptService.Junkyard | 100307 | 42420377 |
| ServerScriptService.JunkyardBelt | 7083 | 740310580 |
| ServerScriptService.JunkyardEvents | 1733 | 471819683 |
| ServerScriptService.JunkyardSave | 17403 | 803073679 |
| ServerScriptService.JunkyardStore | 4904 | 256970632 |
| ServerScriptService.JunkyardRanking | 12574 | 72233971 |
| ServerScriptService.JunkyardContest | 6644 | 622978211 |
| ServerScriptService.JunkyardCCTV | 10127 | 499888406 |
| ServerScriptService.JunkyardGiantRobot | 9911 | 457266346 |
| StarterPlayer.StarterPlayerScripts.JunkyardHud | 86058 | 940999470 |

## 2. 2인 테스트 시작 (사용자가 누른다)
- 사용자에게 부탁한다: **Studio 테스트 탭 → "클라이언트 및 서버" → 플레이어 수 2 → 시작.** MCP 도구로는 이 화면을 시작할 수 없다.
- 시작되면 `list_roblox_studios`에 서버 창과 플레이어 창 2개가 보인다. 판정 확인은 **서버 창**의 `execute_luau`(Server)로, 클라이언트 쪽 행동(Remote 보내기, 버튼 누르기)은 **각 플레이어 창**(Client)으로 한다.
- 두 사람 모두 `Mode = "Junkyard"`, 기지 배정, `Loading = false`가 될 때까지 기다린다.

### Studio 전용 시험 장치 (서버에서 `workspace` 속성으로 켠다, 대상은 `DebugMoneyUserId`)
- `DebugMoneyUserId = -1` 또는 `-2`로 대상을 먼저 정한다.
- `DebugGiveMoney = 숫자`(한 번에 1,000,000 이하), `DebugSetRebirth = 0~20`(음수 계정만), `DebugGiveRobot = "Pippi"` 또는 `"Nova@Gold"`(음수 계정만, 빈 받침대에 놓음), `DebugGivePass = "BatGrowth"` 등(게임패스 효과), `DebugGrantProduct = "EmpPack"` 등, `DebugSetTutorial = 0`(안내 끄기).
- 대회: `DebugContestDuration = 20` 다음에 `DebugContestNow = "Income"` 또는 `"Collect"`.
- 거대 로봇: `DebugGiantProgress = 0~1`, `DebugGiantSkip = 초`.

### 행동 보내는 방법
- Remote: 클라이언트에서 `ReplicatedStorage.Remotes.JunkyardAction:FireServer(행동, 값)`. 행동 이름은 `Buy`(벨트 항목 id), `Lock`(방어막), `Item`("EMP"/"Gloves"), `Bat`(true = 방망이, false = 장갑), `BatLevel`, `BatSkin`, `Donate`(버튼 번호), `Title`, `Upgrade`, `Expand`, `Swap` 등.
- 길게 누르는 버튼(훔치기·빼앗기)은 서버가 실제로 누른 시간을 검사한다. 클라이언트에서 그 버튼의 `ProximityPrompt:InputHoldBegin()` → 기다림 → `InputHoldEnd()`로 누른다. 거리는 서버에서 캐릭터를 `PivotTo`로 옮겨 맞춘다.
- 알림은 클라이언트에서 `Remotes.JunkyardNotify.OnClientEvent`를 잠시 연결해 받아 본다.

### 미리 맞출 상태 (중요)
- 새싹 보호: 환생 0번이고 누적 수입 50,000 미만이면 훔치기·빼앗기·EMP를 **당하지 않는다.** 훔치기를 시험할 때는 두 계정 모두 `DebugSetRebirth = 1`로 맞춘다. 환생 차이가 1 이상이면 높은 쪽이 낮은 쪽 것을 못 훔친다(`ProtectionGap = 1`).
- 장갑/방망이: 로봇 가져가기(벨트 구매·받침대 훔치기·빼앗기)는 **장갑(`BatOut = false`)**일 때만, 되찾기는 **방망이(`BatOut = true`)**일 때만 된다(B-43).

## 3. 확인할 항목 (결과를 "통과 / 실패 / 확인 못 함"으로 적는다)

| # | 항목 | 하는 방법 | 기대 결과 |
|---|---|---|---|
| 1 | 벨트 같은 로봇 동시 구매 | 두 사람을 같은 벨트 로봇 가까이 두고 거의 동시에 `Buy` | 한 명만 들고 감, 다른 사람은 "먼저 샀어요" 알림. 돈은 산 사람만 줄어듦 |
| 2 | 방망이 든 채로 가져가기 막힘 | P2 `Bat true` 후 구매·훔치기·빼앗기 시도 | 셋 다 거절 + "🧤 장갑을 껴야…" 알림 |
| 3 | 받침대 훔치기 | 둘 다 환생 1, P2 장갑으로 P1 받침대 로봇 1.5초 누르기 | P2가 로봇을 들고 `CarryStolen = true`, P1에게 "⚠" 도둑 알림과 화면 가운데 큰 안내 |
| 4 | 방망이로 되찾기 | 3번 상태에서 P1 `Bat true`, P2가 든 로봇 버튼 한 번 누르기 | 로봇이 P1 받침대로 돌아감, P1 `BatXp` +1. 장갑 상태로 누르면 거절 알림 |
| 5 | 경험치 주고받기 방지 | 같은 도둑에게서 20초 안에 다시 되찾기 | 두 번째는 경험치 안 오름 |
| 6 | 단계별 되찾기 효과 | P1에게 돈을 주고 `BatLevel` 여러 번(네온 4단계까지) → 되찾기 | 되찾을 때 도둑 `StunnedUntil`이 1초 뒤, 걷기 속도 0 → 1초 뒤 원래대로. 되찾기 거리 늘어남 |
| 7 | 벨트에서 산 로봇 빼앗기 | P1이 벨트 로봇을 사서 기지 밖에서 들고 있음 → P2가 길게 눌러 빼앗기 | P2가 가져감. 3초 보호 동안 다시 못 뺏음. P1이 방망이로 되찾기 가능. 자기 기지 안에 있는 사람 것은 못 뺏음 |
| 8 | 변종 제한 | P2 환생 0, P1 받침대에 `"Nova@Gold"` → P2가 훔치기 | 거절("환생 1번 이상만") |
| 9 | 새싹 보호 | P1 환생 0·누적 수입 적음 → P2 훔치기·빼앗기·EMP | 모두 거절 |
| 10 | EMP | P1 방어막 켬(`Lock`), P2가 40스터드 안에서 `Item "EMP"` | P1 방어막 남은 시간이 절반. 멀리서는 거절 |
| 11 | 서버 대회 | 대회 20초로 수입왕·수집왕 각각 | 점수판 표시, 끝나면 보상·칭호 지급, 처음 얻은 칭호만 영구 +1%, 같은 칭호 중복 없음 |
| 12 | 기부·정비왕 | 거대 로봇 앞에서 두 사람이 `Donate`, 마지막 기부로 완성 | 다른 사람 화면에도 큰 기부 알림, 마지막 기부자에게만 영구 "정비왕" |
| 13 | 다른 사람 화면에서 보이는 모습 | P1이 방망이·장갑·꾸미기를 바꿈 → P2 클라이언트에서 P1 캐릭터 확인 | P2에게도 `JunkyardBat`/`JunkyardGlove`가 보임, 새 로봇 모형(B-45)·변종 보석(B-47)이 P2 화면에서도 정상 |
| 14 | 재접속 복원 | P1 확장·방망이 단계·칭호를 바꾼 뒤 P1만 나갔다 다시 들어오기 | 확장 단계, 방망이 단계·경험치, 칭호가 그대로 |
| 15 | 출력 창 | 전체 테스트 동안 | 서버·두 클라이언트 모두 오류·경고 없음 |

**한계:** 이 시험은 캐릭터를 순간이동시키고 버튼을 코드로 누르는 방식이다. 실제 손 조작감과 휴대폰 화면은 확인하지 못한다. 사용자 직접 확인 항목으로 따로 적는다.

## 4. 끝나면
1. Play(테스트)를 멈춘다.
2. `HANDOFF.md`에 **B-49 2인 테스트 결과** 절을 새로 만든다. 위 표의 결과를 "자동 테스트 통과 / 실패(무엇이) / 확인 못 함"으로 구분해 적는다. 고친 것이 있으면 무엇을 왜 고쳤는지, 바뀐 스크립트 크기·체크섬도 적는다. H표(마지막 작업 AI, 마지막 게임 수정)를 갱신한다. G-3의 2인 항목 중 확인한 것은 지운다.
3. `NOTES.md`에 날짜와 한두 줄을 덧붙인다.
4. `git status --short`로 확인한 뒤 바꾼 파일만 `git add HANDOFF.md NOTES.md` (+ 고친 `src/` 파일)로 올리고, `[Codex] 고물상 2인 테스트 결과` 같은 메시지로 커밋·푸시한다.
5. 사용자에게 한국어로 결과 표, 고친 것, 사용자가 직접 확인할 것(실제 조작감·휴대폰), Studio Ctrl+S 안내를 짧게 알린다.
