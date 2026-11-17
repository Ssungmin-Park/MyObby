--!strict
-- JunkyardStore: Robux 결제 처리(개발자 상품)와 게임패스 보유 확인. (서버 전용 모듈, Junkyard가 쓴다)
--
-- 원칙
--   1. MarketplaceService.ProcessReceipt는 게임 전체에서 이 모듈 한 곳에서만 설정한다.
--   2. 같은 영수증(PurchaseId)은 한 번만 지급한다. 지급 기록:
--        DataStore "Receipts_v1", 키 "Receipt_<PurchaseId>", 값 { userId, product, at }
--   3. 순서: 이미 기록이 있으면 "지급 완료"로 응답 → 플레이어가 서버에 없거나 준비 안 됐으면 "나중에"(Roblox가 다시 보냄)
--      → 지급 → 기록 → "지급 완료". 기록에 실패하면 "나중에"로 응답한다.
--      (지급 직후 서버가 꺼지는 아주 드문 경우에는 다시 지급될 수 있다. Roblox 공식 권장 흐름과 같다.)
--   4. 상품·게임패스 id는 JunkyardConfig에 있다. id가 0인 상품은 무시한다.
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("JunkyardConfig"))

export type Handlers = {
	grantProduct: (player: Player, key: string) -> boolean, -- 지급에 성공하면 true
	onPassOwned: (player: Player, key: string) -> (), -- 게임에서 게임패스를 새로 샀을 때
}

local Store = {}
local handlers: Handlers? = nil

local receiptStore: any = nil
local function getReceiptStore(): any
	if receiptStore == nil then
		receiptStore = DataStoreService:GetDataStore("Receipts_v1")
	end
	return receiptStore
end

-- 테스트용: 가짜 저장소를 넣는다
function Store.setReceiptStoreForTest(fake: any)
	receiptStore = fake
end

local function keyByProductId(productId: number): string?
	for key, offer in Config.Products do
		if offer.id ~= 0 and offer.id == productId then
			return key
		end
	end
	return nil
end

local function keyByPassId(passId: number): string?
	for key, offer in Config.GamePasses do
		if offer.id ~= 0 and offer.id == passId then
			return key
		end
	end
	return nil
end

-- 개발자 상품 영수증 처리 (테스트에서도 직접 부를 수 있게 공개)
function Store.processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local key = keyByProductId(receipt.ProductId)
	if not key then
		warn("[JunkyardStore] 알 수 없는 상품 id:", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receiptKey = "Receipt_" .. tostring(receipt.PurchaseId)
	local okGet, existing = pcall(function()
		return getReceiptStore():GetAsync(receiptKey)
	end)
	if not okGet then
		warn("[JunkyardStore] 영수증 기록 확인 실패:", existing)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if existing ~= nil then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- 이미 지급함
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not handlers then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- 플레이어가 다시 들어오면 Roblox가 다시 보낸다
	end
	local okGrant, granted = pcall(handlers.grantProduct, player, key)
	if not okGrant or granted ~= true then
		if not okGrant then
			warn("[JunkyardStore] 지급 중 오류:", granted)
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local okSet, setError = pcall(function()
		getReceiptStore():SetAsync(receiptKey, { userId = receipt.PlayerId, product = key, at = os.time() })
	end)
	if not okSet then
		warn("[JunkyardStore] 영수증 기록 실패:", setError)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- 게임패스 보유 여부 (접속할 때 한 번 확인). 확인 실패하면 없음으로 본다.
function Store.checkPasses(player: Player): { [string]: boolean }
	local owned: { [string]: boolean } = {}
	for _, key in Config.PassOrder do
		local id = Config.GamePasses[key].id
		if id ~= 0 then
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
			end)
			if ok and result == true then
				owned[key] = true
			elseif not ok then
				warn("[JunkyardStore] 게임패스 확인 실패:", key, result)
			end
		end
	end
	return owned
end

local started = false

function Store.start(newHandlers: Handlers)
	if started then
		return
	end
	started = true
	handlers = newHandlers
	MarketplaceService.ProcessReceipt = Store.processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		local key = keyByPassId(passId)
		if purchased and key and handlers then
			handlers.onPassOwned(player, key)
		end
	end)
end

return Store
