--!strict
-- EventBus + Catalog (A1.5): subscribe → publish → receive, payload schema, publisher-domain misuse, handler isolation.
-- Every case builds its own bus (EventBus.new), so nothing touches the shared server bus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestRunner = require(script.Parent.Parent.TestRunner)
local Events = ReplicatedStorage.Shared.Events
local EventBus = require(Events.EventBus)
local Catalog = require(Events.Catalog)

type Report = { kind: EventBus.ErrorKind, message: string }

-- A valid EnemyKilled payload; each call returns a fresh table.
local function kill(): { [string]: unknown }
	return {
		MatchId = "m-1",
		KillerUserId = 101,
		EnemyId = 7,
		DefId = "Shambler",
		ProtocolLevel = 2,
		Position = Vector3.new(1, 2, 3),
	}
end

local function with(base: { [string]: unknown }, key: string, value: unknown): { [string]: unknown }
	local out = table.clone(base)
	out[key] = value
	return out
end

-- A non-strict bus whose reports land in the returned list.
local function lenient(): (EventBus.Bus, { Report })
	local reports: { Report } = {}
	local bus = EventBus.new({
		strict = false,
		onError = function(kind: EventBus.ErrorKind, message: string)
			table.insert(reports, { kind = kind, message = message })
		end,
	})
	return bus, reports
end

-- A minimal valid value for a field type (used to publish every catalog event once).
local function sample(ft: Catalog.FieldType): unknown
	local kind = ft.kind
	if kind == "string" then
		return "x"
	elseif kind == "number" then
		return 1.5
	elseif kind == "integer" then
		return 1
	elseif kind == "boolean" then
		return true
	elseif kind == "Vector3" then
		return Vector3.new(1, 2, 3)
	elseif kind == "enum" then
		return (ft.values :: { string })[1]
	elseif kind == "array" then
		return { sample(ft.of :: Catalog.FieldType) }
	elseif kind == "map" then
		return { [sample(ft.key :: Catalog.FieldType)] = sample(ft.value :: Catalog.FieldType) }
	elseif kind == "record" then
		local out: { [string]: unknown } = {}
		for name, sub in ft.fields :: Catalog.Fields do
			out[name] = sample(sub)
		end
		return out
	end
	return sample((ft.options :: { Catalog.FieldType })[1])
end

local function sortedKeys(t: { [string]: unknown }): { string }
	local keys: { string } = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("subscribe → publish → receive", function()
		it("delivers the payload to a subscriber", function()
			local bus = EventBus.new()
			local got: { [string]: unknown }? = nil
			bus:subscribe("EnemyKilled", function(p)
				got = p
			end)
			bus:publisher("Encounter"):publish("EnemyKilled", kill())
			expect(got).toEqual(kill())
		end)

		it("delivers to every subscriber in subscription order", function()
			local bus = EventBus.new()
			local order: { string } = {}
			for _, label in { "a", "b", "c" } do
				bus:subscribe("PlayerLeveledUp", function(p)
					table.insert(order, `{label}{p.NewLevel}`)
				end)
			end
			bus:publisher("Encounter"):publish("PlayerLeveledUp", { MatchId = "m", UserId = 1, NewLevel = 4 })
			expect(order).toEqual({ "a4", "b4", "c4" })
			expect(bus:subscriberCount("PlayerLeveledUp")).toBe(3)
		end)

		it("delivers only to subscribers of that event", function()
			local bus = EventBus.new()
			local hits = 0
			bus:subscribe("PlayerDowned", function()
				hits += 1
			end)
			bus:publisher("Encounter"):publish("EnemyKilled", kill())
			expect(hits).toBe(0)
		end)

		it("stops delivering after Disconnect", function()
			local bus = EventBus.new()
			local hits = 0
			local conn = bus:subscribe("EnemyKilled", function()
				hits += 1
			end)
			local publish = bus:publisher("Encounter")
			publish:publish("EnemyKilled", kill())
			conn:Disconnect()
			conn:Disconnect()
			publish:publish("EnemyKilled", kill())
			expect(hits).toBe(1)
			expect(conn.Connected).toBe(false)
			expect(bus:subscriberCount("EnemyKilled")).toBe(0)
		end)

		it("skips a subscriber disconnected by an earlier handler in the same publish", function()
			local bus = EventBus.new()
			local hits: { string } = {}
			local second: EventBus.Connection
			bus:subscribe("EnemyKilled", function()
				table.insert(hits, "first")
				second:Disconnect()
			end)
			second = bus:subscribe("EnemyKilled", function()
				table.insert(hits, "second")
			end)
			bus:publisher("Encounter"):publish("EnemyKilled", kill())
			expect(hits).toEqual({ "first" })
		end)

		it("hands out a deep-frozen copy and leaves the publisher's table alone", function()
			local bus = EventBus.new()
			local got: any = nil
			bus:subscribe("MatchStarted", function(p)
				got = p
			end)
			local payload = { MatchId = "m", MissionId = "M1", DifficultyId = "Normal", Participants = { 1, 2 } }
			bus:publisher("Encounter"):publish("MatchStarted", payload)
			expect(got == payload).toBe(false)
			expect(table.isfrozen(got)).toBe(true)
			expect(table.isfrozen(got.Participants)).toBe(true)
			expect(table.isfrozen(payload)).toBe(false)
			expect(function()
				got.Participants[1] = 99
			end).toThrow("readonly")
		end)

		it("publishes every catalog event from its own publisher", function()
			local bus = EventBus.new()
			local received: { [string]: boolean } = {}
			local names = sortedKeys(Catalog.EVENTS :: any)
			for _, name in names do
				bus:subscribe(name :: any, function()
					received[name] = true
				end)
			end
			for _, name in names do
				local def = Catalog.EVENTS[name]
				bus:publisher(def.publisher):publish(name :: any, sample({ kind = "record", fields = def.fields }))
			end
			expect(sortedKeys(received :: any)).toEqual(names)
			expect(#names).toBe(37)
		end)
	end)

	describe("wrong-type payload", function()
		it("is rejected in strict mode and never delivered", function()
			local bus = EventBus.new()
			local hits = 0
			bus:subscribe("EnemyKilled", function()
				hits += 1
			end)
			local publish = bus:publisher("Encounter")
			local cases: { { payload: unknown, message: string } } = {
				{ payload = with(kill(), "EnemyId", "7"), message = 'EnemyKilled.EnemyId: expected integer, got string "7"' },
				{ payload = with(kill(), "EnemyId", 7.5), message = "EnemyKilled.EnemyId: expected integer, got 7.5" },
				{ payload = with(kill(), "Position", 5), message = "EnemyKilled.Position: expected Vector3, got number 5" },
				{ payload = with(kill(), "MatchId", nil), message = "EnemyKilled.MatchId: expected non-empty string, got nil" },
				{ payload = with(kill(), "MatchId", ""), message = 'EnemyKilled.MatchId: expected non-empty string, got string ""' },
				{ payload = with(kill(), "ProtocolLevel", 0 / 0), message = "EnemyKilled.ProtocolLevel: expected finite integer" },
				{ payload = with(kill(), "Extra", 1), message = 'EnemyKilled: unexpected field string "Extra"' },
				{ payload = with(kill(), "Position", workspace), message = "EnemyKilled.Position: expected Vector3, got Instance" },
				{ payload = "not a table", message = "EnemyKilled: expected record, got string" },
			}
			for _, case in cases do
				expect(function()
					publish:publish("EnemyKilled", case.payload)
				end).toThrow("[Events] " .. case.message)
			end
			expect(hits).toBe(0)
		end)

		it("checks nested arrays, enums, maps and records", function()
			local bus = EventBus.new()
			local publish = bus:publisher("Encounter")
			expect(function()
				publish:publish("ExtractionVoted", { MatchId = "m", UserId = 1, Choice = "Stay" })
			end).toThrow('ExtractionVoted.Choice: expected one of Hold|Extract, got string "Stay"')
			expect(function()
				publish:publish("BossDefeated", { MatchId = "m", BossId = "B", Participants = { 1, "2" :: any } })
			end).toThrow('BossDefeated.Participants[2]: expected integer, got string "2"')
			expect(function()
				publish:publish("BossDefeated", { MatchId = "m", BossId = "B", Participants = { [1] = 1, [3] = 3 } })
			end).toThrow("BossDefeated.Participants: expected array")
			expect(function()
				bus:publisher("LiveOps"):publish("RaidCompleted", {
					RaidId = "r",
					Participants = { 1 },
					Contributions = { [1] = 10, ["2"] = 5 } :: any,
				})
			end).toThrow('RaidCompleted.Contributions key: expected integer, got string "2"')
			expect(function()
				bus:publisher("Progression"):publish("RewardsGranted", {
					UserId = 1,
					ClaimId = "c",
					Rewards = { { Kind = "Currency", Id = "Scrap", Amount = 1.5 } },
				})
			end).toThrow("RewardsGranted.Rewards[1].Amount: expected integer, got 1.5")
			expect(function()
				bus:publisher("Platform"):publish("FeatureFlagChanged", { Flag = "f", Value = {} })
			end).toThrow("FeatureFlagChanged.Value: expected boolean|number|string, got table")
			bus:publisher("Platform"):publish("FeatureFlagChanged", { Flag = "f", Value = false })
		end)

		it("is reported and dropped outside strict mode", function()
			local bus, reports = lenient()
			local hits = 0
			bus:subscribe("EnemyKilled", function()
				hits += 1
			end)
			bus:publisher("Encounter"):publish("EnemyKilled", with(kill(), "EnemyId", "7"))
			expect(hits).toBe(0)
			expect(#reports).toBe(1)
			expect(reports[1].kind).toBe("payload")
			expect(reports[1].message).toBe('EnemyKilled.EnemyId: expected integer, got string "7" (dropped)')
		end)
	end)

	describe("publish from the wrong domain", function()
		it("asserts in strict mode", function()
			local bus = EventBus.new()
			local hits = 0
			bus:subscribe("EnemyKilled", function()
				hits += 1
			end)
			expect(function()
				bus:publisher("Combat"):publish("EnemyKilled", kill())
			end).toThrow("[Events] EnemyKilled is published by Encounter only; Combat tried to publish it")
			expect(hits).toBe(0)
		end)

		it("asserts for every catalog event published by any other identity", function()
			local bus = EventBus.new()
			local checked = 0
			for name, def in Catalog.EVENTS do
				local payload = sample({ kind = "record", fields = def.fields })
				for _, other in Catalog.PUBLISHERS do
					if other ~= def.publisher then
						expect(function()
							bus:publisher(other :: Catalog.PublisherId):publish(name :: any, payload)
						end).toThrow(`{name} is published by {def.publisher} only`)
						checked += 1
					end
				end
			end
			expect(checked).toBe(37 * 11)
		end)

		it("is reported and dropped outside strict mode", function()
			local bus, reports = lenient()
			local hits = 0
			bus:subscribe("EnemyKilled", function()
				hits += 1
			end)
			bus:publisher("Combat"):publish("EnemyKilled", kill())
			expect(hits).toBe(0)
			expect(reports[1].kind).toBe("domain")
		end)

		it("rejects an unknown publisher identity in any mode", function()
			local bus = lenient()
			expect(function()
				bus:publisher("Quests" :: any)
			end).toThrow('[Events] unknown publisher string "Quests"')
		end)
	end)

	describe("unknown events", function()
		it("throws on publish in strict mode, reports outside it", function()
			expect(function()
				EventBus.new():publisher("Encounter"):publish("EnemyKiled" :: any, kill())
			end).toThrow('[Events] Encounter published unknown event string "EnemyKiled"')
			local bus, reports = lenient()
			bus:publisher("Encounter"):publish("EnemyKiled" :: any, kill())
			expect(reports[1].kind).toBe("unknown_event")
		end)

		it("cannot be subscribed to in any mode", function()
			local bus = lenient()
			expect(function()
				bus:subscribe("EnemyKiled" :: any, function() end)
			end).toThrow('[Events] cannot subscribe to unknown event string "EnemyKiled"')
		end)
	end)

	describe("handler isolation", function()
		it("reports a failing handler without breaking the publisher or other handlers", function()
			local bus, reports = lenient()
			local after = 0
			bus:subscribe("EnemyKilled", function()
				error("boom")
			end)
			bus:subscribe("EnemyKilled", function()
				after += 1
			end)
			bus:publisher("Encounter"):publish("EnemyKilled", kill())
			expect(after).toBe(1)
			expect(#reports).toBe(1)
			expect(reports[1].kind).toBe("handler")
			expect(string.find(reports[1].message, "EnemyKilled handler failed", 1, true) ~= nil).toBe(true)
			expect(string.find(reports[1].message, "boom", 1, true) ~= nil).toBe(true)
		end)

		it("keeps a strict bus quiet for the publisher when a handler fails", function()
			local reports: { Report } = {}
			local bus = EventBus.new({
				onError = function(kind: EventBus.ErrorKind, message: string)
					table.insert(reports, { kind = kind, message = message })
				end,
			})
			bus:subscribe("PlayerDowned", function()
				error("consumer bug")
			end)
			bus:publisher("Combat"):publish("PlayerDowned", { MatchId = "m", UserId = 1 })
			expect(reports[1].kind).toBe("handler")
		end)

		it("does not block the publisher on a yielding handler", function()
			local bus = EventBus.new()
			local done = false
			bus:subscribe("PlayerDowned", function()
				task.wait(0.05)
				done = true
			end)
			local started = os.clock()
			bus:publisher("Combat"):publish("PlayerDowned", { MatchId = "m", UserId = 1 })
			expect(os.clock() - started).toBeLessThan(0.01)
			expect(done).toBe(false)
			task.wait(0.15)
			expect(done).toBe(true)
		end)

		it("survives a failing error handler", function()
			local bus = EventBus.new({ strict = false })
			bus:setErrorHandler(function()
				error("reporter down")
			end)
			bus:publisher("Combat"):publish("EnemyKilled", kill())
			expect(true).toBe(true)
		end)
	end)

	describe("catalog", function()
		it("holds the §5.3 events with at least the §5.3 fields", function()
			local excerpt: { [string]: { string } } = {
				EnemyKilled = { "MatchId", "KillerUserId", "EnemyId", "ProtocolLevel", "Position" },
				PlayerLeveledUp = { "MatchId", "UserId", "NewLevel" },
				UpgradeChosen = { "MatchId", "UserId", "OfferId", "CardIndex", "ResultId" },
				WeaponEvolved = { "MatchId", "UserId", "EvolutionId" },
				ProtocolChanged = { "MatchId", "NewLevel" },
				ExtractionVoted = { "MatchId", "UserId", "Choice" },
				MissionEnded = { "MatchId", "Outcome", "ProtocolReached", "Multiplier", "Participants" },
				RewardsGranted = { "UserId", "ClaimId", "Rewards" },
				ItemEnhanced = { "UserId", "InstanceId", "NewLevel" },
				RaidCompleted = { "RaidId", "Participants", "Contributions" },
				PurchaseGranted = { "UserId", "ProductId", "ReceiptId" },
			}
			local missing: { string } = {}
			for name, fields in excerpt do
				local def = Catalog.EVENTS[name]
				if def == nil then
					table.insert(missing, name)
				else
					for _, field in fields do
						if def.fields[field] == nil then
							table.insert(missing, `{name}.{field}`)
						end
					end
				end
			end
			expect(missing).toEqual({})
		end)

		it("puts MatchId on every in-run event", function()
			local missing: { string } = {}
			for name, def in Catalog.EVENTS do
				if (def.publisher == "Encounter" or def.publisher == "Combat") and def.fields.MatchId == nil then
					table.insert(missing, name)
				end
			end
			expect(missing).toEqual({})
		end)

		it("refuses a malformed catalog", function()
			local T = Catalog.T
			local bad: { [string]: unknown } = {
				["unknown publisher Quests"] = { Thing = { publisher = "Quests", since = "A1.5", fields = { Id = T.string } } },
				["unknown field kind table"] = { Thing = Catalog.event("Encounter", "A1.5", { Id = { kind = "table" } :: any }) },
				["must be PascalCase"] = { thing = Catalog.event("Encounter", "A1.5", { Id = T.string }) },
				["needs at least one field"] = { Thing = Catalog.event("Encounter", "A1.5", {}) },
				["map keys must be string or integer"] = {
					Thing = Catalog.event("Encounter", "A1.5", { M = Catalog.map(T.Vector3, T.number) }),
				},
				["catalog has no events"] = {},
			}
			for fragment, catalog in bad do
				expect(function()
					EventBus.new({ catalog = catalog :: any })
				end).toThrow(fragment)
			end
		end)

		it("accepts a custom valid catalog", function()
			local bus = EventBus.new({
				catalog = { Ping = Catalog.event("Telemetry", "A1.5", { Count = Catalog.T.integer }) },
			})
			local got = 0
			bus:subscribe("Ping" :: any, function(p)
				got = p.Count
			end)
			bus:publisher("Telemetry"):publish("Ping" :: any, { Count = 3 })
			expect(got).toBe(3)
		end)
	end)
end
