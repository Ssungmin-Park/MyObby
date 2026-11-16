# HANDOFF.md — 인수인계 문서

> 이 문서는 **현재 상태 스냅샷**이다. 작업을 마치거나 AI를 전환할 때 **최신 상태로 덮어 갱신**한다.
> 지난 이력은 `NOTES.md`와 `git log`에 있다. 규칙은 `AGENTS.md`를 따른다.
> 모든 항목은 실제 파일, Git, Studio를 확인한 결과로 적는다. 추측은 "미확인"이라고 표시한다.

---

## 0. 기본 정보

| 항목 | 내용 |
|---|---|
| 마지막 작업 AI | **Claude Code** (모델: Claude Opus 5.5) |
| 마지막 갱신 | 2026-11-16 |
| 마지막 커밋 | 이 문서를 추가한 커밋 (`git log -1`로 확인). 그 전 커밋: `e4a1a8b` |
| Git 상태 | `main`, 원격 `origin/main`과 동기화하도록 푸시함. 작업 시작 시 `git status`로 다시 확인할 것 |
| Studio 상태 | Edit 모드, place "마이오비" (placeId 77293997616106) |

## 1. 현재 개발 단계

**1단계 그레이박스 — 사실상 완료.** 2단계(시스템)는 아직 시작하지 않았다.

- 사용자가 직접 플레이해 보고 "난이도는 적당하다"고 확인했다 (2026-11-16). 플레이한 기기(PC/모바일)는 기록되지 않았다.
- 테마는 "실험실 탈출"로 확정했다.

## 2. 완료된 기능 (2026-11-16 Studio에서 확인)

| 기능 | 위치 | 검증 |
|---|---|---|
| 스테이지 10개 + EXIT (Checkpoints 1~11) | `Workspace/Stages`, `Workspace/Checkpoints` | 자동 테스트 통과 |
| 리더보드 Stage (0 = 시작, 11 = 탈출) | `ServerScriptService/Leaderstats` | 자동 테스트 통과 |
| 체크포인트 진행 (다음 번호만 인정, 건너뛰기·뒤로 가기 방지) | `ServerScriptService/Checkpoints` | 자동 테스트 통과 |
| 낙사·사망 시 마지막 체크포인트에서 리스폰 (1초) | `ServerScriptService/Respawn` | 자동 테스트 통과 |
| 레이저 KillPart 8개 (Stage 4, 5, 7, 9의 레이저 + 회전 막대 2개) | `ServerScriptService/Hazards` | 자동 테스트 통과 |
| 회전 레이저 Spinner 2개 (Stage 6: 40°/s, Stage 10: 55°/s) | 〃 | 자동 테스트 통과 |
| 움직이는 발판 Mover 4개 (Stage 7, 8×2, 10 / ±6스터드) | 〃 | 자동 테스트 통과 + 발판 탑승 확인 |
| 시간제 보안문 TimedDoor 2개 (Stage 9 / 3초 교대) | 〃 | 자동 테스트 통과 |
| 골인 → Stage 11 + `Remotes.Escaped` 발송 | `ServerScriptService/Finish` | 자동 테스트 통과 (서버 로그 확인) |
| "탈출 성공!" 화면 메시지 (4초) | `StarterPlayerScripts/EscapeMessage` | 이전 테스트에서 표시 확인. 최신 테스트에서는 미확인 (§6 참고) |
| GitHub 공개 저장소 + README + 스크린샷 | 이 저장소 | 푸시 완료 |
| AI 인수인계 체계 (AGENTS.md / HANDOFF.md / CLAUDE.md 정리) | 이 저장소 | 이번 작업 |

**Studio와 `src/` 일치 여부:** 6개 스크립트 모두 Studio의 `#Source`와 파일 바이트 크기가 같다 (2026-11-16 확인).

| 스크립트 | 크기 |
|---|---|
| Leaderstats | 792 B |
| Respawn | 2019 B |
| Checkpoints | 1756 B |
| Finish | 1423 B |
| Hazards | 4036 B |
| EscapeMessage | 908 B |

## 3. 진행 중인 작업과 완료 정도

- **진행 중인 기능 개발: 없음.** 이번 작업은 인수인계 체계 구축(문서와 Git 규칙)이었고, 완료했다.
- 다음 큰 작업(2단계 시스템)은 아직 계획도 승인받지 않았다.

## 4. 마지막으로 수정한 파일과 내용

이번 작업 (Claude Code, 2026-11-16):

| 파일 | 변경 |
|---|---|
| `AGENTS.md` (신규) | 공통 개발 지침. 기존 `CLAUDE.md`의 규칙을 모두 옮기고 인수인계 프로토콜, Git 규칙, 테스트 체크리스트, 보호 주의사항을 추가 |
| `CLAUDE.md` | 공통 규칙을 빼고 `@AGENTS.md` 불러오기와 Claude 전용 설정(Studio MCP 사용법, gh 경로)만 남김 |
| `HANDOFF.md` (신규) | 이 문서 |
| `.gitignore` | 민감 파일 패턴 추가 (`.env.*`, `*.pem`, `*.key`, `*credentials*`, `*secret*`, `*.cookie`, `.codex/`, `.vscode/`) |
| `NOTES.md` | 인수인계 체계 구축 기록 한 줄 추가 |

직전 작업:
- **Studio:** 체크포인트 10의 SurfaceGui 라벨을 "FINISH"에서 "10"으로 바꿨다.
- **저장소:** `README.md`에 스크린샷을 넣었다 (커밋 `e4a1a8b`).

## 5. 결정된 설계와 이유

| 결정 | 이유 |
|---|---|
| 테마는 "실험실 탈출" | 시장 분석 결과, 일반 오비는 포화 상태여서 테마·이야기형으로 차별화. 레이저/화물/보안문 장애물이 테마와 자연스럽게 맞음 |
| 체크포인트는 "바로 다음 번호만" 인정 | 순간이동 핵으로 건너뛰는 것을 서버에서 차단. 코스가 일직선이라 정상 플레이에는 영향 없음 |
| 골인을 `Checkpoints/11` + `IsFinish` 속성으로 구현 | 별도 `Workspace/Finish` 대신 기존 체크포인트·리스폰 로직을 그대로 재사용. 리더보드 11 = 탈출 |
| 장애물은 CollectionService 태그 + Attribute | 스크립트 수정 없이 레벨 디자인 반복 가능. 사용자(초보)도 태그만 붙여 장애물 추가 가능 |
| 움직이는 발판·회전 막대는 Constraint(물리) + 서버 네트워크 소유 | CFrame 트윈은 캐릭터를 태우지 못하고 Touched가 불안정함. 서버 소유로 모든 플레이어에게 같은 위치 |
| 보안문은 서버 시간(`GetServerTimeNow`) 하나의 시계 | 문끼리 박자가 정확히 맞고 클라이언트 간 차이 없음 |
| 레이저는 색 없이 `Transparency 0.4` | 1단계 규칙(색·재질 금지)을 지키면서 위험 요소를 구분 가능하게 |
| Stage 10 간격 6.0~6.1스터드 | 발판을 4×4로 키운 뒤 간격이 5.1로 줄어 Stage 9(5.7)보다 쉬워진 것을 바로잡음 |
| 원본은 Studio, `src/`는 거울 (Rojo 미사용) | 초보 사용자 환경 단순화. 대신 수동 내보내기와 크기 비교로 동기화 |
| GitHub 연동은 git + gh (플러그인 커넥터 미사용) | 커넥터는 토큰 환경 변수가 필요. gh는 브라우저 로그인만으로 동작 |
| 공개 저장소 | 사용자의 포트폴리오 목적 |
| 수익화 방향 (아직 미구현) | 스테이지 스킵 Developer Product(뒤로 갈수록 비싸게) + 꾸미기 게임패스 + 보상형 광고. 공정성을 깨는 pay-to-win은 피함 |

## 6. 발견된 버그와 미해결 문제

| # | 내용 | 상태 |
|---|---|---|
| 1 | **Studio 저장 여부 미확인.** 체크포인트 10 라벨 수정 등 최근 Studio 변경이 클라우드에 저장(Ctrl+S)됐는지 AI가 확인할 방법이 없음 | 사용자 확인 필요 |
| 2 | 최신 회귀 테스트에서 "탈출 성공!" 클라이언트 표시를 확인하지 못함. 서버 로그에는 "탈출 성공"이 찍힘. 클라이언트 확인 시점이 4초 표시 시간을 넘겼을 가능성이 큼. 직전 테스트(직접 FireClient)에서는 표시 확인됨 | 재확인 권장 (버그 아닐 가능성 높음) |
| 3 | 실제 모바일 기기·터치 조작으로는 테스트하지 않음. 자동 테스트는 순간이동 방식이라 점프 감각을 검증하지 못함 | 미검증 |
| 4 | 진행 저장 없음: 재접속하면 Stage가 0으로 초기화 | 2단계에서 구현 예정 (버그 아님) |
| 5 | `src/` ↔ Studio 동기화가 수동이고 크기만 비교. 크기가 같은데 내용이 다른 경우는 못 잡음 | 알려진 한계 |
| 6 | 체크포인트 1~10에 옛 속성 `Stage`(숫자)가 남아 있음. 현재 스크립트는 쓰지 않음(이름으로 판정). 무해 | 정리 선택 사항 (삭제 전 승인) |
| 7 | `ServerStorage/ObbyServer_backup`, `ServerStorage/StagesBackup` 백업이 남아 있음 | 삭제 여부는 사용자 결정 |
| 8 | Claude Code의 GitHub 플러그인 커넥터 연결 실패 (토큰 환경 변수 없음) | 의도적으로 미사용 |
| 9 | Codex 쪽에 Roblox Studio MCP가 연결되어 있는지 확인되지 않음. 연결이 없으면 Codex는 Studio를 직접 수정할 수 없음 | Codex 첫 작업 때 확인 필요 |

## 7. 마지막으로 실행한 테스트와 결과

**2026-11-16, Claude Code, Studio 플레이테스트 (서버에서 자동 회귀 테스트)**

| # | 항목 | 결과 |
|---|---|---|
| 1 | 입장 시 Stage 0 | PASS |
| 2 | 체크포인트 1 → 2 진행 | PASS |
| 3 | 건너뛰기 방지 (2에서 5 밟기 → 2 유지) | PASS |
| 4 | 뒤로 가기 방지 | PASS |
| 5 | 레이저(KillPart) 닿으면 사망 | PASS |
| 6 | 마지막 체크포인트(2)에서 리스폰, 거리 0.0 | PASS |
| 7 | KillZone 낙사 | PASS |
| 8 | Mover 이동 (X 0.8 → 6.0) | PASS |
| 9 | Spinner 회전 (−19° → 37°) | PASS |
| 10 | TimedDoor 두 문 엇갈림 | PASS |
| 11 | EXIT 도달 시 Stage 11, 서버 로그 "[Finish] … 탈출 성공" | PASS |
| — | 클라이언트 "탈출 성공!" GUI | **미확인** (§6-2) |
| — | 출력 로그 에러·경고 | 없음 |

사용자 수동 플레이: 난이도 적당 (2026-11-16, 기기 미기록).

## 8. 다음 AI가 가장 먼저 할 일

1. `AGENTS.md`와 이 문서를 읽고, `git status`와 `git log --oneline -5`로 상태를 확인한다.
2. **Studio 연결을 확인한다.** Codex라면 Roblox Studio MCP가 있는지 확인한다(§6-9).
   - 없으면 사용자에게 알리고 Studio 작업은 하지 않는다.
3. **사용자에게 Studio 저장(Ctrl+S) 여부를 확인한다** (§6-1).
4. Studio에 연결되면 `src/`와 Studio 스크립트 크기가 일치하는지 다시 확인한다.
5. **다음 기능: 2단계 시스템의 첫 작업인 "진행 저장(DataStore)"의 계획을 세워 사용자 승인을 받는다.**
   - 저장 대상: `leaderstats.Stage`
   - 입장 시 불러오기, 퇴장 시와 주기적으로 저장, 서버 종료 시(`game:BindToClose`) 저장
   - `pcall`과 재시도 처리
   - 별도 스크립트로 만든다. 예: `ServerScriptService/ProgressSave`
   - 그다음 작업 후보: 스테이지 스킵 Developer Product
6. 선택 사항: §6-2(탈출 메시지)를 다시 확인한다. 사용자가 원하면 백업(§6-7)과 옛 속성(§6-6)을 정리한다.

## 9. 다음 작업 시 주의사항

- **DataStore를 Studio에서 테스트하려면** 사용자가 Studio의 Game Settings → Security에서 "Enable Studio Access to API Services"를 켜야 한다.
  - 이 설정은 사용자가 직접 바꾸게 안내한다.
- DataStore 키 이름과 데이터 형식은 한 번 정하면 바꾸지 않는다 (AGENTS.md §7).
- 저장된 Stage를 불러올 때 `Respawn`이 첫 스폰에서 그 체크포인트로 옮기는지 확인한다.
  - 현재 `Respawn`은 `leaderstats`를 최대 5초 기다린 뒤 Stage를 읽는다. 저장값 로딩이 늦으면 시작 발판에서 출발할 수 있다.
- `Checkpoints`는 "다음 번호만" 인정한다. 저장된 Stage가 있으면 그 다음 번호부터 정상 진행되는지 확인한다.
- 스킵 상품을 만들 때 구매 처리(`MarketplaceService.ProcessReceipt`)는 서버에서만 한다. 한 번만 지급되도록 영수증을 처리한다.
- 사용자가 Studio에서 Play 중일 수 있다. 편집하려고 Play를 멈출 때는 알린다.
- 공개 저장소다. 토큰, API 키, 쿠키를 코드나 커밋에 넣지 않는다.

## 10. Studio 미반영 변경

`src/`만 고치고 아직 Studio에 반영하지 못한 변경을 여기에 적는다.

- (없음)
