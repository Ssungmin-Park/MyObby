# 문방구 캐릭터 시험장

쫀득의 피격 축소와 철컥의 발사·놀람·반동을 실제 Roblox Studio에서 확인하는 시제품이다. 게임 기획과 최신 작업 기록은 [새 게임 기획서](../docs/NEW_GAME_DESIGN.md)의 14절에 있다.

## 작업 대상

- 새 Studio 이름 `Place1`, 최초 Place ID·Universe ID 모두 `0`.
- 이번 Studio ID `baba046b-01a7-44b6-821f-e49c24f84de6`. 재시작 시 목록에서 다시 확인한다.
- Workspace 식별 속성 `PrototypeProject = "StationeryCharacterLab"`.
- 기존 고물상 Place ID `77293997616106`은 도구 스크립트의 실행 거절 대상이다.

## 시험 방법

새 Studio에서 Play를 누르면 고정 카메라와 시험 버튼이 나타난다.

| 조작 | 동작 |
|---|---|
| 쫀득 피격 / Q | 체력 20 감소와 외형 축소 |
| 철컥 발사 / E | 발사 효과음·철심 효과·상부 동작·몸 반동·눈 확대 |
| 처음으로 / R | 체력과 표시 상태 복원 |
| 자동 반복 | 피격·발사·체력 소진 뒤 복원 반복 |
| 여러 마리 | 시험 캐릭터 17마리로 전환, 다시 누르면 2마리 |

서버가 체력과 발사를 확정하며, 클라이언트가 시각 모델·효과를 재생한다. 두 런타임 스크립트는 Studio에서만 동작한다. 이 시험장은 전투 게임의 완성 버전이 아니며 실제 PvP·이동 AI·저장 시스템은 후속 구현이다.

## 파일과 Studio 경로

| 파일 | Studio 반영 대상 / 용도 |
|---|---|
| `src/ServerScriptService/CharacterLab.server.luau` | `ServerScriptService/CharacterLab` |
| `src/StarterPlayer/StarterPlayerScripts/CharacterLab.client.luau` | `StarterPlayer/StarterPlayerScripts/CharacterLab` |
| `tools/build-character-lab.luau` | 시험장·식별용 리모트/폴더·초기 속성 구성 |
| `tools/prepare-generated-characters.luau` | 생성 원본 보관·시험 복제본·Edit 미리보기 준비 |
| `tools/refine-character-faces.luau` | 철컥 표정·팔다리 보완과 기본 스폰 무늬 숨김 |
| `screenshots/` | 실제 데스크톱·휴대폰 가로 미리보기 화면 |

빌드 도구는 생성 원본이 준비된 새 시험 Studio에서 순서대로 실행한다. 생성 에셋의 자동 재다운로드·완전한 무인 복구는 검증하지 않았다.

## 검증과 저장

2026-11-18, Studio 1인 Play에서 피격 5회·사망 표시·초기화·발사·반동 복귀·눈 확대 복귀·서버 연타 제한·자동 반복·17마리 렌더를 확인했다. iPhone 17 Pro 가로 시뮬레이터에서 버튼 클릭·안전 영역·문구 표시를 확인했다. 실제 휴대폰 성능과 멀티플레이·세로 화면은 미검증이다.

Studio와 원문·바이트·체크섬이 일치한다. 체크섬은 `(h * 31 + byte) % 1000000007` 방식이다.

| 스크립트 | 바이트 | 체크섬 |
|---|---|---|
| 서버 CharacterLab | 2605 | 240605641 |
| 클라이언트 CharacterLab | 10196 | 223953855 |

**새 Studio는 아직 저장 전이다. 사용자가 Ctrl+S로 별도 Studio 파일을 저장해야 시험장과 3D 모델 전체가 보존된다.** 소스와 캡처는 이 폴더에 보관한다. 생성 원본 모델은 새 Studio의 `ServerStorage/CharacterLabSources`, 동작용 모델은 `ReplicatedStorage/CharacterLabAssets`에 있다. 생성 모델 에셋 번호는 쫀득 `124308299115203`, 철컥 `139594764218049`다.

![실제 Studio 시험 화면](screenshots/character-lab-desktop.jpg)
