# 작업 기록

## 2026-11-16
- 기존 10스테이지 그레이박스를 CLAUDE.md 구조로 정리했다. 바뀐 위치는 `Workspace/Stages/Stage01~10`(Model), `Workspace/Checkpoints/1~10`, `Workspace/KillZone`이다. 10스테이지 발판은 3×3에서 4×4로 키웠다.
- `ObbyServer` 스크립트를 `Leaderstats`·`Checkpoints`·`Respawn` 3개(`--!strict`)로 나눴다. 체크포인트는 바로 다음 번호만 인정한다. 원본은 꺼서 `ServerStorage/ObbyServer_backup`에 백업했다. 플레이테스트에서 체크포인트·리스폰·리더보드가 정상 동작했고 에러는 없었다.
- 10스테이지 발판 간격을 5.1에서 6.0~6.1스터드로 다시 넓혔다(9스테이지는 5.7). 체크포인트 10은 Z=524에서 530으로 옮겼다. 플레이테스트에서 Stage 10 도달과 리스폰을 확인했다.
- 테마를 "실험실 탈출"로 정했다. 스테이지 4–10을 장애물 구간으로 다시 만들었다: 레이저 4–5, 회전 막대 6, 움직이는 발판 7–8, 시간제 보안문 9, 종합 10. 이전 스테이지는 `ServerStorage/StagesBackup`에 있다. 골인은 `Checkpoints/11`(EXIT)이다.
- 스크립트를 추가했다: `Hazards`(태그 KillPart·Spinner·Mover·TimedDoor), `Finish`, `Remotes/Escaped`, `StarterPlayerScripts/EscapeMessage`. 플레이테스트에서 장애물 동작, 레이저 사망, 발판 탑승, Stage 11 골인, "탈출 성공!" 표시를 확인했고 에러는 없었다.
- 직접 플레이해 보고 난이도가 적당하다고 확인했다. 스크립트를 `src/`로 내보내고 README를 썼다. git과 GitHub CLI로 공개 저장소 연동을 시작했다.
