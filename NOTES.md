# 작업 기록

## 2026-11-16
- 기존 10스테이지 그레이박스를 CLAUDE.md 구조로 정리했다. 바뀐 위치는 `Workspace/Stages/Stage01~10`(Model), `Workspace/Checkpoints/1~10`, `Workspace/KillZone`이다. 10스테이지 발판은 3×3에서 4×4로 키웠다.
- `ObbyServer` 스크립트를 `Leaderstats`·`Checkpoints`·`Respawn` 3개(`--!strict`)로 나눴다. 체크포인트는 바로 다음 번호만 인정한다. 원본은 꺼서 `ServerStorage/ObbyServer_backup`에 백업했다. 플레이테스트에서 체크포인트·리스폰·리더보드가 정상 동작했고 에러는 없었다.
- 10스테이지 발판 간격을 5.1에서 6.0~6.1스터드로 다시 넓혔다(9스테이지는 5.7). 체크포인트 10은 Z=524에서 530으로 옮겼다. 플레이테스트에서 Stage 10 도달과 리스폰을 확인했다.
- 테마를 "실험실 탈출"로 정했다. 스테이지 4–10을 장애물 구간으로 다시 만들었다: 레이저 4–5, 회전 막대 6, 움직이는 발판 7–8, 시간제 보안문 9, 종합 10. 이전 스테이지는 `ServerStorage/StagesBackup`에 있다. 골인은 `Checkpoints/11`(EXIT)이다.
- 스크립트를 추가했다: `Hazards`(태그 KillPart·Spinner·Mover·TimedDoor), `Finish`, `Remotes/Escaped`, `StarterPlayerScripts/EscapeMessage`. 플레이테스트에서 장애물 동작, 레이저 사망, 발판 탑승, Stage 11 골인, "탈출 성공!" 표시를 확인했고 에러는 없었다.
- 직접 플레이해 보고 난이도가 적당하다고 확인했다. 스크립트를 `src/`로 내보내고 README를 썼다. git과 GitHub CLI로 공개 저장소 연동을 시작했다.
- README에 구간별 그레이박스 스크린샷 5장을 넣었다(`docs/screenshots/`). 체크포인트 10에 이전 라벨 "FINISH"가 남아 있어 "10"으로 고쳤다.
- Claude Code와 Codex가 번갈아 작업할 수 있도록 인수인계 체계를 만들었다. 공통 규칙은 `AGENTS.md`로 모으고 `CLAUDE.md`는 Claude 전용 설정만 남겼다. 현재 상태는 `HANDOFF.md`에 적었다. 회귀 테스트 11개 항목은 통과했다(클라이언트 메시지 표시는 미확인).
- 인수인계 문서를 보강했다. Studio 실측으로 Universe ID(10777081510)와 전체 구조를 기록하고, 스크립트 6개가 `src/`와 바이트 단위로 같은 것(체크섬)을 확인했다. 재테스트에서 클라이언트 "탈출 성공!" 표시를 확인했다. HANDOFF.md를 A–H 구성으로 다시 쓰고, AGENTS.md에 협업 규칙 10가지·Remote 보안·DataStore 안전 원칙을 추가했다. 게임(Studio) 내용은 바꾸지 않았다.
- Codex에서 Studio MCP 연결, Place ID, 스크립트 6개 일치 여부를 확인했다. 그레이박스 회귀 테스트를 통과하고 Edit 모드로 복귀했다. 진행 저장 설계를 HANDOFF.md에 기록했으며 구현은 사용자 승인 대기 중이다.
- 진행 저장(2단계 첫 작업)을 구현했다. Codex 설계안을 사용자가 승인했다. `ProgressSave` 모듈(DataStore `Progress_v1`, 키 `Player_<UserId>`, `{ Stage }`)을 추가하고 `Leaderstats`가 불러오게 했다. `Respawn`·`Finish`는 leaderstats 대기를 30초로 늘렸다. 가짜 저장소 테스트 13개와 기존 회귀 테스트를 통과했다. Studio API 접근이 꺼져 있어 실제 재접속 테스트는 아직이다.
- 진행 저장 실제 테스트를 3번 시도했지만 Studio API 접근이 계속 거부되어 하지 못했다(Studio 재시작 후도 동일, 쓰기 없음). Studio 재시작 후에도 진행 저장 코드가 남아 있어 클라우드 저장은 된 것으로 본다. Studio 상태(스크립트 7개 체크섬 일치)를 다시 확인하고 HANDOFF를 갱신했다.
- Codex가 Studio에서 Place ID와 스크립트 7개를 대조하고, 읽기 전용 검사에서 기존 API 접근 오류를 재확인했다. 점프가 필요 없는 ‘꼬마 로봇 연구소’ 시안과 첫 구현 범위를 HANDOFF에 기록했다.
- 꼬마 로봇 연구소를 Studio에 추가했다. 로봇 3종 발견·수리·도감, 부품으로 사는 상품 2종, 오비 왕복을 테스트했다. 기존 오비 회귀 테스트를 통과했고 연구소 재접속 저장과 모바일 조작은 후속 검증으로 남겼다.
- Claude Code로 전환하기 전 Studio Edit에서 연구소 상호작용 9개, 오비와 백업, 스크립트 9개 일치를 확인하고 HANDOFF를 갱신했다. 연구소 변경의 클라우드 저장 여부는 미확인이다.

## 2026-11-17
- 사용자가 점프맵 대신 오래 접속할 수 있는 주제를 원해, Codex의 "꼬마 로봇 연구소"를 장시간 플레이용 "로봇 작업장"으로 확장했다(1단계). 부품 줍기 → 실시간 수리 → 도우미 수입 → 업그레이드·구역 열기 루프, 로봇 12종·4등급, 업그레이드 4종, 폐품 처리장 추가. 설정은 `RobotLabConfig` 모듈로 분리했고 v1은 `ServerStorage/RobotLabV1Backup`에 백업했다. Play 자동 테스트와 오비 회귀를 통과했다. 저장은 다음 단계다.
- 로봇 작업장 2단계: 저장(`RobotLabSave`, DataStore `RobotLab_v1`, 세션 잠금)과 오프라인 수입(보관함 상한 4시간)을 추가했다. 가짜 저장소 테스트 16개와 실제 흐름(저장 접근 거부 시 "저장 안 됨" 표시), 오비 회귀를 통과했다. 실제 DataStore 재접속은 Studio API 접근 문제로 아직이다.
