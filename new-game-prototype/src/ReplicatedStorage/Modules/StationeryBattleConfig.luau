--!strict
-- 첫 연습 경기의 시험 수치. 실제 출시 밸런스는 플레이 결과로 조정한다.
return {
	Budget = 1000, PrepareSeconds = 45, BattleSeconds = 90, Tick = 0.1,
	HeadquartersHealth = 600, DetectRange = 18, MaxTroops = 12,
	Center = Vector3.new(120, 1.05, 0), Lanes = { -16, 0, 16 },
	SpawnX = 30, HeadquartersX = 39,
	Slots = { Vector2.new(-29, -9), Vector2.new(-34, -18), Vector2.new(-29, 9), Vector2.new(-34, 18) },
	Skill = { Radius = 8, Slow = 0.4, Duration = 4, BotAt = 25 },
	Units = {
		Jjondeuk = { Name = "쫀득", Price = 100, Health = 140, Damage = 10, BuildingDamage = 10, Cooldown = 1, Range = 3, Speed = 4 },
		Cheolkeok = { Name = "철컥", Price = 200, Health = 70, Damage = 20, BuildingDamage = 30, Cooldown = 1.5, Range = 12, Speed = 3 },
		Tower = { Name = "연필 포탑", Price = 250, Health = 180, Damage = 12, BuildingDamage = 0, Cooldown = 1, Range = 16, Speed = 0 },
	},
	Bots = {
		Balanced = { Jjondeuk = 3, Cheolkeok = 1, Towers = 2, Name = "균형형 봇" },
		Attack = { Jjondeuk = 2, Cheolkeok = 4, Towers = 0, Name = "공격형 봇" },
		Defense = { Jjondeuk = 0, Cheolkeok = 0, Towers = 4, Name = "수비형 봇" },
	},
}
