# 공개 준비 — 로봇 고물상 타이쿤

2026-11-17 Claude Code 작성. **실제 공개(Public 전환·Publish)와 Creator Hub 설정은 사용자가 직접 한다.** AI는 공개하지 않는다(AGENTS.md §8 규칙 9).

---

## 1. 게임 이름과 설명 (Creator Hub에 붙여 넣기용)

지금 Place 이름은 "마이오비"(처음 오비 시절 이름)라서, 공개 이름은 바꾸는 것을 추천한다.

**이름 후보**
1. 로봇 고물상 타이쿤 (Robot Junkyard Tycoon) ← 추천
2. 고물상 로봇 도둑 (Junkyard Robot Heist)
3. 로봇 고물왕 (Scrap Robot King)

**설명 — 한국어**
```
🤖 고장 난 로봇이 컨베이어 벨트를 타고 흘러와요!
먼저 사서 내 기지에 놓으면 로봇이 계속 돈을 벌어 와요.

🦹 남의 기지에서 로봇을 훔칠 수 있어요! 주인에게 잡히면 돌려줘야 해요.
🛡 방어막·경보기·레이저 울타리로 내 로봇을 지키세요.
📖 18종 로봇 도감을 채우고, 세트를 완성하면 수입이 영구로 늘어나요.
⭐ 환생하면 더 빨리 성장하고 ✨금색·💎다이아·🌈무지개 변종을 모을 수 있어요.
🏆 15분마다 서버 대회(수입왕·수집왕), 전체 서버 순위표에 이름을 올려 보세요.
🔧 다 같이 거대 로봇을 완성하면 10분 동안 서버 전체 수입 2배!

한 서버 최대 8명 · PC와 휴대폰 지원
```

**설명 — English**
```
🤖 Broken robots roll down the conveyor belt!
Buy them first and place them in your base to earn money every second.

🦹 Steal robots from other bases — but get caught by the owner and you lose them!
🛡 Protect your robots with shields, alarms and laser fences.
📖 Collect all 18 robots and complete sets for permanent income boosts.
⭐ Rebirth to grow faster and collect ✨Gold, 💎Diamond and 🌈Rainbow variants.
🏆 Server contests every 15 minutes and a global leaderboard.
🔧 Build the Giant Robot together for 2x income for the whole server!

Up to 8 players per server · PC and mobile
```

**장르:** 타이쿤(Tycoon) 또는 시뮬레이션(Simulation)
**추천 기기:** 컴퓨터·휴대폰·태블릿 켜기. 콘솔(Xbox 등)은 시험하지 않았으므로 끄기를 추천한다.

---

## 2. 썸네일과 아이콘

AI의 Studio 화면 캡처가 흰 화면만 돌려줘서, **사진은 사용자가 찍는다.**

| 종류 | 크기 | 개수 |
|---|---|---|
| 아이콘 | 512×512 (정사각형) | 1개 |
| 썸네일 | 1920×1080 (가로 16:9) | 1~10개 (3~5개 추천) |

**찍는 방법:** Studio에서 **Play**를 누르고 카메라를 원하는 각도로 맞춘다. **Windows 키 + Shift + S**로 영역을 잘라 저장한다. 위쪽 패널이나 버튼 같은 화면 UI가 사진에 들어가지 않게 자른다.

**찍을 장면 (추천 순서)**
1. **대표 장면:** 높은 곳에서 본 고물상 전체. 벨트와 기지 8개, 크레인, 거대 로봇이 함께 보이게.
2. **벨트 위 로봇:** 벨트 옆에서 낮게, 이름표가 달린 로봇 여러 대가 흘러가는 모습.
3. **내 기지:** 받침대에 로봇이 가득한 기지와 금고. 희귀·전설 로봇이 있으면 더 좋다.
4. **거대 로봇 완성:** 눈이 빛나는 거대 로봇. Studio 테스트 중이면 AI에게 "거대 로봇 완성시켜 줘"라고 하면 시험 장치로 완성 상태를 만들어 준다.
5. **순위판:** 환생 순위판 앞의 캐릭터.

**아이콘 아이디어:** 거대 로봇 머리 정면 가까이(빛나는 눈) + 위쪽에 "로봇 고물상" 글자. 글자는 그림 프로그램(예: 그림판, Canva)으로 넣는다. 작은 크기에서도 보이게 글자는 크고 짧게 쓴다.

**게임 아이콘:** AI가 만든 `docs/icons/game-icon.png`(512×512, 노을 고물상 + 로봇 + "로봇 고물상 TYCOON"). 다시 만들려면 `tools/game-icon.html`.

**올리는 곳:** create.roblox.com → 이 체험 → 왼쪽 메뉴 **게시 설정 ▼** 아래 항목(체험 세부 정보·썸네일 등, 화면 이름은 바뀔 수 있음). 2026-11-17 사용자 화면에서 "구성 → 기본 정보" 경로는 없었다. 찾기 어려우면 펼친 메뉴를 스크린샷으로 AI에게 보여 준다.

---

## 3. 공개 전 점검표

| # | 항목 | 상태 | 할 사람 |
|---|---|---|---|
| 1 | 서버 최대 인원 8명 | ✅ 완료 (2026-11-17) | — |
| 2 | Studio 저장 (Ctrl+S), 마지막 변경까지 | 사용자 확인 | 사용자 |
| 3 | 공개 이름 변경 ("마이오비" → 위 이름) | ✅ 사용자 완료 (2026-11-17) | 사용자 |
| 4 | 설명(한국어·영어), 장르, 기기 설정 | ✅ 사용자 완료 (2026-11-17) | 사용자 |
| 5 | 아이콘 1개, 썸네일 3개 이상 | 아이콘 ✅ · 썸네일 4장 준비 ✅(`docs/thumbnails/thumb-1~4.png`, 1920×1080, **1~3번은 2026-11-19 새 로봇으로 다시 만듦**) · ☐ 올리기 | 사용자 |
| 6 | **성숙도·준수 설문(Maturity & Compliance Questionnaire)** — 공개하려면 필수. 이 게임은 폭력·공포·실제 도박 요소가 없다(훔치기는 만화풍 게임 규칙). 질문에 사실대로 답한다 | ✅ 사용자 완료 (2026-11-17, 미디어 피드·미디어 공유·AI 상호작용·교차 경험 콘텐츠 모두 "아니요") | 사용자 |
| 7 | 개발자 상품 3개 설명 갱신 — 붙여 넣을 글은 아래 §6 (EMP는 "방어막 절반"으로 바뀜) | ☐ | 사용자 |
| 8 | 게임 패스 3개 등록·번호 입력 (2093876772 / 2092598831 / 2093948767) | ✅ 번호 입력 · ✅ 판매 켬 (2026-11-17, 관리형 가격은 끔) | 사용자 |
| 8-1 | 패스 3개·개발자 상품 3개 이미지 — AI가 `docs/icons/*.png`(512×512) 6장을 만듦. Creator Hub에서 각 패스·상품에 올리기 | ✅ 올림 (2026-11-17) | 사용자 |
| 8-2 | 방망이 게임패스 5개 등록 (이름·가격·이미지·설명은 아래 §5) → 번호를 AI에게 알려 `JunkyardConfig.GamePasses`에 넣기 | ✅ 등록·번호 입력 (2026-11-19: 2092905047 / 2094339061 / 2093559042 / 2092353045 / 2094255003) | 사용자 |
| 9 | Studio 전용 시험 장치 | ✅ 실제 서버에서는 작동 안 함 (IsStudio 확인, 나머지는 서버만 바꿀 수 있는 값) | — |
| 10 | 오류·경고 0 (혼자 Play) | ✅ 2026-11-17 | — |
| 11 | 2인 테스트: 훔치기·붙잡기·방어막·경보·거대 로봇 함께 기부 | 일부 완료 (경보 ✅) | 사용자 또는 Codex |
| 12 | 휴대폰 화면 (상점·도감·대회·안내·기부 창·방망이 버튼) | 상점·도감·대회·안내 ✅, 방망이·강화 버튼 자리와 화면 정리 ✅(2026-11-19, B-48), 기부 창 미확인 | 사용자 |
| 13 | 공개 범위: 처음에는 **친구만** 또는 **비공개 링크**로 몇 명과 먼저 해 보고, 문제가 없으면 Public | ☐ | 사용자 |

**알아 둘 것**
- Studio Play는 실제 DataStore를 쓴다. 그래서 **사용자 본인 계정이 순위표 1위로 올라가 있고**, 돈·로봇도 시험 값이 섞여 있다. 그대로 둬도 문제는 없다. 지우려면(RemoveAsync) AI에게 따로 요청하고 승인한다.
- 공개 직후 실제 서버에서 확인할 것:
  - 새 계정(친구)으로 첫 접속 안내 5단계가 처음부터 뜨는지
  - 8명이 다 찼을 때 9번째 사람이 새 서버로 가는지
  - Creator Hub → 모니터링에서 오류 로그

---

## 4. 공개 뒤 할 일 (추천)
1. 첫 1~2일은 Creator Hub **애널리틱스**에서 평균 플레이 시간, 재방문율, 첫 5분 안에 나가는 비율을 본다.
2. 첫 5분 이탈이 많으면 첫 접속 안내와 첫 로봇 가격(밸런스)을 조정한다. 숫자는 `JunkyardConfig` 한 곳에 있다.
3. 나중에 할 수 있는 것: 도둑왕 대회, 주간 순위표, 게임 패스 등록, 새 로봇·새 변종, 이벤트 맵.

---

## 5. 방망이 게임패스 5개 (Creator Hub에 붙여 넣기용)

Creator Hub → 이 게임 → **수익 창출 → 게임 패스 → 패스 만들기**. 이미지는 `docs/icons/`에 있다(512×512, AI가 `tools/store-icons.html`로 만듦).
만든 뒤 **판매 켜기**와 **가격**을 정하고, 패스 번호 5개를 AI에게 알려 준다. 번호를 넣기 전까지 게임 안 방망이 창에는 "준비 중"으로 보인다.
꾸미기 4종은 **성능이 같다**(모양·효과만). 설명에도 그렇게 적어 "돈 주고 이기는 게임"이라는 오해를 막는다.

### 🏏 방망이 성장 2배 — 99 R$
- 이미지: `docs/icons/pass-bat-growth.png`
- 이름: `🏏 방망이 성장 2배`
- 설명 (한국어):
  > 도둑맞은 로봇을 방망이로 되찾을 때 받는 경험치가 2배! 방망이 단계를 게임 돈으로 올릴 때도 반값이에요. 나무 → 쇠 → 금 → 네온 → 무지개 방망이까지 남보다 빨리 키워 보세요. (방망이는 누구나 무료로 키울 수 있고, 이 패스는 더 빨리 키우게 해 줘요. 환생해도 방망이 단계는 그대로예요.)
- Description (English):
  > Earn 2x bat XP every time you win back a stolen robot, and pay half price to level up your bat with in-game cash. Grow from Wood to Iron, Gold, Neon and Rainbow faster than anyone! (Every player can level their bat for free — this pass just makes it faster. Bat levels stay after rebirth.)

### 🔧 렌치 방망이 — 49 R$
- 이미지: `docs/icons/pass-bat-wrench.png`
- 이름: `🔧 렌치 방망이`
- 설명 (한국어):
  > 고물상 정비공의 커다란 렌치로 도둑을 쫓아내요! 휘두르면 주황색 불꽃이 튀고 꼬리 빛이 따라와요. 사면 바로 손에 들리고, 방망이 창에서 언제든 바꿔 낄 수 있어요. 모양과 효과만 바뀌고 성능은 같아요.
- Description (English):
  > Chase thieves away with a giant mechanic's wrench! Orange sparks burst when you swing, with a glowing trail. Equipped right after purchase; switch any time in the Bat menu. Cosmetic only — same power as other bats.

### 🍭 사탕 방망이 — 79 R$
- 이미지: `docs/icons/pass-bat-candy.png`
- 이름: `🍭 사탕 방망이`
- 설명 (한국어):
  > 빨간 줄무늬 사탕 지팡이 끝에 커다란 막대 사탕! 휘두르면 분홍색 불꽃이 퍼져요. 사면 바로 손에 들리고, 방망이 창에서 언제든 바꿔 낄 수 있어요. 모양과 효과만 바뀌고 성능은 같아요.
- Description (English):
  > A striped candy cane topped with a huge lollipop! Pink sparks burst when you swing, with a glowing trail. Equipped right after purchase; switch any time in the Bat menu. Cosmetic only — same power as other bats.

### 🎸 기타 방망이 — 99 R$
- 이미지: `docs/icons/pass-bat-guitar.png`
- 이름: `🎸 기타 방망이`
- 설명 (한국어):
  > 빨간 기타를 들고 무대처럼 도둑을 혼내 줘요! 휘두르면 빨간 불꽃과 꼬리 빛이 따라와요. 사면 바로 손에 들리고, 방망이 창에서 언제든 바꿔 낄 수 있어요. 모양과 효과만 바뀌고 성능은 같아요.
- Description (English):
  > Rock out on thieves with a red guitar! Red sparks and a glowing trail follow every swing. Equipped right after purchase; switch any time in the Bat menu. Cosmetic only — same power as other bats.

### ⚡ 번개 방망이 — 149 R$
- 이미지: `docs/icons/pass-bat-lightning.png`
- 이름: `⚡ 번개 방망이`
- 설명 (한국어):
  > 스스로 빛나는 노란 번개 방망이! 양옆에 번개 무늬가 있고, 주변을 밝히며, 휘두르면 파란 번개 불꽃이 터져요. 사면 바로 손에 들리고, 방망이 창에서 언제든 바꿔 낄 수 있어요. 모양과 효과만 바뀌고 성능은 같아요.
- Description (English):
  > A glowing yellow lightning bat with bolt fins that lights up the area around you! Blue lightning sparks burst on every swing. Equipped right after purchase; switch any time in the Bat menu. Cosmetic only — same power as other bats.

---

## 6. 개발자 상품 3개 설명 (Creator Hub에 붙여 넣기용, 2026-11-19 게임 효과 기준)

Creator Hub → 이 게임 → **수익 창출 → 개발자 상품** → 각 상품 → 설명 바꾸기. 이름·가격은 그대로 둬도 된다.

### ⚡ EMP 5개 — 49 R$ (3732684191)
- 한국어:
  > 게임 돈 없이 쓰는 EMP 5번! 방어막이 켜진 남의 기지 가까이에서 쓰면 그 방어막의 남은 시간이 절반으로 줄어요. 충전 시간은 보통 EMP와 같고, 남은 횟수는 저장돼요. (막 시작한 새싹 플레이어에게는 쓸 수 없어요.)
- English:
  > 5 free EMP uses — no in-game cash needed! Use it near another player's shielded base to cut their remaining shield time in half. Same cooldown as a normal EMP; unused charges are saved. (Can't be used on brand-new "sprout" players.)

### 🛡 즉시 방어막 — 25 R$ (3732684298)
- 한국어:
  > 방어막이 충전 중이어도 지금 바로 내 기지 방어막을 켜요! 켜져 있는 동안에는 아무도 내 기지에 들어와 로봇을 훔칠 수 없어요.
- English:
  > Turn on your base shield right now, even while it's recharging! While it's on, nobody can enter your base to steal robots.

### ✨ 희귀 로봇 비 (서버 전체) — 99 R$ (3732684420)
- 한국어:
  > 60초 동안 서버 모든 사람의 컨베이어 벨트에 희귀 이상 로봇이 5배 더 자주 나와요! 산 사람에게는 희귀 이상 로봇 1개를 확정으로 선물해요. 등급별 확률은 게임 안 상점의 Robux 칸에 공개되어 있어요.
- English:
  > For 60 seconds, Rare-or-better robots appear 5x more often on everyone's conveyor belt in the server! The buyer also gets one guaranteed Rare-or-better robot as a gift. Exact odds are shown in the in-game shop's Robux tab.
