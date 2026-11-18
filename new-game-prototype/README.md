# 문방구 전쟁 — 첫 연습 경기

같은 1,000원을 공격 병력과 방어 시설에 나눠 투자하고, 봇과 동시에 상대 필통 본부를 공략하는 Roblox Studio 시제품이다. 기존 쫀득·철컥 캐릭터 시험장도 유지한다.

![실제 연습 경기](screenshots/practice-combat.jpg)

기획·최신 인수인계는 [새 게임 기획서 18절](../docs/NEW_GAME_DESIGN.md), 승인 범위·시험 수치는 [첫 경기 계획](FIRST_MATCH_PLAN.md)에 있다. 기존 고물상 게임의 소스·문서는 이번 작업 대상이 아니다.

## 실행과 조작

1. **문방구 전쟁** Studio에서 Play를 누른다.
2. 화면 아래에서 균형/공격/수비 봇을 고르고 **연습 경기 시작**을 누른다.
3. 준비 중 쫀득/철컥 종류를 골라 구매하거나, 방어 슬롯을 골라 **포탑 250원**을 누른다. 준비 중 취소는 전액 환불한다.
4. **준비 완료**를 누르거나 45초가 지나면 전투가 시작된다. 양쪽 무료 쫀득·철컥 각 1명은 자동 출발한다.
5. 전투 중 종류·위/중앙/아래 구역을 고르고 **선택 병력 투입**을 누른다. **종이바람**은 버튼을 누른 뒤 전장의 적 병력이 있는 곳을 선택한다. 한 판 1회, 범위 8 안의 적 이동을 4초간 40% 느리게 한다.
6. 상대 본부 파괴 또는 최대 90초 후 피해율 비교로 종료한다. 공격 병력이 모두 소진되면 조기 종료한다. 결과에서 **다시 경기**, 또는 언제든 **시험장으로** 돌아갈 수 있다.

쫀득 100원·철컥 200원·포탑 250원이다. 포탑 4개에 전액 수비해도 기본 공격대는 무료로 출발한다. 추가 구매 병력은 자동 투입되지 않으므로 전투 중 직접 보내야 한다. 봇 역시 같은 예산·기본 병력을 사용한다.

현재 한 서버의 연습 경기 1개·참가자 1명만 지원한다. 사람 간 대결·매칭·영구 저장·보상은 후속 단계다. 실제 출시 실행은 막혀 있고 문방구 Studio에서만 동작한다.

## 작업 대상과 저장

- Place ID **123176209315432**, Universe ID **10777479934**, Studio 이름 **문방구 전쟁**.
- 마지막 조회 Studio ID `b5ca1279-b9be-4ff8-808a-60c4c8d2be53`. 매 세션 목록에서 다시 확인한다.
- Workspace 식별 속성 `PrototypeProject = "StationeryCharacterLab"`.
- 기존 고물상 Place ID `77293997616106`에서는 실행하지 않는다.
- 현재 Studio는 **Edit·기본 미리보기**다. **이번 변경은 사용자가 문방구 전쟁에서 Ctrl+S로 저장해야 한다.** AI는 save_place/Publish하지 않았다.
- 생성 원본은 `ServerStorage/CharacterLabSources`, 시험 모델은 `ReplicatedStorage/CharacterLabAssets`에 유지했다. 에셋 번호: 쫀득 `124308299115203`, 철컥 `139594764218049`.
- 수정 전 시험 스크립트는 `ServerStorage/CharacterLabScriptBackups/BeforeFirstMatch_1794988510`에 보관했다.

## 소스와 생성 도구

| 경로 | 역할 |
|---|---|
| src/ReplicatedStorage/Modules/StationeryBattleConfig.luau | 수치·가격·봇 투자안 |
| src/ServerScriptService/StationeryBattleEngine.luau | 서버 경기 계산 |
| src/ServerScriptService/StationeryBattle.server.luau | 소유권·행동 검증·서버 시간·상태 전송 |
| src/ReplicatedStorage/Modules/StationeryBattleView.luau | 캐릭터·체력·철심·둔화·효과음 표시 |
| src/StarterPlayer/StarterPlayerScripts/StationeryBattleHud.client.luau | 조작 화면·경기 카메라 |
| tools/build-practice-arena.luau | 노트 전장 34파트·리모트 구성, 반복 실행 시 기존 맵 보존 |
| tests/battle-engine.spec.luau | 실제 계산 모듈로 실행하는 회귀 검사 |
| tests/last-engine-results.json | 118개 검사·투자별 9개 표본 결과 |
| src/.../CharacterLab.*.luau | 기존 피격·발사·이동 캐릭터 시험 |
| tools/build-character-lab.luau | 기존 시험장 구성 |
| tools/prepare-generated-characters.luau | 생성 원본·시험 모델 준비 |
| tools/refine-character-faces.luau | 얼굴·팔다리 보완 |

서버는 예산·체력·이동·표적·사거리·피해·승패를 결정한다. 클라이언트는 행동 요청과 표시를 담당한다. 병력은 장애물 없는 직접 이동이며 물리로 밀거나 경로를 차단하지 않는다. 철심은 서버가 정한 도착 시점에 살아 있는 표적에만 피해를 주고, 보이는 쫀득의 크기가 서버 사거리를 바꾸지는 않는다.

Studio와 로컬은 자동 동기화되지 않는다. 아래 7개는 원문 내보내기 후 전체 내용·바이트·체크섬이 일치했다. 체크섬은 `(h * 31 + byte) % 1000000007`이다.

| Studio 스크립트 | 바이트 | 체크섬 |
|---|---|---|
| ServerScriptService.CharacterLab | 5589 | 934721775 |
| StarterPlayer.StarterPlayerScripts.CharacterLab | 15479 | 900984887 |
| ReplicatedStorage.Modules.StationeryBattleConfig | 1182 | 358159348 |
| ServerScriptService.StationeryBattleEngine | 10321 | 278988633 |
| ReplicatedStorage.Modules.StationeryBattleView | 9122 | 190982966 |
| ServerScriptService.StationeryBattle | 3383 | 79773353 |
| StarterPlayer.StarterPlayerScripts.StationeryBattleHud | 12433 | 377826956 |

## 실제 검증과 남은 일

- 서버 자동 검사 **118개 통과**. 구매/환불·비정상 요청·사거리·스킬·동시 파괴·시간 종료·병력 소진·투자 9개 조합을 확인했다.
- 실제 1인 Play에서 준비→전투→승리/무승부→재시작→시험장 복귀를 확인했다. 돈/병력 초기화·이전 판 번호 거절·복귀 시 표시 객체 정리 확인.
- PC 품질 2·1069×900, 객체 10~15개·6초 표본 **60.018 FPS**, 프레임 시간 p95 **18.063ms**. 최종 새 Play 콘솔 오류·경고 0.
- iPhone 17 Pro 가로 미리보기 750×381에서 버튼 114×44·TextFits=true, 전투 조작창 한 줄·체력 막대 표시 확인. **실제 모바일 터치 조작·세로 화면·휴대폰 실기 성능·2인 소유권 검증·장시간/최대 병력 부하는 미검증**이다.
- 9개 표본은 정식 밸런스 검증이 아니다. 사용자가 판 길이·투입 조작·캐릭터 식별성을 직접 평가한 뒤 수치를 조정한다. 전장과 본부/포탑의 미술 완성 작업도 남아 있다.

## 기존 캐릭터 시험장

| 조작 | 동작 |
|---|---|
| 쫀득 피격 / Q | 체력 20 감소·외형 축소 |
| 철컥 발사 / E | 단독 발사·놀람·반동 |
| 처음으로 / R | 체력·표시 상태 복원 |
| 자동 반복 | 피격·발사 반복 |
| 여러 마리 | 2명/17명 외형 시험 |
| 접근 시험 / Y | 사거리까지 이동·정지·발사 반복 |
| 연결 시험 / T | 정지한 두 캐릭터의 발사→도착→피격 연결 시험 |

이 시험들의 이전 검증·제약은 기획서 14~16절에 있다. 연습 경기 중에는 기존 시험 입력·카메라를 사용하지 않는다.

![준비 화면](screenshots/practice-prepare.jpg)

![휴대폰 가로](screenshots/practice-mobile.jpg)

![실제 승리 결과](screenshots/practice-result.jpg)
