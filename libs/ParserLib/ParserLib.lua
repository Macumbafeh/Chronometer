--[[
Name: ParserLib
Revision: $Revision: 28229 $
Author(s): rophy (rophy123@gmail.com)
Website: http://www.wowace.com/index.php/ParserLib
Documentation: http://www.wowace.com/index.php/ParserLib
SVN: http://svn.wowace.com/wowace/trunk/ParserLib
Description: An embedded combat log parser, which works on all localizations.
Dependencies: None

License: LGPL v2.1

Copyright (C) 2006-2007 Rophy

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
--]]




---------------------------------------------------------------------------
--	To Get an instance of ParserLib, call this:
-- 	local parser = ParserLib:GetInstance(version)
-- 	where the version is the variable 'vmajor' you see here.
---------------------------------------------------------------------------
local vmajor, vminor = "1.1", tonumber(string.sub("$Revision: 28229 $", 12, -3))

local stubvarname = "TekLibStub"
local libvarname = "ParserLib"

local _G = getfenv(0)

-- Check to see if an update is needed
-- if not then just return out now before we do anything
local libobj = _G[libvarname]
if libobj and not libobj:NeedsUpgraded(vmajor, vminor) then return end

local print = _G.print
if not print then
	print = function(msg)
		ChatFrame1:AddMessage(string.format("<%s-%s-%s> %s", libvarname, vmajor, vminor, msg))
	end
end

---------------------------------------------------------------------------
-- Embedded Library Registration Stub
-- Written by Iriel <iriel@vigilance-committee.org>
-- Version 0.1 - 2006-03-05
-- Modified by Tekkub <tekkub@gmail.com>
---------------------------------------------------------------------------

local stubobj = _G[stubvarname]
if not stubobj then
	stubobj = {}
	setglobal(stubvarname, stubobj)

	-- Instance replacement method, replace contents of old with that of new
	function stubobj:ReplaceInstance(old, new)
		for k,v in pairs(old) do old[k]=nil end
		for k,v in pairs(new) do old[k]=v end
	end

	-- Get a new copy of the stub
	function stubobj:NewStub(name)
		local newStub = {}
		self:ReplaceInstance(newStub, self)
		newStub.libName = name
		newStub.lastVersion = ''
		newStub.versions = {}
		return newStub
	end

	-- Get instance version
	function stubobj:NeedsUpgraded(vmajor, vminor)
		local versionData = self.versions[vmajor]
		if not versionData or versionData.minor < vminor then return true end
	end

	-- Get instance version
	function stubobj:GetInstance(version)
		if not version then version = self.lastVersion end
		local versionData = self.versions[version]
		if not versionData then print(string.format("<%s> Cannot find library version: %s", self.libName, version or "")) return end
		return versionData.instance
	end

	-- Register new instance
	function stubobj:Register(newInstance)
		local version,minor = newInstance:GetLibraryVersion()
		self.lastVersion = version
		local versionData = self.versions[version]
		if not versionData then
				-- This one is new!
				versionData = {
					instance = newInstance,
					minor = minor,
					old = {},
				}
				self.versions[version] = versionData
				newInstance:LibActivate(self)
				return newInstance
		end
		-- This is an update
		local oldInstance = versionData.instance
		local oldList = versionData.old
		versionData.instance = newInstance
		versionData.minor = minor
		local skipCopy = newInstance:LibActivate(self, oldInstance, oldList)
		table.insert(oldList, oldInstance)
		if not skipCopy then
				for i, old in ipairs(oldList) do self:ReplaceInstance(old, newInstance) end
		end
		return newInstance
	end
end

if not libobj then
	libobj = stubobj:NewStub(libvarname)
	setglobal(libvarname, libobj)
end

local lib = {}

-- Return the library's current version
function lib:GetLibraryVersion()
	return vmajor, vminor
end

-- Activate a new instance of this library
function lib:LibActivate(stub, oldLib, oldList)
	local maj, min = self:GetLibraryVersion()

	if oldLib then
		local omaj, omin = oldLib:GetLibraryVersion()
		----------------------------------------------------
		-- ********************************************** --
		-- **** Copy over any old data you need here **** --
		-- ********************************************** --
		----------------------------------------------------
		self.frame = oldLib.frame
		self:OnLoad()
		
		if omin < 11 then
			if oldLib.clients then
				for event, list in pairs(oldLib.clients) do
					for i, t in ipairs(list) do
						if type(t.func) == "sting" then
							t.func = _G[t.func]
						end
					end
				end
			end
		end
		
		if omin < 28100 then
			if oldLib.clients then
				for event, list in pairs(oldLib.clients) do
					for i, t in ipairs(list) do
						if t.id and t.func then
							if not clients[event] then
								clients[event] = {}
							end
							clients[event][t.id] = t.func
						end
					end
				end
			end
		end
			
	else
		---------------------------------------------------
		-- ********************************************* --
		-- **** Do any initialization you need here **** --
		-- ********************************************* --
		---------------------------------------------------
		self:OnLoad()
	end
	-- nil return makes stub do object copy
end


-- Global Constants
ParserLib_SELF = 103
ParserLib_MELEE = 112
ParserLib_DAMAGESHIELD = 113

local eventTable
local eventTableLocale
local trailers
local keywordTable = nil

-- Starts out empty, load the data only when required.
local patternTable = {}

-- Client event handlers.
local clients = {}

-- Store parsed result.
local info = {}
local rInfo = {}

	
-- Fields of the patternTable.
local infoMap = {
	hit = { "source", "victim", "skill", "amount", "element", "isCrit", "isDOT", "isSplit" },
	heal = { "source", "victim", "skill", "amount", "isCrit", "isDOT" },
	miss = { "source", "victim", "skill", "missType" },
	death = { "victim", "source", "skill", "isItem" },
	debuff = { "victim", "skill", "amountRank" },
	buff = { "victim", "skill", "amountRank" },
	fade = { "victim", "skill" },
	cast = { "source", "skill", "victim", "isBegin", "isPerform" },
	gain = { "source", "victim", "skill", "amount", "attribute" },
	drain = { "source", "victim", "skill", "amount", "attribute" },
	leech = { "source", "victim", "skill", "amount", "attribute", "sourceGained", "amountGained", "attributeGained" },
	dispel = { "victim", "skill", "source", "isFailed" },
	extraattack = { "victim", "skill", "amount" },
	environment = { "victim", "amount", "damageType" },
	experience = { "amount", "source", "bonusAmount", "bonusType", "penaltyAmount", "penaltyType", "amountRaidPenalty", "amountGroupBonus", "victim" },
	reputation = { "faction", "amount", "rank", "isNegative" },
	feedpet = { "victim", "item" },
	enchant = { "source", "victim", "skill", "item" },
	fail = { "source", "skill", "reason" },
	interrupt = { "source", "victim", "skill" },
	create = { "source", "item" },
	honor = { "amount", "source", "sourceRank" }, -- if amount == nil then isDishonor = true.
	durability = { "source", "skill", "victim", "item" }, -- is not item then isAllItems = true
	unknown = { "message" },
}

local ConvertPattern
local ConvertType
local Curry
local FindPattern
local GenerateKeywordTable
local LoadEverything
local LoadPatternInfo
local MapPatternInfo
local NotifyClients
local ParseMessage
local ParseTrailers
local PatternCompare
local SortEventTables
local TestKeywordTable

-- Register an event to ParserLib.
function lib:RegisterEvent(addonID, event, handler)

		
	if eventTable[event] and addonID then
			
		if type(handler) == "string" then
			handler = _G[handler]
		end
		
		if not handler then
			error('Usage: RegisterEvent(addonID, "event", handler or "handler")')
		end
		
		if not clients[event] then
			clients[event] = {}
		end
		
		clients[event][addonID] = handler
		self.frame:RegisterEvent(event)
		
	end


end

-- Check if you have registered an event.
function lib:IsEventRegistered(addonID, event)
	return ( clients[event] and clients[event][addonID] )
end

-- Unregister an event.
function lib:UnregisterEvent(addonID, event)
	if clients[event] and clients[event][addonID] then
		clients[event][addonID] = nil
		if not next(clients[event]) then
			self.frame:UnregisterEvent(event)
		end
	end
end

-- Unregister all events.
function lib:UnregisterAllEvents(addonID)
	for event in pairs(clients) do
		self:UnregisterEvent(addonID, event)
	end
end

local customPatterns = {}
-- Parse custom messages, check documentation.html for more info.
function lib:Deformat(text, pattern)
	if not customPatterns[pattern] then
		customPatterns[pattern] = Curry(pattern)
	end
	return customPatterns[pattern](text)
end

function lib:OnLoad()

	if eventTableLocale ~= GetLocale() then
		SortEventTables()
	end
	
	if not self.frame then
		self.frame = CreateFrame("Frame", "ParserLibFrame")
		self.frame:SetScript("OnEvent", function() self:OnEvent() end )
		self.frame:Hide()
	end
	
	
	GenerateKeywordTable()
	TestKeywordTable()
	
	-- A read-only table for sending to clients.
	rInfo = setmetatable( rInfo, {
		__index = function(_, k)
			return info[k]
		end,
		__newindex = function()
			-- You cannot modify the table!
		end
	} )
	
	-- Make local variables accessable from external scope.
	self.eventTable = eventTable
	self.patternTable = patternTable
	self.infoMap = infoMap
	self.trailers = trailers
	self.keywordTable = keywordTable
	self.info = info
	self.rInfo = rInfo	
	self.clients = clients
	
	self.ConvertPattern = ConvertPattern
	self.ConvertType = ConvertType
	self.Curry = Curry	
	self.FindPattern = FindPattern
	self.GenerateKeywordTable = GenerateKeywordTable
	self.LoadEverything = LoadEverything
	self.LoadPatternInfo = LoadPatternInfo
	self.MapPatternInfo = MapPatternInfo
	self.NotifyClients = NotifyClients
	self.ParseMessage = ParseMessage
	self.ParseTrailers = ParseTrailers
	self.PatternCompare = PatternCompare
	self.SortEventTables = SortEventTables
	self.TestKeywordTable = TestKeywordTable

end

function lib:OnEvent(e, a1)

	if not e then e = _G['event'] end
	if not a1 then a1 = _G['arg1'] end
	
	ParseMessage(a1, e)
	NotifyClients(e)
	
end

-- Map parsed tokens (from) into a hash table (to) with the patternInfo.
function MapPatternInfo(from, to, patternInfo)
	local field
	
	local infoType = patternInfo[1]
	
	to.type = infoType
	for i=2, #patternInfo do
		field = infoMap[infoType][i-1]
		to[field] = from[patternInfo[i]] or patternInfo[i]
	end
	
	if infoType == "honor" and not to.amount then
		to.isDishonor = true

	elseif infoType == "durability" and not to.item then
		to.isAllItems = true
	end
	
end

function NotifyClients(event)
	if clients and clients[event] then
		for addonID, handler in pairs(clients[event]) do
			local success, ret = pcall(handler, event, rInfo)
			if not success then
				geterrorhandler()(ret)
			end			
		end
	end
end

-- Sort the pattern so that they can be parsed in a correct sequence, will only do once for each registered event.
function PatternCompare(a, b)

	local pa = _G[a]
	local pb = _G[b]
	
	if pa and not pb then
		return true
	elseif pb and not pa then
		return false
	elseif not pa and not pb then
		return a < b
	else
		local ca=0
		for _ in pa:gmatch("%%%d?%$?[sd]") do ca=ca+1 end
		local cb=0
		for _ in pb:gmatch("%%%d?%$?[sd]") do cb=cb+1 end

		pa = pa:gsub("%%%d?%$?[sd]", "")
		pb = pb:gsub("%%%d?%$?[sd]", "")

		if pa:len() == pb:len() then
			return ca < cb
		else
			return pa:len() > pb:len()
		end
	end
	
end

local FindString = {
	[0] = function(m,p,t) _,pos = m:find(p) if pos then return pos end end,
	[1] = function(m,p,t) _,pos,t[1] = m:find(p) if t[1] then return pos end end,
	[2] = function(m,p,t) _,pos,t[1],t[2] = m:find(p) if t[2] then return pos end end,
	[3] = function(m,p,t) _,pos,t[1],t[2],t[3] = m:find(p) if t[3] then return pos end end,
	[4] = function(m,p,t) _,pos,t[1],t[2],t[3],t[4] = m:find(p) if t[4] then return pos end end,
	[5] = function(m,p,t) _,pos,t[1],t[2],t[3],t[4],t[5] = m:find(p) if t[5] then return pos end end,
	[6] = function(m,p,t) _,pos,t[1],t[2],t[3],t[4],t[5],t[6] = m:find(p) if t[6] then return pos end end,
	[7] = function(m,p,t) _,pos,t[1],t[2],t[3],t[4],t[5],t[6],t[7] = m:find(p) if t[7] then return pos end end,
	[8] = function(m,p,t) _,pos,t[1],t[2],t[3],t[4],t[5],t[6],t[7],t[8] = m:find(p) if t[8] then return pos end end,
	[9] = function(m,p,t) _,pos,t[1],t[2],t[3],t[4],t[5],t[6],t[7],t[8],t[9] = m:find(p) if t[9] then return pos end end,
}

--[[
if GetLocale() == "enUS" then
	keywordTable = {
		AURAADDEDOTHERHARMFUL = "afflict",
		AURAADDEDOTHERHELPFUL = "gain",
		AURAADDEDSELFHARMFUL = "afflict",
		AURAADDEDSELFHELPFUL = "gain",
		AURAAPPLICATIONADDEDOTHERHARMFUL = "afflict",
		AURAAPPLICATIONADDEDOTHERHELPFUL = "gain",
		AURAAPPLICATIONADDEDSELFHARMFUL = "afflict",
		AURAAPPLICATIONADDEDSELFHELPFUL = "gain",
		AURADISPELOTHER = "remove",
		AURADISPELSELF = "remove",
		AURAREMOVEDOTHER = "fade",
		AURAREMOVEDSELF = "fade",
		COMBATHITCRITOTHEROTHER = "crit",
		COMBATHITCRITOTHERSELF = "crit",
		COMBATHITCRITSELFOTHER = "crit",
		COMBATHITCRITSELFSELF = "crit",
		COMBATHITCRITSCHOOLOTHEROTHER = "crit",
		COMBATHITCRITSCHOOLOTHERSELF = "crit",
		COMBATHITCRITSCHOOLSELFOTHER = "crit",
		COMBATHITCRITSCHOOLSELFSELF = "crit",
		COMBATHITOTHEROTHER = "hit",
		COMBATHITOTHERSELF = "hit",
		COMBATHITSELFOTHER = "hit",
		COMBATHITSELFSELF = "hit",
		COMBATHITSCHOOLOTHEROTHER = "hit",
		COMBATHITSCHOOLOTHERSELF = "hit",
		COMBATHITSCHOOLSELFOTHER = "hit",
		COMBATHITSCHOOLSELFSELF = "hit",
		DAMAGESHIELDOTHEROTHER = "reflect",
		DAMAGESHIELDOTHERSELF = "reflect",
		DAMAGESHIELDSELFOTHER = "reflect",
		DISPELFAILEDOTHEROTHER = "fail",
		DISPELFAILEDOTHERSELF = "fail",
		DISPELFAILEDSELFOTHER = "fail",
		DISPELFAILEDSELFSELF = "fail",
		HEALEDCRITOTHEROTHER = "crit",
		HEALEDCRITOTHERSELF = "crit",
		HEALEDCRITSELFOTHER = "crit",
		HEALEDCRITSELFSELF = "crit",
		HEALEDOTHEROTHER = "heal",
		HEALEDOTHERSELF = "heal",
		HEALEDSELFOTHER = "heal",
		HEALEDSELFSELF = "heal",
		IMMUNESPELLOTHEROTHER = "immune",
		IMMUNESPELLSELFOTHER = "immune",
		IMMUNESPELLOTHERSELF = "immune",
		IMMUNESPELLSELFSELF = "immune",
		ITEMENCHANTMENTADDOTHEROTHER = "cast",
		ITEMENCHANTMENTADDOTHERSELF = "cast",
		ITEMENCHANTMENTADDSELFOTHER = "cast",
		ITEMENCHANTMENTADDSELFSELF = "cast",
		MISSEDOTHEROTHER = "miss",
		MISSEDOTHERSELF = "miss",
		MISSEDSELFOTHER = "miss",
		MISSEDSELFSELF = "miss",
		OPEN_LOCK_OTHER = "perform",
		OPEN_LOCK_SELF = "perform",
		PARTYKILLOTHER = "slain",
		PERIODICAURADAMAGEOTHEROTHER = "suffer",
		PERIODICAURADAMAGEOTHERSELF = "suffer",
		PERIODICAURADAMAGESELFOTHER = "suffer",
		PERIODICAURADAMAGESELFSELF = "suffer",
		PERIODICAURAHEALOTHEROTHER = "gain",
		PERIODICAURAHEALOTHERSELF = "gain",
		PERIODICAURAHEALSELFOTHER = "gain",
		PERIODICAURAHEALSELFSELF = "gain",
		POWERGAINOTHEROTHER = "gain",
		POWERGAINOTHERSELF = "gain",
		POWERGAINSELFSELF = "gain",
		POWERGAINSELFOTHER = "gain",
		PROCRESISTOTHEROTHER = "resist",
		PROCRESISTOTHERSELF = "resist",
		PROCRESISTSELFOTHER = "resist",
		PROCRESISTSELFSELF = "resist",
		SIMPLECASTOTHEROTHER = "cast",
		SIMPLECASTOTHERSELF = "cast",
		SIMPLECASTSELFOTHER = "cast",
		SIMPLECASTSELFSELF = "cast",
		SIMPLEPERFORMOTHEROTHER = "perform",
		SIMPLEPERFORMOTHERSELF = "perform",
		SIMPLEPERFORMSELFOTHER = "perform",
		SIMPLEPERFORMSELFSELF = "perform",
		SPELLBLOCKEDOTHEROTHER = "block",
		SPELLBLOCKEDOTHERSELF = "block",
		SPELLBLOCKEDSELFOTHER = "block",
		SPELLBLOCKEDSELFSELF = "block",
		SPELLCASTOTHERSTART = "begin",
		SPELLCASTSELFSTART = "begin",
		SPELLDEFLECTEDOTHEROTHER = "deflect",
		SPELLDEFLECTEDOTHERSELF = "deflect",
		SPELLDEFLECTEDSELFOTHER = "deflect",
		SPELLDEFLECTEDSELFSELF = "deflect",
		SPELLDODGEDOTHEROTHER = "dodge",
		SPELLDODGEDOTHERSELF = "dodge",
		SPELLDODGEDSELFOTHER = "dodge",
		SPELLEVADEDOTHEROTHER = "evade",
		SPELLEVADEDOTHERSELF = "evade",
		SPELLEVADEDSELFOTHER = "evade",
		SPELLEVADEDSELFSELF = "evade",
		SPELLEXTRAATTACKSOTHER = "extra",
		SPELLEXTRAATTACKSOTHER_SINGULAR = "extra",
		SPELLEXTRAATTACKSSELF = "extra",
		SPELLEXTRAATTACKSSELF_SINGULAR = "extra",
		SPELLFAILCASTSELF = "fail",
		SPELLFAILPERFORMSELF = "fail",
		SPELLIMMUNEOTHEROTHER = "immune",
		SPELLIMMUNEOTHERSELF = "immune",
		SPELLIMMUNESELFOTHER = "immune",
		SPELLIMMUNESELFSELF = "immune",
		SPELLINTERRUPTOTHEROTHER = "interrupt",
		SPELLINTERRUPTOTHERSELF = "interrupt",
		SPELLINTERRUPTSELFOTHER = "interrupt",
		SPELLLOGABSORBOTHEROTHER = "absorb",
		SPELLLOGABSORBOTHERSELF = "absorb",
		SPELLLOGABSORBSELFOTHER = "absorb",
		SPELLLOGABSORBSELFSELF = "absorb",
		SPELLLOGCRITOTHEROTHER = "crit",
		SPELLLOGCRITOTHERSELF = "crit",
		SPELLLOGCRITSCHOOLOTHEROTHER = "crit",
		SPELLLOGCRITSCHOOLOTHERSELF = "crit",
		SPELLLOGCRITSCHOOLSELFOTHER = "crit",
		SPELLLOGCRITSCHOOLSELFSELF = "crit",
		SPELLLOGCRITSELFOTHER = "crit",
		SPELLLOGOTHEROTHER = "hit",
		SPELLLOGOTHERSELF = "hit",
--		SPELLLOGOTHERSELF = "hit", -- Duplicated
		SPELLLOGSCHOOLOTHEROTHER = "hit",
		SPELLLOGSCHOOLOTHERSELF = "hit",
		SPELLLOGSCHOOLSELFOTHER = "hit",
		SPELLLOGSCHOOLSELFSELF = "hit",
		SPELLLOGSELFOTHER = "hit",
		SPELLMISSOTHEROTHER = "miss",
		SPELLMISSOTHERSELF = "miss",
		SPELLMISSSELFOTHER = "miss",
		SPELLPARRIEDOTHEROTHER = "parr",
		SPELLPARRIEDOTHERSELF = "parr",
		SPELLPARRIEDSELFOTHER = "parr",
		SPELLPERFORMOTHERSTART = "begin",
		SPELLPERFORMSELFSTART = "begin",
		SPELLPOWERDRAINOTHEROTHER = "drain",
		SPELLPOWERDRAINOTHERSELF = "drain",
		SPELLPOWERDRAINSELFOTHER = "drain",
		SPELLPOWERLEECHOTHEROTHER = "drain",
		SPELLPOWERLEECHOTHERSELF = "drain",
		SPELLPOWERLEECHSELFOTHER = "drain",
		SPELLREFLECTOTHEROTHER = "reflect",
		SPELLREFLECTOTHERSELF = "reflect",
		SPELLREFLECTSELFOTHER = "reflect",
		SPELLREFLECTSELFSELF = "reflect",
		SPELLRESISTOTHEROTHER = "resist",
		SPELLRESISTOTHERSELF = "resist",
		SPELLRESISTSELFOTHER = "resist",
		SPELLRESISTSELFSELF = "resist",
		SPELLSPLITDAMAGESELFOTHER = "cause",
		SPELLSPLITDAMAGEOTHEROTHER = "cause",
		SPELLSPLITDAMAGEOTHERSELF = "cause",
		SPELLTERSEPERFORM_OTHER = "perform",
		SPELLTERSEPERFORM_SELF = "perform",
		SPELLTERSE_OTHER = "cast",
		SPELLTERSE_SELF = "cast",
		VSABSORBOTHEROTHER = "absorb",
		VSABSORBOTHERSELF = "absorb",
		VSABSORBSELFOTHER = "absorb",
		VSBLOCKOTHEROTHER = "block",
		VSBLOCKOTHERSELF = "block",
		VSBLOCKSELFOTHER = "block",
		VSBLOCKSELFSELF = "block",
		VSDEFLECTOTHEROTHER = "deflect",
		VSDEFLECTOTHERSELF = "deflect",
		VSDEFLECTSELFOTHER = "deflect",
		VSDEFLECTSELFSELF = "deflect",
		VSDODGEOTHEROTHER = "dodge",
		VSDODGEOTHERSELF = "dodge",
		VSDODGESELFOTHER = "dodge",
		VSDODGESELFSELF = "dodge",
		VSENVIRONMENTALDAMAGE_FALLING_OTHER = "fall",
		VSENVIRONMENTALDAMAGE_FALLING_SELF = "fall",
		VSENVIRONMENTALDAMAGE_FIRE_OTHER = "fire",
		VSENVIRONMENTALDAMAGE_FIRE_SELF = "fire",
		VSENVIRONMENTALDAMAGE_LAVA_OTHER = "lava",
		VSENVIRONMENTALDAMAGE_LAVA_SELF = "lava",
		VSEVADEOTHEROTHER = "evade",
		VSEVADEOTHERSELF = "evade",
		VSEVADESELFOTHER = "evade",
		VSEVADESELFSELF = "evade",
		VSIMMUNEOTHEROTHER = "immune",
		VSIMMUNEOTHERSELF = "immune",
		VSIMMUNESELFOTHER = "immune",
		VSPARRYOTHEROTHER = "parr",
		VSPARRYOTHERSELF = "parr",
		VSPARRYSELFOTHER = "parr",
		VSRESISTOTHEROTHER = "resist",
		VSRESISTOTHERSELF = "resist",
		VSRESISTSELFOTHER = "resist",
		VSRESISTSELFSELF = "resist",
		VSENVIRONMENTALDAMAGE_FATIGUE_OTHER = "exhaust",
		VSENVIRONMENTALDAMAGE_FIRE_OTHER = "fire",
		VSENVIRONMENTALDAMAGE_SLIME_OTHER = "slime",
		VSENVIRONMENTALDAMAGE_SLIME_SELF = "slime",
		VSENVIRONMENTALDAMAGE_DROWNING_OTHER = "drown",
		UNITDIESSELF = "die",
		UNITDIESOTHER = "die",
		UNITDESTROYEDOTHER = "destroy",
	}

elseif GetLocale() == "koKR" then

	keywordTable = {
		AURAADDEDOTHERHARMFUL = "걸렸습니다.",
		AURAADDEDOTHERHELPFUL = "효과를 얻었습니다.",
		AURAADDEDSELFHARMFUL = "걸렸습니다.",
		AURAADDEDSELFHELPFUL = "효과를 얻었습니다.",
		AURAAPPLICATIONADDEDOTHERHARMFUL = "걸렸습니다. (%d)",
		AURAAPPLICATIONADDEDOTHERHELPFUL = "효과를 얻었습니다. (%d)",
		AURAAPPLICATIONADDEDSELFHARMFUL = "걸렸습니다. (%d)",
		AURAAPPLICATIONADDEDSELFHELPFUL = "효과를 얻었습니다. (%d)",
		AURADISPELOTHER = "제거되었습니다.",
		AURADISPELSELF = "제거되었습니다.",
		AURAREMOVEDOTHER = "효과가 사라졌습니다.",
		AURAREMOVEDSELF = "효과가 사라졌습니다.",
		COMBATHITCRITOTHEROTHER = "치명상 피해를 입혔습니다.",
		COMBATHITCRITOTHERSELF = "치명상 피해를 입혔습니다.",
		COMBATHITCRITSELFOTHER = "치명상 피해를 입혔습니다.",
		--COMBATHITCRITSELFSELF = "crit",
		COMBATHITCRITSCHOOLOTHEROTHER = "치명상 피해를 입혔습니다.",
		COMBATHITCRITSCHOOLOTHERSELF = "치명상 피해를 입혔습니다.",
		COMBATHITCRITSCHOOLSELFOTHER = "치명상 피해를 입혔습니다.",
		--COMBATHITCRITSCHOOLSELFSELF = "crit",
		COMBATHITOTHEROTHER = "피해를 입혔습니다.",
		COMBATHITOTHERSELF = "피해를 입혔습니다.",
		COMBATHITSELFOTHER = "피해를 입혔습니다.",
		--COMBATHITSELFSELF = "hit",
		COMBATHITSCHOOLOTHEROTHER = "피해를 입혔습니다.",
		COMBATHITSCHOOLOTHERSELF = "피해를 입혔습니다.",
		COMBATHITSCHOOLSELFOTHER = "피해를 입혔습니다.",
		--COMBATHITSCHOOLSELFSELF = "hit",
		DAMAGESHIELDOTHEROTHER = "반사했습니다.",
		DAMAGESHIELDOTHERSELF = "반사했습니다.",
		DAMAGESHIELDSELFOTHER = "반사했습니다.",
		DISPELFAILEDOTHEROTHER = "무효화하지 못했습니다.",
		DISPELFAILEDOTHERSELF = "무효화하지 못했습니다.",
		DISPELFAILEDSELFOTHER = "무효화하지 못했습니다.",
		DISPELFAILEDSELFSELF = "무효화하지 못했습니다.",
		HEALEDCRITOTHEROTHER = "극대화 효과를 발휘하여",
		HEALEDCRITOTHERSELF = "극대화 효과를 발휘하여 당신의 생명력이",
		HEALEDCRITSELFOTHER = "극대화 효과를 발휘하여",
		HEALEDCRITSELFSELF = "극대화 효과를 발휘하여 생명력이",
		HEALEDOTHEROTHER = "회복되었습니다.",
		HEALEDOTHERSELF = "회복되었습니다.",
		HEALEDSELFOTHER = "회복되었습니다.",
		HEALEDSELFSELF = "회복되었습니다.",
		IMMUNESPELLOTHEROTHER = "면역입니다.",
		IMMUNESPELLSELFOTHER = "면역입니다.",
		IMMUNESPELLOTHERSELF = "면역입니다.",
		IMMUNESPELLSELFSELF = "면역입니다.",
		ITEMENCHANTMENTADDOTHEROTHER = "사용합니다.",
		ITEMENCHANTMENTADDOTHERSELF = "사용합니다.",
		ITEMENCHANTMENTADDSELFOTHER = "사용합니다.",
		ITEMENCHANTMENTADDSELFSELF = "시전합니다.",
		MISSEDOTHEROTHER = "공격했지만 적중하지 않았습니다.",
		MISSEDOTHERSELF = "당신을 공격했지만 적중하지 않았습니다.",
		MISSEDSELFOTHER = "공격했지만 적중하지 않았습니다.",
		--MISSEDSELFSELF = "miss",
		OPEN_LOCK_OTHER = "사용했습니다.",
		OPEN_LOCK_SELF = "사용했습니다.",
		PARTYKILLOTHER = "죽였습니다!",
		PERIODICAURADAMAGEOTHEROTHER = "피해를 입었습니다.",
		PERIODICAURADAMAGEOTHERSELF = "피해를 입었습니다.",
		PERIODICAURADAMAGESELFOTHER = "피해를 입었습니다.",
		PERIODICAURADAMAGESELFSELF = "피해를 입었습니다.",
		PERIODICAURAHEALOTHEROTHER = "만큼 회복되었습니다.",
		PERIODICAURAHEALOTHERSELF = "만큼 회복되었습니다.",
		PERIODICAURAHEALSELFOTHER = "만큼 회복되었습니다.",
		PERIODICAURAHEALSELFSELF = "만큼 회복되었습니다.",
		POWERGAINOTHEROTHER = "얻었습니다.",
		POWERGAINOTHERSELF = "얻었습니다.",
		POWERGAINSELFSELF = "얻었습니다.",
		POWERGAINSELFOTHER = "얻었습니다.",
		PROCRESISTOTHEROTHER = "저항했습니다.",
		PROCRESISTOTHERSELF = "저항했습니다.",
		PROCRESISTSELFOTHER = "저항했습니다.",
		PROCRESISTSELFSELF = "저항했습니다.",
		SIMPLECASTOTHEROTHER = "시전합니다.",
		SIMPLECASTOTHERSELF = "시전합니다.",
		SIMPLECASTSELFOTHER = "시전합니다.",
		SIMPLECASTSELFSELF = "시전합니다.",
		SIMPLEPERFORMOTHEROTHER = "사용했습니다.",
		SIMPLEPERFORMOTHERSELF = "사용했습니다.",
		SIMPLEPERFORMSELFOTHER = "사용했습니다.",
		SIMPLEPERFORMSELFSELF = "사용했습니다.",
		SPELLBLOCKEDOTHEROTHER = "공격했지만 방어했습니다.",
		SPELLBLOCKEDOTHERSELF = "공격했지만 방어했습니다.",
		SPELLBLOCKEDSELFOTHER = "공격했지만 방어했습니다.",
		--SPELLBLOCKEDSELFSELF = "block",
		SPELLCASTOTHERSTART = "시전을 시작합니다.",
		SPELLCASTSELFSTART = "시전을 시작합니다.",
		SPELLDEFLECTEDOTHEROTHER = "공격했지만 빗맞았습니다.",
		SPELLDEFLECTEDOTHERSELF = "공격했지만 빗맞았습니다.",
		SPELLDEFLECTEDSELFOTHER = "공격했지만 빗맞았습니다.",
		SPELLDEFLECTEDSELFSELF = "흘려보냈습니다.",
		SPELLDODGEDOTHEROTHER = "공격했지만 교묘히 피했습니다.",
		SPELLDODGEDOTHERSELF = "공격했지만 교묘히 피했습니다.",
		SPELLDODGEDSELFOTHER = "공격했지만 교묘히 피했습니다.",
		SPELLEVADEDOTHEROTHER = "공격했지만 빗나갔습니다.",
		SPELLEVADEDOTHERSELF = "공격했지만 빗나갔습니다.",
		SPELLEVADEDSELFOTHER = "공격했지만 빗나갔습니다.",
		SPELLEVADEDSELFSELF = "피했습니다.",
		SPELLEXTRAATTACKSOTHER = "추가 공격 기회를 얻었습니다.",
		SPELLEXTRAATTACKSOTHER_SINGULAR = "추가 공격 기회를 얻었습니다.",
		SPELLEXTRAATTACKSSELF = "추가 공격 기회를 얻었습니다.",
		SPELLEXTRAATTACKSSELF_SINGULAR = "추가 공격 기회를 얻었습니다.",
		SPELLFAILCASTSELF = "시전을 실패했습니다:",
		SPELLFAILPERFORMSELF = "사용을 실패했습니다:",
		SPELLIMMUNEOTHEROTHER = "면역입니다.",
		SPELLIMMUNEOTHERSELF = "당신은 면역입니다.",
		SPELLIMMUNESELFOTHER = "면역입니다.",
		SPELLIMMUNESELFSELF = "당신은 면역입니다.",
		SPELLINTERRUPTOTHEROTHER = "차단했습니다.",
		SPELLINTERRUPTOTHERSELF = "차단했습니다.",
		SPELLINTERRUPTSELFOTHER = "차단했습니다.",
		SPELLLOGABSORBOTHEROTHER = "흡수했습니다.",
		SPELLLOGABSORBOTHERSELF = "흡수했습니다.",
		SPELLLOGABSORBSELFOTHER = "흡수했습니다.",
		SPELLLOGABSORBSELFSELF = "흡수했습니다.",
		SPELLLOGCRITOTHEROTHER = "치명상 피해를 입혔습니다.",
		SPELLLOGCRITOTHERSELF = "치명상 피해를 입혔습니다.",
		SPELLLOGCRITSCHOOLOTHEROTHER = "치명상 피해를 입혔습니다.",
		SPELLLOGCRITSCHOOLOTHERSELF = "치명상 피해를 입혔습니다.",
		SPELLLOGCRITSCHOOLSELFOTHER = "치명상 피해를 입혔습니다.",
		SPELLLOGCRITSCHOOLSELFSELF = "치명상 피해를 입었습니다.",
		SPELLLOGCRITSELFOTHER = "치명상 피해를 입혔습니다.",
		SPELLLOGOTHEROTHER = "피해를 입혔습니다.",
		SPELLLOGOTHERSELF = "피해를 입혔습니다.",
--		SPELLLOGOTHERSELF = "피해를 입혔습니다.", -- Duplicated
		SPELLLOGSCHOOLOTHEROTHER = "피해를 입혔습니다.",
		SPELLLOGSCHOOLOTHERSELF = "피해를 입혔습니다.",
		SPELLLOGSCHOOLSELFOTHER = "피해를 입혔습니다.",
		SPELLLOGSCHOOLSELFSELF = "피해를 입었습니다.",
		SPELLLOGSELFOTHER = "피해를 입혔습니다.",
		SPELLMISSOTHEROTHER = "공격했지만 적중하지 않았습니다.",
		SPELLMISSOTHERSELF = "공격했지만 적중하지 않았습니다.",
		SPELLMISSSELFOTHER = "공격했지만 적중하지 않았습니다.",
		SPELLPARRIEDOTHEROTHER = "공격했지만 막았습니다.",
		SPELLPARRIEDOTHERSELF = "공격했지만 막았습니다.",
		SPELLPARRIEDSELFOTHER = "공격했지만 막았습니다.",
		SPELLPERFORMOTHERSTART = "사용을 시작합니다.",
		SPELLPERFORMSELFSTART = "사용을 시작합니다.",
		SPELLPOWERDRAINOTHEROTHER = "소진시켰습니다.",
		SPELLPOWERDRAINOTHERSELF = "소진시켰습니다.",
		SPELLPOWERDRAINSELFOTHER = "소진시켰습니다.",
		SPELLPOWERLEECHOTHEROTHER = "소진시켰습니다.",
		SPELLPOWERLEECHOTHERSELF = "소진시켰습니다.",
		SPELLPOWERLEECHSELFOTHER = "소진시켰습니다.",
		SPELLREFLECTOTHEROTHER = "공격했지만 반사했습니다.",
		SPELLREFLECTOTHERSELF = "반사했습니다.",
		SPELLREFLECTSELFOTHER = "공격했지만 반사했습니다.",
		SPELLREFLECTSELFSELF = "반사했습니다.",
		SPELLRESISTOTHEROTHER = "공격했지만 저항했습니다.",
		SPELLRESISTOTHERSELF = "공격했지만 저항했습니다.",
		SPELLRESISTSELFOTHER = "공격했지만 저항했습니다.",
		SPELLRESISTSELFSELF = "저항했습니다.",
		SPELLSPLITDAMAGESELFOTHER = "피해를 입혔습니다.",
		SPELLSPLITDAMAGEOTHEROTHER = "피해를 입혔습니다.",
		SPELLSPLITDAMAGEOTHERSELF = "피해를 입혔습니다.",
		SPELLTERSEPERFORM_OTHER = "사용했습니다.",
		SPELLTERSEPERFORM_SELF = "사용했습니다.",
		SPELLTERSE_OTHER = "시전합니다.",
		SPELLTERSE_SELF = "시전합니다.",
		VSABSORBOTHEROTHER = "공격했지만 모든 피해를 흡수했습니다.",
		VSABSORBOTHERSELF = "당신을 공격했지만 모든 피해를 흡수했습니다.",
		VSABSORBSELFOTHER = "공격했지만 모든 피해를 흡수했습니다.",
		VSBLOCKOTHEROTHER = "공격했지만 방어했습니다.",
		VSBLOCKOTHERSELF = "당신을 공격했지만 방어했습니다.",
		VSBLOCKSELFOTHER = "공격했지만 방어했습니다.",
		--VSBLOCKSELFSELF = "block",
		VSDEFLECTOTHEROTHER = "공격했지만 빗맞았습니다.",
		VSDEFLECTOTHERSELF = "당신을 공격했지만 빗맞았습니다.",
		VSDEFLECTSELFOTHER = "공격했지만 빗맞았습니다.",
		--VSDEFLECTSELFSELF = "deflect",
		VSDODGEOTHEROTHER = "공격했지만 교묘히 피했습니다.",
		VSDODGEOTHERSELF = "당신을 공격했지만 교묘히 피했습니다.",
		VSDODGESELFOTHER = "공격했지만 교묘히 피했습니다.",
		--VSDODGESELFSELF = "dodge",
		VSENVIRONMENTALDAMAGE_FALLING_OTHER = "낙하할 때의 충격으로",
		VSENVIRONMENTALDAMAGE_FALLING_SELF = "당신은 낙하할 때의 충격으로",
		VSENVIRONMENTALDAMAGE_FIRE_OTHER = "화염 피해를 입었습니다.",
		VSENVIRONMENTALDAMAGE_FIRE_SELF = "화염 피해를 입었습니다.",
		VSENVIRONMENTALDAMAGE_LAVA_OTHER = "용암의 열기로 인해",
		VSENVIRONMENTALDAMAGE_LAVA_SELF = "당신은 용암의 열기로 인해",
		VSEVADEOTHEROTHER = "공격했지만 빗나갔습니다.",
		VSEVADEOTHERSELF = "당신을 공격했지만 빗나갔습니다.",
		VSEVADESELFOTHER = "공격했지만 빗나갔습니다.",
		--VSEVADESELFSELF = "evade",
		VSIMMUNEOTHEROTHER = "공격했지만 면역입니다.",
		VSIMMUNEOTHERSELF = "당신을 공격했지만 면역입니다.",
		VSIMMUNESELFOTHER = "공격했지만 면역입니다.",
		VSPARRYOTHEROTHER = "공격했지만 막았습니다.",
		VSPARRYOTHERSELF = "당신을 공격했지만 막았습니다.",
		VSPARRYSELFOTHER = "공격했지만 막았습니다.",
		VSRESISTOTHEROTHER = "공격했지만 모든 피해를 저항했습니다.",
		VSRESISTOTHERSELF = "당신을 공격했지만 모든 피해를 저항했습니다.",
		VSRESISTSELFOTHER = "공격했지만 모든 피해를 저항했습니다.",
		--VSRESISTSELFSELF = "resist",
		VSENVIRONMENTALDAMAGE_FATIGUE_OTHER = "너무 기진맥진하여",
		VSENVIRONMENTALDAMAGE_FIRE_OTHER = "화염 피해를 입었습니다.",
		VSENVIRONMENTALDAMAGE_SLIME_OTHER = "독성으로 인해",
		VSENVIRONMENTALDAMAGE_SLIME_SELF = "당신은 독성으로 인해",
		VSENVIRONMENTALDAMAGE_DROWNING_OTHER = "숨을 쉴 수 없어",
		UNITDIESSELF = "당신은 죽었습니다.",
		UNITDIESOTHER = "죽었습니다.",
		UNITDESTROYEDOTHER = "파괴되었습니다.",
}

elseif GetLocale() == "zhTW" then

	keywordTable = {
		AURAADDEDOTHERHARMFUL = "受到",
		AURAADDEDOTHERHELPFUL = "獲得了",
		AURAADDEDSELFHARMFUL = "受到了",
		AURAADDEDSELFHELPFUL = "獲得了",
		AURAAPPLICATIONADDEDOTHERHARMFUL = "受到了",
		AURAAPPLICATIONADDEDOTHERHELPFUL = "獲得了",
		AURAAPPLICATIONADDEDSELFHARMFUL = "受到了",
		AURAAPPLICATIONADDEDSELFHELPFUL = "獲得了",
		AURADISPELOTHER = "移除",
		AURADISPELSELF = "移除",
		AURAREMOVEDOTHER = "消失",
		AURAREMOVEDSELF = "消失了",
		COMBATHITCRITOTHEROTHER = "致命一擊",
		COMBATHITCRITOTHERSELF = "致命一擊",
		COMBATHITCRITSELFOTHER = "致命一擊",
		COMBATHITCRITSELFSELF = "致命一擊",
		COMBATHITCRITSCHOOLOTHEROTHER = "致命一擊",
		COMBATHITCRITSCHOOLOTHERSELF = "致命一擊",
		COMBATHITCRITSCHOOLSELFOTHER = "致命一擊",
		COMBATHITCRITSCHOOLSELFSELF = "致命一擊",
		COMBATHITOTHEROTHER = "擊中",
		COMBATHITOTHERSELF = "擊中",
		COMBATHITSELFOTHER = "擊中",
		COMBATHITSELFSELF = "擊中",
		COMBATHITSCHOOLOTHEROTHER = "擊中",
		COMBATHITSCHOOLOTHERSELF = "擊中",
		COMBATHITSCHOOLSELFOTHER = "擊中",
		COMBATHITSCHOOLSELFSELF = "擊中",
		DAMAGESHIELDOTHEROTHER = "反射",
		DAMAGESHIELDOTHERSELF = "反彈",
		DAMAGESHIELDSELFOTHER = "反彈",
		DISPELFAILEDOTHEROTHER = "未能",
		DISPELFAILEDOTHERSELF = "未能",
		DISPELFAILEDSELFOTHER = "未能",
		DISPELFAILEDSELFSELF = "無法",
		HEALEDCRITOTHEROTHER = "發揮極效",
		HEALEDCRITOTHERSELF = "發揮極效",
		HEALEDCRITSELFOTHER = "極效治療",
		HEALEDCRITSELFSELF = "極效治療",
		HEALEDOTHEROTHER = "恢復",
		HEALEDOTHERSELF = "恢復",
		HEALEDSELFOTHER = "治療",
		HEALEDSELFSELF = "治療",
		IMMUNESPELLOTHEROTHER = "免疫",
		IMMUNESPELLSELFOTHER = "免疫",
		IMMUNESPELLOTHERSELF = "免疫",
		IMMUNESPELLSELFSELF = "免疫",
		ITEMENCHANTMENTADDOTHEROTHER = "施放",
		ITEMENCHANTMENTADDOTHERSELF = "施放",
		ITEMENCHANTMENTADDSELFOTHER = "施放",
		ITEMENCHANTMENTADDSELFSELF = "施放",
		MISSEDOTHEROTHER = "沒有擊中",
		MISSEDOTHERSELF = "沒有擊中",
		MISSEDSELFOTHER = "沒有擊中",
		MISSEDSELFSELF = "沒有擊中",
		OPEN_LOCK_OTHER = "使用",
		OPEN_LOCK_SELF = "使用",
		PARTYKILLOTHER = "幹掉",
		PERIODICAURADAMAGEOTHEROTHER = "受到了",
		PERIODICAURADAMAGEOTHERSELF = "受到",
		PERIODICAURADAMAGESELFOTHER = "受到了",
		PERIODICAURADAMAGESELFSELF = "受到",
		PERIODICAURAHEALOTHEROTHER = "獲得",
		PERIODICAURAHEALOTHERSELF = "獲得了",
		PERIODICAURAHEALSELFOTHER = "獲得",
		PERIODICAURAHEALSELFSELF = "獲得了",
		POWERGAINOTHEROTHER = "獲得",
		POWERGAINOTHERSELF = "獲得了",
		POWERGAINSELFSELF = "獲得了",
		POWERGAINSELFOTHER = "獲得",
		PROCRESISTOTHEROTHER = "抵抗了",
		PROCRESISTOTHERSELF = "抵抗了",
		PROCRESISTSELFOTHER = "抵抗了",
		PROCRESISTSELFSELF = "抵抗了",
		SIMPLECASTOTHEROTHER = "施放了",
		SIMPLECASTOTHERSELF = "施放了",
		SIMPLECASTSELFOTHER = "施放了",
		SIMPLECASTSELFSELF = "施放了",
		SIMPLEPERFORMOTHEROTHER = "使用",
		SIMPLEPERFORMOTHERSELF = "使用",
		SIMPLEPERFORMSELFOTHER = "使用",
		SIMPLEPERFORMSELFSELF = "使用",
		SPELLBLOCKEDOTHEROTHER = "格擋",
		SPELLBLOCKEDOTHERSELF = "格擋",
		SPELLBLOCKEDSELFOTHER = "格擋",
		SPELLBLOCKEDSELFSELF = "格擋",
		SPELLCASTOTHERSTART = "開始",
		SPELLCASTSELFSTART = "開始",
		SPELLDEFLECTEDOTHEROTHER = "偏斜",
		SPELLDEFLECTEDOTHERSELF = "偏斜",
		SPELLDEFLECTEDSELFOTHER = "偏斜",
		SPELLDEFLECTEDSELFSELF = "偏斜",
		SPELLDODGEDOTHEROTHER = "閃躲",
		SPELLDODGEDOTHERSELF = "閃躲",
		SPELLDODGEDSELFOTHER = "閃躲",
		SPELLEVADEDOTHEROTHER = "閃避",
		SPELLEVADEDOTHERSELF = "閃避",
		SPELLEVADEDSELFOTHER = "閃避",
		SPELLEVADEDSELFSELF = "閃避",
		SPELLEXTRAATTACKSOTHER = "額外",
		SPELLEXTRAATTACKSOTHER_SINGULAR = "額外",
		SPELLEXTRAATTACKSSELF = "額外",
		SPELLEXTRAATTACKSSELF_SINGULAR = "額外",
		SPELLFAILCASTSELF = "失敗",
		SPELLFAILPERFORMSELF = "失敗",
		SPELLIMMUNEOTHEROTHER = "免疫",
		SPELLIMMUNEOTHERSELF = "免疫",
		SPELLIMMUNESELFOTHER = "免疫",
		SPELLIMMUNESELFSELF = "免疫",
		SPELLINTERRUPTOTHEROTHER = "打斷了",
		SPELLINTERRUPTOTHERSELF = "打斷了",
		SPELLINTERRUPTSELFOTHER = "打斷了",
		SPELLLOGABSORBOTHEROTHER = "吸收了",
		SPELLLOGABSORBOTHERSELF = "吸收了",
		SPELLLOGABSORBSELFOTHER = "吸收了",
		SPELLLOGABSORBSELFSELF = "吸收了",
		SPELLLOGCRITOTHEROTHER = "致命一擊",
		SPELLLOGCRITOTHERSELF = "致命一擊",
		SPELLLOGCRITSCHOOLOTHEROTHER = "致命一擊",
		SPELLLOGCRITSCHOOLOTHERSELF = "致命一擊",
		SPELLLOGCRITSCHOOLSELFOTHER = "致命一擊",
		SPELLLOGCRITSCHOOLSELFSELF = "致命一擊",
		SPELLLOGCRITSELFOTHER = "致命一擊",
		SPELLLOGOTHEROTHER = "擊中",
		SPELLLOGOTHERSELF = "擊中",
--		SPELLLOGOTHERSELF = "擊中", -- Duplicated
		SPELLLOGSCHOOLOTHEROTHER = "擊中",
		SPELLLOGSCHOOLOTHERSELF = "擊中",
		SPELLLOGSCHOOLSELFOTHER = "擊中",
		SPELLLOGSCHOOLSELFSELF = "擊中",
		SPELLLOGSELFOTHER = "擊中",
		SPELLMISSOTHEROTHER = "沒有擊中",
		SPELLMISSOTHERSELF = "沒有擊中",
		SPELLMISSSELFOTHER = "沒有擊中",
		SPELLPARRIEDOTHEROTHER = "招架",
		SPELLPARRIEDOTHERSELF = "招架",
		SPELLPARRIEDSELFOTHER = "招架",
		SPELLPERFORMOTHERSTART = "開始",
		SPELLPERFORMSELFSTART = "開始",
		SPELLPOWERDRAINOTHEROTHER = "吸取",
		SPELLPOWERDRAINOTHERSELF = "吸收",
		SPELLPOWERDRAINSELFOTHER = "吸收",
		SPELLPOWERLEECHOTHEROTHER = "吸取",
		SPELLPOWERLEECHOTHERSELF = "吸取",
		SPELLPOWERLEECHSELFOTHER = "吸取",
		SPELLREFLECTOTHEROTHER = "反彈",
		SPELLREFLECTOTHERSELF = "反彈",
		SPELLREFLECTSELFOTHER = "反彈",
		SPELLREFLECTSELFSELF = "反彈",
		SPELLRESISTOTHEROTHER = "抵抗",
		SPELLRESISTOTHERSELF = "抵抗",
		SPELLRESISTSELFOTHER = "抵抗",
		SPELLRESISTSELFSELF = "抵抗",
		SPELLSPLITDAMAGESELFOTHER = "造成了",
		SPELLSPLITDAMAGEOTHEROTHER = "造成了",
		SPELLSPLITDAMAGEOTHERSELF = "造成了",
		SPELLTERSEPERFORM_OTHER = "使用",
		SPELLTERSEPERFORM_SELF = "使用",
		SPELLTERSE_OTHER = "施放了",
		SPELLTERSE_SELF = "施放了",
		VSABSORBOTHEROTHER = "吸收了",
		VSABSORBOTHERSELF = "吸收了",
		VSABSORBSELFOTHER = "吸收了",
		VSBLOCKOTHEROTHER = "格擋住了",
		VSBLOCKOTHERSELF = "格擋住了",
		VSBLOCKSELFOTHER = "格擋住了",
		VSBLOCKSELFSELF = "格擋住了",
		VSDEFLECTOTHEROTHER = "閃開了",
		VSDEFLECTOTHERSELF = "閃開了",
		VSDEFLECTSELFOTHER = "閃開了",
		VSDEFLECTSELFSELF = "閃開了",
		VSDODGEOTHEROTHER = "閃躲開了",
		VSDODGEOTHERSELF = "閃躲開了",
		VSDODGESELFOTHER = "閃開了",
		VSDODGESELFSELF = "dodge",
		VSENVIRONMENTALDAMAGE_FALLING_OTHER = "高處掉落",
		VSENVIRONMENTALDAMAGE_FALLING_SELF = "火焰",
		VSENVIRONMENTALDAMAGE_FIRE_OTHER = "火焰",
		VSENVIRONMENTALDAMAGE_FIRE_SELF = "火焰",
		VSENVIRONMENTALDAMAGE_LAVA_OTHER = "岩漿",
		VSENVIRONMENTALDAMAGE_LAVA_SELF = "岩漿",
		VSEVADEOTHEROTHER = "閃避",
		VSEVADEOTHERSELF = "閃避",
		VSEVADESELFOTHER = "閃避",
		VSEVADESELFSELF = "閃避",
		VSIMMUNEOTHEROTHER = "免疫",
		VSIMMUNEOTHERSELF = "免疫",
		VSIMMUNESELFOTHER = "免疫",
		VSPARRYOTHEROTHER = "招架",
		VSPARRYOTHERSELF = "招架",
		VSPARRYSELFOTHER = "招架",
		VSRESISTOTHEROTHER = "抵抗",
		VSRESISTOTHERSELF = "抵抗",
		VSRESISTSELFOTHER = "抵抗",
		VSRESISTSELFSELF = "抵抗",
		VSENVIRONMENTALDAMAGE_FATIGUE_OTHER = "精疲力竭",
		VSENVIRONMENTALDAMAGE_FIRE_OTHER = "火焰",
		VSENVIRONMENTALDAMAGE_SLIME_OTHER = "泥漿",
		VSENVIRONMENTALDAMAGE_SLIME_SELF = "泥漿",
		VSENVIRONMENTALDAMAGE_DROWNING_OTHER = "溺水狀態",
		UNITDIESSELF = "死亡",
		UNITDIESOTHER = "死亡",
		UNITDESTROYEDOTHER = "摧毀",
	}
end
]]
-- Provide the optimized eventTable of enUS as the default table.
eventTable = {
	CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_HITS = {
		'SPELLLOGCRITSCHOOLOTHEROTHER',
		'SPELLLOGSCHOOLOTHEROTHER',
		'COMBATHITCRITSCHOOLOTHEROTHER',
		'COMBATHITSCHOOLOTHEROTHER',
		'SPELLLOGCRITOTHEROTHER',
		'SPELLLOGOTHEROTHER',
		'COMBATHITCRITOTHEROTHER',
		'COMBATHITOTHEROTHER',
		'VSENVIRONMENTALDAMAGE_SLIME_OTHER',
		'VSENVIRONMENTALDAMAGE_LAVA_OTHER',
		'VSENVIRONMENTALDAMAGE_FIRE_OTHER',
		'VSENVIRONMENTALDAMAGE_FATIGUE_OTHER',
		'VSENVIRONMENTALDAMAGE_DROWNING_OTHER',
		'VSENVIRONMENTALDAMAGE_FALLING_OTHER',
	},
	CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_MISSES = {
		'VSABSORBOTHEROTHER',
		'VSRESISTOTHEROTHER',
		'IMMUNEDAMAGECLASSOTHEROTHER',
		'VSIMMUNEOTHEROTHER',
		'IMMUNEOTHEROTHER',
		'VSDEFLECTOTHEROTHER',
		'VSPARRYOTHEROTHER',
		'VSEVADEOTHEROTHER',
		'VSBLOCKOTHEROTHER',
		'VSDODGEOTHEROTHER',
		'MISSEDOTHEROTHER',
	},
	CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS = {
		'SPELLLOGCRITSCHOOLOTHERSELF',
		'SPELLLOGSCHOOLOTHERSELF',
		'COMBATHITCRITSCHOOLOTHERSELF',
		'SPELLLOGCRITSCHOOLOTHEROTHER',
		'COMBATHITSCHOOLOTHERSELF',
		'SPELLLOGSCHOOLOTHEROTHER',
		'COMBATHITCRITSCHOOLOTHEROTHER',
		'COMBATHITSCHOOLOTHEROTHER',
		'SPELLLOGCRITOTHERSELF',
		'SPELLLOGOTHERSELF',
		'COMBATHITCRITOTHERSELF',
		'SPELLLOGCRITOTHEROTHER',
		'COMBATHITOTHERSELF',
		'SPELLLOGOTHEROTHER',
		'COMBATHITCRITOTHEROTHER',
		'COMBATHITOTHEROTHER',
		'VSENVIRONMENTALDAMAGE_SLIME_OTHER',
		'VSENVIRONMENTALDAMAGE_LAVA_OTHER',
		'VSENVIRONMENTALDAMAGE_FIRE_OTHER',
		'VSENVIRONMENTALDAMAGE_FATIGUE_OTHER',
		'VSENVIRONMENTALDAMAGE_DROWNING_OTHER',
		'VSENVIRONMENTALDAMAGE_FALLING_OTHER',
	},
	CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES = {
		'VSABSORBOTHERSELF',
		'VSRESISTOTHERSELF',
		'VSABSORBOTHEROTHER',
		'VSRESISTOTHEROTHER',
		'IMMUNEOTHERSELF',
		'IMMUNEDAMAGECLASSOTHERSELF',
		'VSIMMUNEOTHERSELF',
		'IMMUNEDAMAGECLASSOTHEROTHER',
		'VSIMMUNEOTHEROTHER',
		'IMMUNEOTHEROTHER',
		'VSDEFLECTOTHERSELF',
		'VSPARRYOTHERSELF',
		'VSBLOCKOTHERSELF',
		'VSEVADEOTHERSELF',
		'VSDODGEOTHERSELF',
		'VSDEFLECTOTHEROTHER',
		'VSPARRYOTHEROTHER',
		'VSBLOCKOTHEROTHER',
		'VSEVADEOTHEROTHER',
		'VSDODGEOTHEROTHER',
		'MISSEDOTHERSELF',
		'MISSEDOTHEROTHER',
	},
	CHAT_MSG_COMBAT_FACTION_CHANGE = {
		'FACTION_STANDING_INCREASED',
		'FACTION_STANDING_DECREASED',
		'FACTION_STANDING_CHANGED',
	},
	CHAT_MSG_COMBAT_FRIENDLY_DEATH = {
		'SELFKILLOTHER',
		'UNITDESTROYEDOTHER',
		'PARTYKILLOTHER',
		'UNITDIESSELF',
		'UNITDIESOTHER',
	},
	CHAT_MSG_COMBAT_HONOR_GAIN = {
		'COMBATLOG_HONORGAIN',
		'COMBATLOG_HONORAWARD',
		'COMBATLOG_DISHONORGAIN',
	},
	CHAT_MSG_COMBAT_SELF_HITS = {
		'SPELLLOGCRITSCHOOLSELFOTHER',
		'SPELLLOGSCHOOLSELFOTHER',
		'COMBATHITCRITSCHOOLSELFOTHER',
		'COMBATHITSCHOOLSELFOTHER',
		'SPELLLOGCRITSELFOTHER',
		'SPELLLOGSELFOTHER',
		'COMBATHITCRITSELFOTHER',
		'COMBATHITSELFOTHER',
		'VSENVIRONMENTALDAMAGE_SLIME_SELF',
		'VSENVIRONMENTALDAMAGE_LAVA_SELF',
		'VSENVIRONMENTALDAMAGE_FATIGUE_SELF',
		'VSENVIRONMENTALDAMAGE_FIRE_SELF',
		'VSENVIRONMENTALDAMAGE_DROWNING_SELF',
		'VSENVIRONMENTALDAMAGE_FALLING_SELF',
	},
	CHAT_MSG_COMBAT_SELF_MISSES = {
		'IMMUNESELFSELF',
		'VSABSORBSELFOTHER',
		'VSRESISTSELFOTHER',
		'IMMUNEDAMAGECLASSSELFOTHER',
		'VSIMMUNESELFOTHER',
		'IMMUNESELFOTHER',
		'VSDEFLECTSELFOTHER',
		'VSPARRYSELFOTHER',
		'VSDODGESELFOTHER',
		'VSBLOCKSELFOTHER',
		'VSEVADESELFOTHER',
		'SPELLMISSSELFOTHER',
		'MISSEDSELFOTHER',
	},
	CHAT_MSG_COMBAT_XP_GAIN = {
		'COMBATLOG_XPGAIN_EXHAUSTION4_RAID',
		'COMBATLOG_XPGAIN_EXHAUSTION5_RAID',
		'COMBATLOG_XPGAIN_EXHAUSTION5_GROUP',
		'COMBATLOG_XPGAIN_EXHAUSTION4_GROUP',
		'COMBATLOG_XPGAIN_EXHAUSTION2_RAID',
		'COMBATLOG_XPGAIN_EXHAUSTION1_RAID',
		'COMBATLOG_XPGAIN_EXHAUSTION1_GROUP',
		'COMBATLOG_XPGAIN_EXHAUSTION2_GROUP',
		'COMBATLOG_XPGAIN_FIRSTPERSON_RAID',
		'COMBATLOG_XPGAIN_FIRSTPERSON_GROUP',
		'COMBATLOG_XPGAIN_EXHAUSTION5',
		'COMBATLOG_XPGAIN_EXHAUSTION4',
		'COMBATLOG_XPGAIN_EXHAUSTION1',
		'COMBATLOG_XPGAIN_EXHAUSTION2',
		'COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED_RAID',
		'COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED_GROUP',
		'COMBATLOG_XPGAIN_FIRSTPERSON',
		'COMBATLOG_XPLOSS_FIRSTPERSON_UNNAMED',
		'COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED',
		'COMBATLOG_XPGAIN',
	},
	CHAT_MSG_SPELL_AURA_GONE_OTHER = {
		'AURAREMOVEDOTHER',
	},
	CHAT_MSG_SPELL_AURA_GONE_SELF = {
		'AURAREMOVEDSELF',
		'AURAREMOVEDOTHER',
	},
	CHAT_MSG_SPELL_BREAK_AURA = {
		-- 'AURADISPELSELF3',
		-- 'AURADISPELSELF2',
		'AURADISPELSELF',
		-- 'AURADISPELOTHER3',
		-- 'AURADISPELOTHER2',
		'AURADISPELOTHER',
	},
	CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF = {
		'SPELLPOWERLEECHOTHERSELF',
		'SPELLEXTRAATTACKSOTHER',
		'HEALEDCRITOTHERSELF',
		'SPELLEXTRAATTACKSOTHER_SINGULAR',
		'SPELLPOWERLEECHOTHEROTHER',
		'HEALEDCRITOTHEROTHER',
		'SPELLPOWERDRAINOTHERSELF',
		'HEALEDOTHERSELF',
		'SPELLPOWERDRAINOTHEROTHER',
		'HEALEDOTHEROTHER',
		'POWERGAINOTHERSELF',
		'POWERGAINOTHEROTHER',
		'SPELLCASTOTHERSTART',
		'SIMPLEPERFORMOTHERSELF',
		'ITEMENCHANTMENTADDOTHERSELF',
		'SIMPLECASTOTHERSELF',
		'SIMPLEPERFORMOTHEROTHER',
		'OPEN_LOCK_OTHER',
		'ITEMENCHANTMENTADDOTHEROTHER',
		'SIMPLECASTOTHEROTHER',
		'SPELLTERSEPERFORM_OTHER',
		'SPELLTERSE_OTHER',
		'SPELLPERFORMOTHERSTART',
		'SPELLIMMUNEOTHERSELF',
		'SPELLREFLECTOTHEROTHER',
		'IMMUNESPELLOTHERSELF',
		'SPELLDEFLECTEDOTHEROTHER',
		'SPELLIMMUNEOTHEROTHER',
		'SPELLRESISTOTHEROTHER',
		'SPELLLOGABSORBOTHEROTHER',
		'SPELLPARRIEDOTHEROTHER',
		'SPELLBLOCKEDOTHEROTHER',
		'SPELLDODGEDOTHEROTHER',
		'SPELLEVADEDOTHEROTHER',
		'SPELLDEFLECTEDOTHERSELF',
		'IMMUNESPELLOTHEROTHER',
		'SPELLRESISTOTHERSELF',
		'SPELLREFLECTOTHERSELF',
		'SPELLBLOCKEDOTHERSELF',
		'SPELLPARRIEDOTHERSELF',
		'SPELLEVADEDOTHERSELF',
		'SPELLDODGEDOTHERSELF',
		'SPELLLOGABSORBOTHERSELF',
		'SPELLMISSOTHERSELF',
		'SPELLMISSOTHEROTHER',
		'PROCRESISTOTHERSELF',
		'PROCRESISTOTHEROTHER',
		'SPELLSPLITDAMAGEOTHERSELF',
		'SPELLSPLITDAMAGEOTHEROTHER',
		'DISPELFAILEDOTHERSELF',
		'DISPELFAILEDOTHEROTHER',
	},
	CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE = {
		'SPELLLOGCRITSCHOOLOTHERSELF',
		'SPELLLOGSCHOOLOTHERSELF',
		'SPELLLOGCRITSCHOOLOTHEROTHER',
		'SPELLLOGSCHOOLOTHEROTHER',
		'SPELLLOGCRITOTHERSELF',
		'SPELLLOGOTHERSELF',
		'SPELLLOGCRITOTHEROTHER',
		'SPELLLOGOTHEROTHER',
		'SPELLCASTOTHERSTART',
		'SPELLPERFORMOTHERSTART',
		'SPELLPOWERLEECHOTHERSELF',
		'SPELLPOWERLEECHOTHEROTHER',
		'SPELLPOWERDRAINOTHERSELF',
		'SPELLPOWERDRAINOTHEROTHER',
		'SPELLIMMUNEOTHERSELF',
		'SPELLREFLECTOTHEROTHER',
		'IMMUNESPELLOTHERSELF',
		'SPELLDEFLECTEDOTHEROTHER',
		'SPELLIMMUNEOTHEROTHER',
		'SPELLRESISTOTHEROTHER',
		'SPELLLOGABSORBOTHEROTHER',
		'SPELLPARRIEDOTHEROTHER',
		'SPELLBLOCKEDOTHEROTHER',
		'SPELLDODGEDOTHEROTHER',
		'SPELLEVADEDOTHEROTHER',
		'SPELLDEFLECTEDOTHERSELF',
		'IMMUNESPELLOTHEROTHER',
		'SPELLRESISTOTHERSELF',
		'SPELLREFLECTOTHERSELF',
		'SPELLBLOCKEDOTHERSELF',
		'SPELLPARRIEDOTHERSELF',
		'SPELLEVADEDOTHERSELF',
		'SPELLDODGEDOTHERSELF',
		'SPELLLOGABSORBOTHERSELF',
		'SPELLMISSOTHERSELF',
		'SPELLMISSOTHEROTHER',
		'INSTAKILLSELF',
		'INSTAKILLOTHER',
		'PROCRESISTOTHERSELF',
		'PROCRESISTOTHEROTHER',
		'SPELLSPLITDAMAGEOTHERSELF',
		'SPELLSPLITDAMAGEOTHEROTHER',
		'SPELLDURABILITYDAMAGEALLOTHERSELF',
		'SPELLDURABILITYDAMAGEALLOTHEROTHER',
		'SPELLDURABILITYDAMAGEOTHERSELF',
		'SPELLDURABILITYDAMAGEOTHEROTHER',
		'SPELLINTERRUPTOTHERSELF',
		'SPELLINTERRUPTOTHEROTHER',
		'SIMPLECASTOTHERSELF',
		'SIMPLECASTOTHEROTHER',
		'SPELLTERSE_OTHER',
		'SIMPLEPERFORMOTHERSELF',
		'OPEN_LOCK_OTHER',
		'SIMPLEPERFORMOTHEROTHER',
		'SPELLTERSEPERFORM_OTHER',
		'SPELLEXTRAATTACKSOTHER',
		'SPELLEXTRAATTACKSOTHER_SINGULAR',
		'DISPELFAILEDOTHERSELF',
		'DISPELFAILEDOTHEROTHER',
	},
	CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS = {
		'DAMAGESHIELDOTHERSELF',
		'DAMAGESHIELDOTHEROTHER',
		'SPELLRESISTOTHEROTHER',
		'SPELLRESISTOTHERSELF',
	},
	CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF = {
		'DAMAGESHIELDSELFOTHER',
		'SPELLRESISTSELFOTHER',
		'DAMAGESHIELDOTHEROTHER',
		'SPELLRESISTOTHEROTHER',
	},
	CHAT_MSG_SPELL_FAILED_LOCALPLAYER = {
		'SPELLFAILPERFORMSELF',
		'SPELLFAILCASTSELF',
	},
	CHAT_MSG_SPELL_ITEM_ENCHANTMENTS = {
		'ITEMENCHANTMENTADDSELFSELF',
		'ITEMENCHANTMENTADDSELFOTHER',
		'ITEMENCHANTMENTADDOTHERSELF',
		'ITEMENCHANTMENTADDOTHEROTHER',
	},
	CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS = {
		'PERIODICAURAHEALSELFOTHER',
		'PERIODICAURAHEALOTHEROTHER',
		'SPELLPOWERLEECHOTHERSELF',
		'SPELLPOWERLEECHOTHEROTHER',
		'SPELLPOWERDRAINOTHERSELF',
		'SPELLPOWERDRAINOTHEROTHER',
		'POWERGAINOTHERSELF',
		'AURAAPPLICATIONADDEDOTHERHELPFUL',
		'POWERGAINOTHEROTHER',
		'AURAADDEDOTHERHELPFUL',
		'PERIODICAURADAMAGESELFOTHER',
		'PERIODICAURADAMAGEOTHEROTHER',
		'PERIODICAURADAMAGEOTHER',
		'AURAAPPLICATIONADDEDOTHERHARMFUL',
		'AURAADDEDOTHERHARMFUL',
	},
	CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE = {
		'AURAAPPLICATIONADDEDOTHERHARMFUL',
		'AURAADDEDOTHERHARMFUL',
		'PERIODICAURADAMAGESELFOTHER',
		'PERIODICAURADAMAGEOTHEROTHER',
		'PERIODICAURADAMAGEOTHER',
		'SPELLLOGABSORBSELFOTHER',
		'SPELLLOGABSORBOTHEROTHER',
		'SPELLPOWERLEECHOTHERSELF',
		'SPELLPOWERLEECHOTHEROTHER',
		'SPELLPOWERDRAINOTHERSELF',
		'SPELLPOWERDRAINOTHEROTHER',
		'POWERGAINOTHERSELF',
		'AURAAPPLICATIONADDEDOTHERHELPFUL',
		'POWERGAINOTHEROTHER',
		'AURAADDEDOTHERHELPFUL',
	},
	CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS = {
		'PERIODICAURAHEALSELFOTHER',
		'PERIODICAURAHEALOTHERSELF',
		'PERIODICAURAHEALOTHEROTHER',
		'PERIODICAURAHEALSELFSELF',
		'AURAAPPLICATIONADDEDSELFHELPFUL',
		'POWERGAINOTHEROTHER',
		'POWERGAINOTHERSELF',
		'POWERGAINSELFSELF',
		'AURAAPPLICATIONADDEDOTHERHELPFUL',
		'AURAADDEDSELFHELPFUL',
		'POWERGAINSELFOTHER',
		'AURAADDEDOTHERHELPFUL',
		'SPELLPOWERLEECHSELFOTHER',
		'SPELLPOWERDRAINSELFSELF',
		'SPELLPOWERDRAINSELFOTHER',
		'PERIODICAURADAMAGESELFSELF',
		'PERIODICAURADAMAGEOTHERSELF',
		'PERIODICAURADAMAGESELF',
	},
	CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE = {
		'PERIODICAURADAMAGESELFSELF',
		'PERIODICAURADAMAGEOTHERSELF',
		'PERIODICAURADAMAGESELFOTHER',
		'PERIODICAURADAMAGEOTHEROTHER',
		'PERIODICAURADAMAGESELF',
		'PERIODICAURADAMAGEOTHER',
		'AURAAPPLICATIONADDEDSELFHARMFUL',
		'AURAADDEDSELFHARMFUL',
		'AURAAPPLICATIONADDEDOTHERHARMFUL',
		'AURAADDEDOTHERHARMFUL',
		'SPELLLOGABSORBSELFOTHER',
		'SPELLLOGABSORBOTHEROTHER',
		'SPELLLOGABSORBSELFSELF',
		'SPELLLOGABSORBOTHERSELF',
		'SPELLPOWERLEECHSELFOTHER',
		'SPELLPOWERDRAINSELFSELF',
		'SPELLPOWERDRAINSELFOTHER',
	},
	CHAT_MSG_SPELL_SELF_BUFF = {
		'HEALEDCRITSELFSELF',
		'HEALEDCRITSELFOTHER',
		'HEALEDSELFSELF',
		'HEALEDSELFOTHER',
		'ITEMENCHANTMENTADDSELFSELF',
		'ITEMENCHANTMENTADDSELFOTHER',
		'SIMPLECASTSELFOTHER',
		'SIMPLECASTSELFSELF',
		'SPELLTERSE_SELF',
		'OPEN_LOCK_SELF',
		'SIMPLEPERFORMSELFOTHER',
		'SIMPLEPERFORMSELFSELF',
		'SPELLTERSEPERFORM_SELF',
		'DISPELFAILEDSELFSELF',
		'DISPELFAILEDSELFOTHER',
		'SPELLCASTSELFSTART',
		'SPELLPERFORMSELFSTART',
		'SPELLEXTRAATTACKSSELF',
		'SPELLPOWERLEECHSELFOTHER',
		'SPELLEXTRAATTACKSSELF_SINGULAR',
		'SPELLPOWERDRAINSELFSELF',
		'SPELLPOWERDRAINSELFOTHER',
		'POWERGAINSELFSELF',
		'POWERGAINSELFOTHER',
		'SPELLSPLITDAMAGESELFOTHER',
		'SPELLIMMUNESELFSELF',
		'SPELLREFLECTSELFOTHER',
		'SPELLIMMUNESELFOTHER',
		'IMMUNESPELLSELFSELF',
		'SPELLDEFLECTEDSELFOTHER',
		'SPELLRESISTSELFOTHER',
		'SPELLBLOCKEDSELFOTHER',
		'SPELLLOGABSORBSELFOTHER',
		'SPELLEVADEDSELFOTHER',
		'SPELLPARRIEDSELFOTHER',
		'SPELLDODGEDSELFOTHER',
		'SPELLREFLECTSELFSELF',
		'SPELLDEFLECTEDSELFSELF',
		'IMMUNESPELLSELFOTHER',
		'SPELLRESISTSELFSELF',
		'SPELLPARRIEDSELFSELF',
		'SPELLEVADEDSELFSELF',
		'SPELLLOGABSORBSELFSELF',
		'SPELLDODGEDSELFSELF',
		'PROCRESISTSELFSELF',
		'SPELLMISSSELFSELF',
		'PROCRESISTSELFOTHER',
		'SPELLMISSSELFOTHER',
	},
	CHAT_MSG_SPELL_SELF_DAMAGE = {
		'SPELLLOGCRITSCHOOLSELFSELF',
		'SPELLLOGSCHOOLSELFSELF',
		'SPELLLOGCRITSCHOOLSELFOTHER',
		'SPELLLOGSCHOOLSELFOTHER',
		'SPELLLOGCRITSELFSELF',
		'SPELLLOGSELFSELF',
		'SPELLLOGCRITSELFOTHER',
		'SPELLLOGSELFOTHER',
		'SPELLDURABILITYDAMAGEALLSELFOTHER',
		'SPELLDURABILITYDAMAGESELFOTHER',
		'SIMPLECASTSELFOTHER',
		'SIMPLECASTSELFSELF',
		'SPELLTERSE_SELF',
		'OPEN_LOCK_SELF',
		'SIMPLEPERFORMSELFOTHER',
		'SIMPLEPERFORMSELFSELF',
		'SPELLTERSEPERFORM_SELF',
		'SPELLIMMUNESELFSELF',
		'SPELLREFLECTSELFOTHER',
		'SPELLIMMUNESELFOTHER',
		'IMMUNESPELLSELFSELF',
		'SPELLDEFLECTEDSELFOTHER',
		'SPELLRESISTSELFOTHER',
		'SPELLLOGABSORBSELFOTHER',
		'SPELLBLOCKEDSELFOTHER',
		'SPELLPARRIEDSELFOTHER',
		'SPELLDODGEDSELFOTHER',
		'SPELLEVADEDSELFOTHER',
		'SPELLDEFLECTEDSELFSELF',
		'SPELLREFLECTSELFSELF',
		'IMMUNESPELLSELFOTHER',
		'SPELLRESISTSELFSELF',
		'SPELLPARRIEDSELFSELF',
		'SPELLDODGEDSELFSELF',
		'SPELLEVADEDSELFSELF',
		'SPELLLOGABSORBSELFSELF',
		'SPELLMISSSELFSELF',
		'SPELLMISSSELFOTHER',
		'SPELLCASTSELFSTART',
		'SPELLPERFORMSELFSTART',
		'SPELLINTERRUPTSELFOTHER',
		'DISPELFAILEDSELFSELF',
		'DISPELFAILEDSELFOTHER',
		'SPELLEXTRAATTACKSSELF',
		'SPELLEXTRAATTACKSSELF_SINGULAR',
		'SPELLPOWERLEECHSELFOTHER',
		'SPELLPOWERDRAINSELFSELF',
		'SPELLPOWERDRAINSELFOTHER',
	},
	CHAT_MSG_SPELL_TRADESKILLS = {
		'FEEDPET_LOG_FIRSTPERSON',
		'FEEDPET_LOG_THIRDPERSON',
		'TRADESKILL_LOG_FIRSTPERSON',
		'TRADESKILL_LOG_THIRDPERSON',
	},
}
eventTable['CHAT_MSG_COMBAT_CREATURE_VS_PARTY_MISSES'] = eventTable['CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_MISSES']
eventTable['CHAT_MSG_COMBAT_FRIENDLYPLAYER_MISSES'] = eventTable['CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_MISSES']
eventTable['CHAT_MSG_COMBAT_PARTY_MISSES'] = eventTable['CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_MISSES']
eventTable['CHAT_MSG_COMBAT_PET_MISSES'] = eventTable['CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_MISSES']
eventTable['CHAT_MSG_SPELL_CREATURE_VS_PARTY_BUFF'] = eventTable['CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF']
eventTable['CHAT_MSG_SPELL_CREATURE_VS_SELF_BUFF'] = eventTable['CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF']
eventTable['CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF'] = eventTable['CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF']
eventTable['CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF'] = eventTable['CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF']
eventTable['CHAT_MSG_SPELL_PARTY_BUFF'] = eventTable['CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF']
eventTable['CHAT_MSG_SPELL_PET_BUFF'] = eventTable['CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF']
eventTable['CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE'] = eventTable['CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE']
eventTable['CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE'] = eventTable['CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE']
eventTable['CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE'] = eventTable['CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE']
eventTable['CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS'] = eventTable['CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS']
eventTable['CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_BUFFS'] = eventTable['CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS']
eventTable['CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS'] = eventTable['CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS']
eventTable['CHAT_MSG_COMBAT_HOSTILE_DEATH'] = eventTable['CHAT_MSG_COMBAT_FRIENDLY_DEATH']
eventTable['CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE'] = eventTable['CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE']
eventTable['CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE'] = eventTable['CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE']
eventTable['CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE'] = eventTable['CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE']
eventTable['CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE'] = eventTable['CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE']
eventTable['CHAT_MSG_SPELL_PARTY_DAMAGE'] = eventTable['CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE']
eventTable['CHAT_MSG_SPELL_PET_DAMAGE'] = eventTable['CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE']
eventTable['CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS'] = eventTable['CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS']
eventTable['CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS'] = eventTable['CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_HITS']
eventTable['CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS'] = eventTable['CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_HITS']
eventTable['CHAT_MSG_COMBAT_PARTY_HITS'] = eventTable['CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_HITS']
eventTable['CHAT_MSG_COMBAT_PET_HITS'] = eventTable['CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_HITS']
eventTable['CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES'] = eventTable['CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES']
eventTable['CHAT_MSG_SPELL_AURA_GONE_PARTY'] = eventTable['CHAT_MSG_SPELL_AURA_GONE_OTHER']

eventTableLocale = "enUS"


if GetLocale() == "deDE" then

	-- Remove ITEMENCHANTMENTADDOTHERSELF, it's ambiguous to SIMPLECASTOTHEROTHER.
	-- Remove ITEMENCHANTMENTADDSELFSELF, it's ambiguous to SIMPLECASTSELFOTHER.
	for event, list in pairs(eventTable) do
		for i, pattern in ipairs(list) do
			if pattern == 'ITEMENCHANTMENTADDOTHERSELF' or pattern == 'ITEMENCHANTMENTADDSELFSELF' then
				table.remove(list, i)
			end
		end
	end
	
end

-- Convert "%s hits %s for %d." to "(.+) hits (.+) for (%d+)."
-- Will additionaly return the sequence of tokens, for example:
--  "%2$s reflects %3$d %4$s damage to %1$s." will return:
--    "(.-) reflects (%+) (.-) damage to (.-)%.", 4 1 2 3.
--  (    [1]=2,[2]=3,[3]=4,[4]=1  Reverting indexes and become  [1]=4, [2]=[1],[3]=2,[4]=3. )
function ConvertPattern(pattern, anchor)
	local seq

	-- Add % to escape all magic characters used in LUA pattern matching, except $ and %
	pattern = pattern:gsub("([%^%(%)%.%[%]%*%+%-%?])","%%%1")


	if pattern:find("%$") then
		seq = {} -- fills with ordered list of $s as they appear
		local idx = 1 -- incremental index into field[]
		local prevIdx = idx
		local tmpSeq = {}
		for i in pattern:gmatch("%%(%d?)%$?[sd]") do
			if tonumber(i) then
				tmpSeq[idx] = tonumber(i)
				prevIdx = tonumber(i)+1
			else
				tmpSeq[idx] = prevIdx
				prevIdx = idx + 1
			end
			idx = idx + 1
		end
		for i, j in ipairs(tmpSeq) do
			seq[j] = i
		end
	end
	
	-- Do these AFTER escaping the magic characters.
	pattern = pattern:gsub("%%%d?%$?s", "(.-)")
	pattern = pattern:gsub("%%%d?%$?d", "(%-?%%d+)")
	

	-- Escape $ now.
	pattern = pattern:gsub("%$","%%$")

	-- Anchor tag can improve string.find() performance by 100%.
	if anchor then pattern = "^"..pattern end

	-- If the pattern ends with (.-), replace it with (.+), or the capsule will be lost.
	if pattern:sub(-4) == "(.-)" then
		pattern = pattern:sub(0, -5) .. "(.+)"
	end

	if seq then
		return pattern, unpack(seq)
	else
		return pattern
	end
end

-- Sort the eventTable so that they work on the current localization.
function SortEventTables()
	
	-- Get the list of events.
	local eventList = {}
	for event in pairs(eventTable) do
		table.insert(eventList, event)
	end
	
	-- Record the lists which have the same reference, noneed to sort them twice.
	local eventMap = {}
	
	for i, event in ipairs(eventList) do		
		if not eventMap[event] then
			table.sort(eventTable[event], PatternCompare)
		end		
		for j=i+1, #eventList, 1 do
			local event2 = eventList[j]
			if eventTable[event2] == eventTable[event] then
				eventMap[event2] = true
			end
		end
	end
	
	
end

function ParseMessage(message, event)

	local list = eventTable[event]

	if not list then
		return
	end

	-- Cleans the table.
	for k in pairs(info) do
		info[k] = nil
	end

	local pattern, patternInfo, pos = FindPattern(message, list)

	info.pattern = pattern
	
	if not pattern then
		-- create "unknown" event type.
		info.type = "unknown"
		info.message = message
		
	else

		ConvertType(info, patternInfo)
		MapPatternInfo(info, info, patternInfo)

		if info.type == "hit" or info.type == "environment" then
			ParseTrailers(message, pos+1)
		end

	end


end

-- Search for pattern in 'patternList' which matches 'message', parsed tokens will be stored in table info
function FindPattern(message, patternList)

	local pt, pos

	for i, pattern in ipairs(patternList) do

		if patternTable[pattern] == nil then
			patternTable[pattern] = LoadPatternInfo(pattern)
		end
		
		pt = patternTable[pattern]
		
		if pt then
			if not keywordTable
			or not keywordTable[pattern]
			or message:find(keywordTable[pattern], 1, true) then
			
				pos = FindString[pt.tc](message, pt.pattern, info)
				
			end
			
			if pos then
				return pattern, pt, pos
			end
			
		end
	end
end

function ParseTrailers(message, begin)
	local found, amount

	if not trailers then
		trailers = {
			CRUSHING_TRAILER = ConvertPattern(CRUSHING_TRAILER),
			GLANCING_TRAILER = ConvertPattern(GLANCING_TRAILER),
			ABSORB_TRAILER = ConvertPattern(ABSORB_TRAILER),
			BLOCK_TRAILER = ConvertPattern(BLOCK_TRAILER),
			RESIST_TRAILER = ConvertPattern(RESIST_TRAILER),
			VULNERABLE_TRAILER = ConvertPattern(VULNERABLE_TRAILER),
		}
	end
	

	found = message:find(trailers.CRUSHING_TRAILER, begin)
	if found then
		info.isCrushing = true
	end
	found = message:find(trailers.GLANCING_TRAILER, begin)
	if found then
		info.isGlancing = true
	end
	found, _, amount = message:find(trailers.ABSORB_TRAILER, begin)
	if found then
		info.amountAbsorb = tonumber(amount)
	end
	found, _, amount = message:find(trailers.BLOCK_TRAILER, begin)
	if found then
		info.amountBlock = tonumber(amount)
	end
	found, _, amount = message:find(trailers.RESIST_TRAILER, begin)
	if found then
		info.amountResist = tonumber(amount)
	end
	found, _, amount = message:find(trailers.VULNERABLE_TRAILER, begin)
	if found then
		info.amountVulnerable = tonumber(amount)
	end
end

function ConvertType(t, patternInfo)
	local nf = patternInfo.nf
	if nf then
		if type(nf) == 'number' then
			info[nf] = tonumber(info[nf])
		else
			for i, v in ipairs(nf) do
				info[v] = tonumber(info[v])
			end
		end
	end
end

-- Make sure the keyword table is correct.
-- Will remove incorrect ones.
function TestKeywordTable()
	if keywordTable then
		for pattern, keyword in pairs(keywordTable) do
			local str = _G[pattern]
			if str and type(str) == 'string' then
				if not str:find(keyword, 1, true) then
					keywordTable[pattern] = nil
				end
			end
		end
	end
end

-- Auto-generate the keywordTable with the idea suggested by ckknight.
function GenerateKeywordTable()

	keywordTable = {}
	
	local wordCounts = {}
	local patterns = {}

	-- Get a list of patterns.
	for event, list in pairs(eventTable) do
		for i, pattern in ipairs(list) do
			patterns[pattern] = true
		end
	end
	
	-- Count how many GlobalString contains the word.
	local function CountWord(word)
		if not wordCounts[word] then
			wordCounts[word] = 0
			for pattern in pairs(patterns) do
				local str = _G[pattern]
				if str and str:find(word, 1, true) then
					wordCounts[word] = wordCounts[word] + 1
				end
			end
		end
	end
		
	-- Parse for the keywords in each pattern.
	for pattern in pairs(patterns) do
		local str = _G[pattern]
		if str then
			local fpat = "(.-)%%%d?%$?[sd]"
			local last_end = 1
			local s, e, cap = str:find(fpat, 1)
			while s do
				if s ~= 1 or w ~= "" then
					CountWord(cap)
				end
				last_end = e+1
				s, e, cap = str:find(fpat, last_end)
			end
			if last_end <= str:len() then
				cap = str:sub(last_end)
				CountWord(cap)
			end
		end
	end
	
	-- Parse for the keywords in each pattern again, find the rarest word.
	for pattern in pairs(patterns) do
		local str = _G[pattern]
		local minCount, rarestWord
		if str then
			local fpat = "(.-)%%%d?%$?[sd]"
			local last_end = 1
			local s, e, cap = str:find(fpat, 1)
			while s do
				if s ~= 1 or w ~= "" then
					if not rarestWord or minCount > wordCounts[cap] or ( minCount == wordCounts[cap] and cap:len() < rarestWord:len() ) then
						minCount = wordCounts[cap]
						rarestWord = cap
					end
				end
				last_end = e+1
				s, e, cap = str:find(fpat, last_end)
			end
			if last_end <= str:len() then
				cap = str:sub(last_end)
				if not rarestWord or minCount > wordCounts[cap] or ( minCount == wordCounts[cap] and cap:len() < rarestWord:len() ) then
					minCount = wordCounts[cap]
					rarestWord = cap
				end
			end
			
			keywordTable[pattern] = rarestWord
		end
	end

end

-- Most of the parts were learnt from BabbleLib by chknight, so credits goes to him.
function Curry(pattern)
	local cp, tt, n, f, o
	local DoNothing = function(tok) return tok end

	tt = {}
	for tk in pattern:gmatch("%%%d?%$?([sd])") do
		table.insert(tt, tk)
	end

	cp = { ConvertPattern(pattern, true) }
	cp.p = cp[1]

	n = #(cp)
	for i=1,n-1 do
		cp[i] = cp[i+1]
	end
	table.remove(cp, n)

	f = {}
	o = {}
	n = #(tt)
	for i=1, n do
		if tt[i] == "s" then
			f[i] = DoNothing
		else
			f[i] = tonumber
		end
	end

	if not cp[1] then
		if n == 0 then
			return function() end
		elseif n == 1 then
			return function(text)
				_, _, o[1] = text:find(cp.p)
				if o[1] then
					return f[1](o[1])
				end
			end
		elseif n == 2 then
			return function(text)
				_, _, o[1], o[2]= text:find(cp.p)
				if o[1] then
					return f[1](o[1]), f[2](o[2])
				end
			end
		elseif n == 3 then
			return function(text)
				_, _, o[1], o[2], o[3] = text:find(cp.p)
				if o[1] then
					return f[1](o[1]), f[2](o[2]), f[3](o[3])
				end
			end
		elseif n == 4 then
			return function(text)
				_, _, o[1], o[2], o[3], o[4] = text:find(cp.p)
				if o[1] then
					return f[1](o[1]), f[2](o[2]), f[3](o[3]), f[4](o[4])
				end
			end
		elseif n == 5 then
			return function(text)
				_, _, o[1], o[2], o[3], o[4], o[5] = text:find(cp.p)
				if o[1] then
					return f[1](o[1]), f[2](o[2]), f[3](o[3]), f[4](o[4]), f[5](o[5])
				end
			end
		elseif n == 6 then
			return function(text)
				_, _, o[1], o[2], o[3], o[4], o[5], o[6] = text:find(cp.p)
				if o[1] then
					return f[1](o[1]), f[2](o[2]), f[3](o[3]), f[4](o[4]), f[5](o[5]), f[6](o[6])
				end
			end
		elseif n == 7 then
			return function(text)
				_, _, o[1], o[2], o[3], o[4], o[5], o[6], o[7] = text:find(cp.p)
				if o[1] then
					return f[1](o[1]), f[2](o[2]), f[3](o[3]), f[4](o[4]), f[5](o[5]), f[6](o[6]), f[7](o[7])
				end
			end
		elseif n == 8 then
			return function(text)
				_, _, o[1], o[2], o[3], o[4], o[5], o[6], o[7], o[8] = text:find(cp.p)
				if o[1] then
					return f[1](o[1]), f[2](o[2]), f[3](o[3]), f[4](o[4]), f[5](o[5]), f[6](o[6]), f[7](o[7]), f[8](o[8])
				end
			end
		elseif n == 9 then
			return function(text)
				_, _, o[1], o[2], o[3], o[4], o[5], o[6], o[7], o[8], o[9] = text:find(cp.p)
				if o[1] then
					return f[1](o[1]), f[2](o[2]), f[3](o[3]), f[4](o[4]), f[5](o[5]), f[6](o[6]), f[7](o[7]), f[8](o[8]), f[9](o[9])
				end
			end
		end
	else
		if n == 0 then
			return function() end
		elseif n == 1 then
			return function(text)
				_, _, o[1] = text:find(cp.p)
				if o[1] then
					return f[cp[1]](o[cp[1]])
				end
			end
		elseif n == 2 then
			return function(text)
				_, _, o[1], o[2] = text:find(cp.p)
				if o[1] then
					return f[cp[1]](o[cp[1]]), f[cp[2]](o[cp[2]])
				end
			end
		elseif n == 3 then
			return function(text)
				_, _, o[1], o[2], o[3] = text:find(cp.p)
				if o[1] then
					return f[cp[1]](o[cp[1]]), f[cp[2]](o[cp[2]]), f[cp[3]](o[cp[3]])
				end
			end
		elseif n == 4 then
			return function(text)
				_, _, o[1], o[2], o[3], o[4] = text:find(cp.p)
				if o[1] then
					return f[cp[1]](o[cp[1]]), f[cp[2]](o[cp[2]]), f[cp[3]](o[cp[3]]), f[cp[4]](o[cp[4]])
				end
			end
		elseif n == 5 then
			return function(text)
				_, _, o[1], o[2], o[3], o[4], o[5] = text:find(cp.p)
				if o[1] then
					return f[cp[1]](o[cp[1]]), f[cp[2]](o[cp[2]]), f[cp[3]](o[cp[3]]), f[cp[4]](o[cp[4]]), f[cp[5]](o[cp[5]])
				end
			end
		elseif n == 6 then
			return function(text)
				_, _, o[1], o[2], o[3], o[4], o[5], o[6] = text:find(cp.p)
				if o[1] then
					return f[cp[1]](o[cp[1]]), f[cp[2]](o[cp[2]]), f[cp[3]](o[cp[3]]), f[cp[4]](o[cp[4]]), f[cp[5]](o[cp[5]]), f[cp[6]](o[cp[6]])
				end
			end
		elseif n == 7 then
			return function(text)
				_, _, o[1], o[2], o[3], o[4], o[5], o[6], o[7] = text:find(cp.p)
				if o[1] then
					return f[cp[1]](o[cp[1]]), f[cp[2]](o[cp[2]]), f[cp[3]](o[cp[3]]), f[cp[4]](o[cp[4]]), f[cp[5]](o[cp[5]]), f[cp[6]](o[cp[6]]), f[cp[7]](o[cp[7]])
				end
			end
		elseif n == 8 then
			return function(text)
				_, _, o[1], o[2], o[3], o[4], o[5], o[6], o[7], o[8] = text:find(cp.p)
				if o[1] then
					return f[cp[1]](o[cp[1]]), f[cp[2]](o[cp[2]]), f[cp[3]](o[cp[3]]), f[cp[4]](o[cp[4]]), f[cp[5]](o[cp[5]]), f[cp[6]](o[cp[6]]), f[cp[7]](o[cp[7]]), f[cp[8]](o[cp[8]])
				end
			end
		elseif n == 9 then
			return function(text)
				_, _, o[1], o[2], o[3], o[4], o[5], o[6], o[7], o[8], o[9] = text:find(cp.p)
				if o[1] then
					return f[cp[1]](o[cp[1]]), f[cp[2]](o[cp[2]]), f[cp[3]](o[cp[3]]), f[cp[4]](o[cp[4]]), f[cp[5]](o[cp[5]]), f[cp[6]](o[cp[6]]), f[cp[7]](o[cp[7]]), f[cp[8]](o[cp[8]]), f[cp[9]](o[cp[9]])
				end
			end
		end
	end
end

-- Used to test the correcteness of ParserLib on different languages.
function lib:TestPatterns(sendToClient)
	
	local function PrintInfo(event, pattern, msg, msgTable, info)
		print("Event: " .. event)
		print("Pattern: " .. pattern)
		print("Message: " .. msg)
		print("Message Content: ")
		for k, v in pairs(msgTable) do
			print( k .. '=' .. tostring(v) )
		end
		print("info table:")
		for k, v in pairs(info) do
			print( k .. '=' .. tostring(v) )
		end	
	end
	
	LoadEverything()
	

	-- Creating the combat messages.	
	local testNumber = 123
	local message
	local messages = {}
	local t = {}
	for patternName, patternInfo in pairs(patternTable) do
		if patternInfo then
			local t2 = {}
			local message = getglobal(patternName)
			for k in pairs(t) do
				t[k] = nil
			end
			local infoType
			for i, v in ipairs(patternInfo) do			
				if i == 1 then
					infoType = patternInfo[i]
					t2.type = infoType
				else
					local field = infoMap[infoType][i-1]
					if type(v) == 'number' and v < 100 then
						if field:find("^amount") then
							t[v] = testNumber
						else
							t[v] = field:upper()
						end
					end
					t2[field] = t[v]
				end			
			end
			local i=0
			message = message:gsub("(%%%d?%$?[sd])", function()
				i = i + 1
				return tostring(t[i])
			end )
			t2.message = message
			messages[patternName] = t2
			
			-- Trailers.
			if infoType == 'hit' then
				local c = CRUSHING_TRAILER
				local g = GLANCING_TRAILER
				local r = RESIST_TRAILER:format(testNumber)
				local a = ABSORB_TRAILER:format(testNumber)
				local v = VULNERABLE_TRAILER:format(testNumber)
				local b = BLOCK_TRAILER:format(testNumber)
				messages[patternName].message = messages[patternName].message .. c .. g .. r .. a .. v .. b
			end
		end
	end
	
	
	-- Begin the test.
	
	local wrongCount = 0
	local totalCount = 0
	local msg
	local startTime = GetTime()
	local startMem = collectgarbage("count")
	
	local errorMsg
	for event, patternList in pairs(eventTable) do
		for i, pattern in ipairs(patternList) do
			totalCount = totalCount + 1
			if messages[pattern] then
				msg = messages[pattern].message
				ParseMessage(msg, event)
				if sendToClient then
					NotifyClients(event)
				end
				
				-- Check trailers.
				if info.type == 'hit' then
					if not info.isCrushing
					or not info.isGlancing
					or info.amountResist ~= testNumber
					or info.amountVulnerable ~= testNumber
					or info.amountBlock ~= testNumber
					or info.amountAbsorb ~= testNumber then
						errorMsg = "Trailer is wrong"
					end
				end
				
				if not errorMsg then
					
					for k, v in pairs(messages[pattern]) do
						if k ~= 'message' then
							if ( string.find(k, "^amount") and info[k] ~= testNumber ) then
								errorMsg = tostring(k) .. " is not number 123"
								break
							elseif info[k] ~= v then
								errorMsg = "Incorrect field " .. k .. "=" .. tostring(v)
								break
							end
							
						end
						
					end
					
				end
				
				if errorMsg then
					print(errorMsg)
					wrongCount = wrongCount + 1
					PrintInfo(event, pattern, msg, messages[pattern], info)
					self.prevMsg = msg
					return
				end
				
				
				
			end
		end
	end

	print( string.format("Test completed in %.4fs, memory cost %.2fKB.", GetTime() - startTime, collectgarbage("count") - startMem) )
	print( string.format("%d out of %d parses are wrong.", wrongCount, totalCount) )

end

-- Load all patterns and events.
function LoadEverything()
	for event, list in pairs(eventTable) do
		for i, pattern in ipairs(list) do
			if not patternTable[pattern] then
				patternTable[pattern] = LoadPatternInfo(pattern)
			end
		end
	end
end

-- Used to load patternTable elements on demand.
function LoadPatternInfo(patternName)

	local patternInfo
	
	if patternTable[patternName] then
		return patternTable[patternName]
	end

	-- buff = { "victim", "skill", "amountRank" },
	if patternName == "AURAADDEDOTHERHELPFUL" then
		patternInfo = { "buff", 1, 2, false, }
	elseif patternName == "AURAADDEDSELFHELPFUL" then
		patternInfo = { "buff", ParserLib_SELF, 1, false, }
	elseif patternName == "AURAAPPLICATIONADDEDOTHERHELPFUL" then
		patternInfo = { "buff", 1, 2, 3, }
	elseif patternName == "AURAAPPLICATIONADDEDSELFHELPFUL" then
		patternInfo = { "buff", ParserLib_SELF, 1, 2, }

	-- cast = { "source", "skill", "victim", "isBegin", "isPerform" },
	elseif patternName == "OPEN_LOCK_OTHER" then
		patternInfo = { "cast", 1, 2, 3, false, true, }
	elseif patternName == "OPEN_LOCK_SELF" then
		patternInfo = { "cast", ParserLib_SELF, 1, 2, false, true, }
	elseif patternName == "SIMPLECASTOTHEROTHER" then
		patternInfo = { "cast", 1, 2, 3, false, false, }
	elseif patternName == "SIMPLECASTOTHERSELF" then
		patternInfo = { "cast", 1, 2, ParserLib_SELF, false, false, }
	elseif patternName == "SIMPLECASTSELFOTHER" then
		patternInfo = { "cast", ParserLib_SELF, 1, 2, false, false, }
	elseif patternName == "SIMPLECASTSELFSELF" then
		patternInfo = { "cast", ParserLib_SELF, 1, ParserLib_SELF, false, false, }
	elseif patternName == "SIMPLEPERFORMOTHEROTHER" then
		patternInfo = { "cast", 1, 2, 3, false, true, }
	elseif patternName == "SIMPLEPERFORMOTHERSELF" then
		patternInfo = { "cast", 1, 2, ParserLib_SELF, false, true, }
	elseif patternName == "SIMPLEPERFORMSELFOTHER" then
		patternInfo = { "cast", ParserLib_SELF, 1, 2, false, true, }
	elseif patternName == "SIMPLEPERFORMSELFSELF" then
		patternInfo = { "cast", ParserLib_SELF, 1, ParserLib_SELF, false, true, }
	elseif patternName == "SPELLCASTOTHERSTART" then
		patternInfo = { "cast", 1, 2, false, true, false, }
	elseif patternName == "SPELLCASTSELFSTART" then
		patternInfo = { "cast", ParserLib_SELF, 1, false, true, false, }
	elseif patternName == "SPELLPERFORMOTHERSTART" then
		patternInfo = { "cast", 1, 2, false, true, true, }
	elseif patternName == "SPELLPERFORMSELFSTART" then
		patternInfo = { "cast", ParserLib_SELF, 1, false, true, true, }
	elseif patternName == "SPELLTERSEPERFORM_OTHER" then
		patternInfo = { "cast", 1, 2, false, false, true, }
	elseif patternName == "SPELLTERSEPERFORM_SELF" then
		patternInfo = { "cast", ParserLib_SELF, 1, false, false, true, }
	elseif patternName == "SPELLTERSE_OTHER" then
		patternInfo = { "cast", 1, 2, false, false, false, }
	elseif patternName == "SPELLTERSE_SELF" then
		patternInfo = { "cast", ParserLib_SELF, 1, false, false, false, }

	-- create = { "source", "item" },
	elseif patternName == "TRADESKILL_LOG_FIRSTPERSON" then
		patternInfo = { "create", ParserLib_SELF, 1, }
	elseif patternName == "TRADESKILL_LOG_THIRDPERSON" then
		patternInfo = { "create", 1, 2, }

	-- death = { "victim", "source", "skill", "isItem" },
	elseif patternName == "PARTYKILLOTHER" then
		patternInfo = { "death", 1, 2, false, false, }
	elseif patternName == "SELFKILLOTHER" then
		patternInfo = { "death", 1, ParserLib_SELF, false, false, }
	elseif patternName == "UNITDESTROYEDOTHER" then
		patternInfo = { "death", 1, false, false, true }
	elseif patternName == "UNITDIESOTHER" then
		patternInfo = { "death", 1, false, false, false, }
	elseif patternName == "UNITDIESSELF" then
		patternInfo = { "death", ParserLib_SELF, false, false, false, }
	elseif patternName == "INSTAKILLOTHER" then
		patternInfo = { "death", 1, false, 2, false, }
	elseif patternName == "INSTAKILLSELF" then
		patternInfo = { "death", ParserLib_SELF, false, 1, false }

	-- debuff = { "victim", "skill", "amountRank" },
	elseif patternName == "AURAADDEDOTHERHARMFUL" then
		patternInfo = { "debuff", 1, 2, false, }
	elseif patternName == "AURAADDEDSELFHARMFUL" then
		patternInfo = { "debuff", ParserLib_SELF, 1, false, }
	elseif patternName == "AURAAPPLICATIONADDEDOTHERHARMFUL" then
		patternInfo = { "debuff", 1, 2, 3, }
	elseif patternName == "AURAAPPLICATIONADDEDSELFHARMFUL" then
		patternInfo = { "debuff", ParserLib_SELF, 1, 2, }

	-- dispel = { "victim", "skill", "source", "isFailed" },
	elseif patternName == "AURADISPELOTHER" then
		patternInfo = { "dispel", 1, 2, false, false, }
	elseif patternName == "AURADISPELSELF" then
		patternInfo = { "dispel", ParserLib_SELF, 1, false, false, }
	elseif patternName == "DISPELFAILEDOTHEROTHER" then
		patternInfo = { "dispel", 2, 3, 1, true, }
	elseif patternName == "DISPELFAILEDOTHERSELF" then
		patternInfo = { "dispel", ParserLib_SELF, 2, 1, true, }
	elseif patternName == "DISPELFAILEDSELFOTHER" then
		patternInfo = { "dispel", 1, 2, ParserLib_SELF, true, }
	elseif patternName == "DISPELFAILEDSELFSELF" then
		patternInfo = { "dispel", ParserLib_SELF, 1, ParserLib_SELF, true, }
	-- WoW2.0 new patterns : more info needed.
	--[[
			SPELLPOWERDRAINOTHER = "%s drains %d %s from %s."
			SPELLPOWERDRAINSELF = "%s drains %d %s from you."
	]]

	-- drain = { "source", "victim", "skill", "amount", "attribute" },
	elseif patternName == "SPELLPOWERDRAINOTHEROTHER" then
		patternInfo = { "drain", 1, 5, 2, 3, 4, }
	elseif patternName == "SPELLPOWERDRAINOTHERSELF" then
		patternInfo = { "drain", 1, ParserLib_SELF, 2, 3, 4, }
	elseif patternName == "SPELLPOWERDRAINSELFOTHER" then
		patternInfo = { "drain", ParserLib_SELF, 4, 1, 2, 3, }
	elseif patternName == "SPELLPOWERDRAINSELFSELF" then
		patternInfo = { "drain", ParserLib_SELF, ParserLib_SELF, 1, 2, 3, }

	-- 	durability = { "source", "skill", "victim", "item" }, -- is not item then isAllItems = true
	elseif patternName == "SPELLDURABILITYDAMAGEALLOTHEROTHER" then
		patternInfo = { "durability", 1, 2, 3, false, }
	elseif patternName == "SPELLDURABILITYDAMAGEALLOTHERSELF" then
		patternInfo = { "durability", 1, 2, ParserLib_SELF, false, }
	elseif patternName == "SPELLDURABILITYDAMAGEALLSELFOTHER" then
		patternInfo = { "durability", ParserLib_SELF, 1, 2, false, }
	elseif patternName == "SPELLDURABILITYDAMAGEOTHEROTHER" then
		patternInfo = { "durability", 1, 2, 3, 4, }
	elseif patternName == "SPELLDURABILITYDAMAGEOTHERSELF" then
		patternInfo = { "durability", 1, 2, ParserLib_SELF, 3, }
	elseif patternName == "SPELLDURABILITYDAMAGESELFOTHER" then
		patternInfo = { "durability", ParserLib_SELF, 1, 2, 3, }

	-- enchant = { "source", "victim", "skill", "item" },
	elseif patternName == "ITEMENCHANTMENTADDOTHEROTHER" then
		patternInfo = { "enchant", 1, 3, 2, 4, }
	elseif patternName == "ITEMENCHANTMENTADDOTHERSELF" then
		patternInfo = { "enchant", 1, ParserLib_SELF, 2, 3, }
	elseif patternName == "ITEMENCHANTMENTADDSELFOTHER" then
		patternInfo = { "enchant", ParserLib_SELF, 2, 1, 3, }
	elseif patternName == "ITEMENCHANTMENTADDSELFSELF" then
		patternInfo = { "enchant", ParserLib_SELF, ParserLib_SELF, 1, 2, }

	-- environment = { "victim", "amount", "damageType" },
	elseif patternName == "VSENVIRONMENTALDAMAGE_DROWNING_OTHER" then
		patternInfo = { "environment", 1, 2, "drown", }
	elseif patternName == "VSENVIRONMENTALDAMAGE_DROWNING_SELF" then
		patternInfo = { "environment", ParserLib_SELF, 1, "drown", }
	elseif patternName == "VSENVIRONMENTALDAMAGE_FALLING_OTHER" then
		patternInfo = { "environment", 1, 2, "fall", }
	elseif patternName == "VSENVIRONMENTALDAMAGE_FALLING_SELF" then
		patternInfo = { "environment", ParserLib_SELF, 1, "fall", }
	elseif patternName == "VSENVIRONMENTALDAMAGE_FATIGUE_OTHER" then
		patternInfo = { "environment", 1, 2, "exhaust", }
	elseif patternName == "VSENVIRONMENTALDAMAGE_FATIGUE_SELF" then
		patternInfo = { "environment", ParserLib_SELF, 1, "exhaust", }
	elseif patternName == "VSENVIRONMENTALDAMAGE_FIRE_OTHER" then
		patternInfo = { "environment", 1, 2, "fire", }
	elseif patternName == "VSENVIRONMENTALDAMAGE_FIRE_SELF" then
		patternInfo = { "environment", ParserLib_SELF, 1, "fire", }
	elseif patternName == "VSENVIRONMENTALDAMAGE_LAVA_OTHER" then
		patternInfo = { "environment", 1, 2, "lava", }
	elseif patternName == "VSENVIRONMENTALDAMAGE_LAVA_SELF" then
		patternInfo = { "environment", ParserLib_SELF, 1, "lava", }
	elseif patternName == "VSENVIRONMENTALDAMAGE_SLIME_OTHER" then
		patternInfo = { "environment", 1, 2, "slime", }
	elseif patternName == "VSENVIRONMENTALDAMAGE_SLIME_SELF" then
		patternInfo = { "environment", ParserLib_SELF, 1, "slime", }

	-- experience = { "amount", "source", "bonusAmount", "bonusType", "penaltyAmount", "penaltyType", "amountRaidPenalty", "amountGroupBonus", "victim" },
	elseif patternName == "COMBATLOG_XPGAIN" then
		patternInfo = { "experience", 2, false, false, false, false, false, false, false, 1, }
	elseif patternName == "COMBATLOG_XPGAIN_EXHAUSTION1" then
		patternInfo = { "experience", 2, 1, 3, 4, false, false, false, false, false, }
	elseif patternName == "COMBATLOG_XPGAIN_EXHAUSTION1_GROUP" then
		patternInfo = { "experience", 2, 1, 3, 4, false, false, false, 5, false, }
	elseif patternName == "COMBATLOG_XPGAIN_EXHAUSTION1_RAID" then
		patternInfo = { "experience", 2, 1, 3, 4, false, false, 5, false, false, }
	elseif patternName == "COMBATLOG_XPGAIN_EXHAUSTION2" then
		patternInfo = { "experience", 2, 1, 3, 4, false, false, false, false, false, }
	elseif patternName == "COMBATLOG_XPGAIN_EXHAUSTION2_GROUP" then
		patternInfo = { "experience", 2, 1, 3, 4, false, false, false, 5, false, }
	elseif patternName == "COMBATLOG_XPGAIN_EXHAUSTION2_RAID" then
		patternInfo = { "experience", 2, 1, 3, 4, false, false, 5, false, false, }
	elseif patternName == "COMBATLOG_XPGAIN_EXHAUSTION4" then
		patternInfo = { "experience", 2, 1, false, false, 3, 4, false, false, false, }
	elseif patternName == "COMBATLOG_XPGAIN_EXHAUSTION4_GROUP" then
		patternInfo = { "experience", 2, 1, false, false, 3, 4, false, 5, false, }
	elseif patternName == "COMBATLOG_XPGAIN_EXHAUSTION4_RAID" then
		patternInfo = { "experience", 2, 1, false, false, 3, 4, 5, false, false, }
	elseif patternName == "COMBATLOG_XPGAIN_EXHAUSTION5" then
		patternInfo = { "experience", 2, 1, false, false, 3, 4, false, false, false, }
	elseif patternName == "COMBATLOG_XPGAIN_EXHAUSTION5_GROUP" then
		patternInfo = { "experience", 2, 1, false, false, 3, 4, false, 5, false, }
	elseif patternName == "COMBATLOG_XPGAIN_EXHAUSTION5_RAID" then
		patternInfo = { "experience", 2, 1, false, false, 3, 4, 5, false, false, }
	elseif patternName == "COMBATLOG_XPGAIN_FIRSTPERSON" then
		patternInfo = { "experience", 2, 1, false, false, false, false, false, false, false, }
	elseif patternName == "COMBATLOG_XPGAIN_FIRSTPERSON_GROUP" then
		patternInfo = { "experience", 2, 1, false, false, false, false, false, 3, false, }
	elseif patternName == "COMBATLOG_XPGAIN_FIRSTPERSON_RAID" then
		patternInfo = { "experience", 2, 1, false, false, false, false, 3, false, false, }
	elseif patternName == "COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED" then
		patternInfo = { "experience", 1, false, false, false, false, false, false, false, false, }
	elseif patternName == "COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED_GROUP" then
		patternInfo = { "experience", 1, false, false, false, false, false, false, 2, false, }
	elseif patternName == "COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED_RAID" then
		patternInfo = { "experience", 1, false, false, false, false, false, 2, false, false, }
	elseif patternName == "COMBATLOG_XPLOSS_FIRSTPERSON_UNNAMED" then
		patternInfo = { "experience", 1, false, false, false, false, false, false, false, false, }

	-- extraattack = { "victim", "skill", "amount" },
	elseif patternName == "SPELLEXTRAATTACKSOTHER" then
		patternInfo = { "extraattack", 1, 3, 2, }
	elseif patternName == "SPELLEXTRAATTACKSOTHER_SINGULAR" then
		patternInfo = { "extraattack", 1, 3, 2, }
	elseif patternName == "SPELLEXTRAATTACKSSELF" then
		patternInfo = { "extraattack", ParserLib_SELF, 2, 1, }
	elseif patternName == "SPELLEXTRAATTACKSSELF_SINGULAR" then
		patternInfo = { "extraattack", ParserLib_SELF, 2, 1, }

	-- fade = { "victim", "skill" },
	elseif patternName == "AURAREMOVEDOTHER" then
		patternInfo = { "fade", 2, 1, }
	elseif patternName == "AURAREMOVEDSELF" then
		patternInfo = { "fade", ParserLib_SELF, 1, }

	-- fail = { "source", "skill", "reason" },
	elseif patternName == "SPELLFAILCASTSELF" then
		patternInfo = { "fail", ParserLib_SELF, 1, 2, }
	elseif patternName == "SPELLFAILPERFORMSELF" then
		patternInfo = { "fail", ParserLib_SELF, 1, 2, }

	-- feedpet = { "victim", "item" },
	elseif patternName == "FEEDPET_LOG_FIRSTPERSON" then
		patternInfo = { "feedpet", ParserLib_SELF, 1, }
	elseif patternName == "FEEDPET_LOG_THIRDPERSON" then
		patternInfo = { "feedpet", 1, 2, }

	-- gain = { "source", "victim", "skill", "amount", "attribute" },
	elseif patternName == "POWERGAINOTHEROTHER" then
		patternInfo = { "gain", 4, 1, 5, 2, 3, }
	elseif patternName == "POWERGAINOTHERSELF" then
		patternInfo = { "gain", 3, ParserLib_SELF, 4, 1, 2, }
	elseif patternName == "POWERGAINSELFOTHER" then
		patternInfo = { "gain", ParserLib_SELF, 1, 4, 2, 3, }
	elseif patternName == "POWERGAINSELFSELF" then
		patternInfo = { "gain", ParserLib_SELF, ParserLib_SELF, 3, 1, 2, }
	-- WoW2.0 new patterns : more info needed.
	--[[
	POWERGAINOTHER = "%s gains %d %s from %s."
	POWERGAINSELF = "You gain %d %s from %s."
	]]

	-- heal = { "source", "victim", "skill", "amount", "isCrit", "isDOT" },
	elseif patternName == "HEALEDCRITOTHEROTHER" then
		patternInfo = { "heal", 1, 3, 2, 4, true, false, }
	elseif patternName == "HEALEDCRITOTHERSELF" then
		patternInfo = { "heal", 1, ParserLib_SELF, 2, 3, true, false, }
	elseif patternName == "HEALEDCRITSELFOTHER" then
		patternInfo = { "heal", ParserLib_SELF, 2, 1, 3, true, false, }
	elseif patternName == "HEALEDCRITSELFSELF" then
		patternInfo = { "heal", ParserLib_SELF, ParserLib_SELF, 1, 2, true, false, }
	elseif patternName == "HEALEDOTHEROTHER" then
		patternInfo = { "heal", 1, 3, 2, 4, false, false, }
	elseif patternName == "HEALEDOTHERSELF" then
		patternInfo = { "heal", 1, ParserLib_SELF, 2, 3, false, false, }
	elseif patternName == "HEALEDSELFOTHER" then
		patternInfo = { "heal", ParserLib_SELF, 2, 1, 3, false, false, }
	elseif patternName == "HEALEDSELFSELF" then
		patternInfo = { "heal", ParserLib_SELF, ParserLib_SELF, 1, 2, false, false, }
	elseif patternName == "PERIODICAURAHEALOTHEROTHER" then
		patternInfo = { "heal", 3, 1, 4, 2, false, true, }
	elseif patternName == "PERIODICAURAHEALOTHERSELF" then
		patternInfo = { "heal", 2, ParserLib_SELF, 3, 1, false, true, }
	elseif patternName == "PERIODICAURAHEALSELFOTHER" then
		patternInfo = { "heal", ParserLib_SELF, 1, 3, 2, false, true, }
	elseif patternName == "PERIODICAURAHEALSELFSELF" then
		patternInfo = { "heal", ParserLib_SELF, ParserLib_SELF, 2, 1, false, true, }
	-- WoW2.0 new patterns - more info needed.
	--[[
	HEALEDCRITOTHER = "%s critically heals %s for %d."
	HEALEDCRITSELF = "%s critically heals you for %d."
	HEALEDOTHER = "%s heals %s for %d."
	HEALEDSELF = "%s's %s heals you for %d."
	PERIODICAURAHEALOTHER = "%s gains %d health from %s."
	PERIODICAURAHEALSELF = "You gain %d health from %s."
	]]

	-- hit = { "source", "victim", "skill", "amount", "element", "isCrit", "isDOT", "isSplit" },
	elseif patternName == "COMBATHITCRITOTHEROTHER" then
		patternInfo = { "hit", 1, 2, ParserLib_MELEE, 3, false, true, false, false, }
	elseif patternName == "COMBATHITCRITOTHERSELF" then
		patternInfo = { "hit", 1, ParserLib_SELF, ParserLib_MELEE, 2, false, true, false, false, }
	elseif patternName == "COMBATHITCRITSCHOOLOTHEROTHER" then
		patternInfo = { "hit", 1, 2, ParserLib_MELEE, 3, 4, true, false, false, }
	elseif patternName == "COMBATHITCRITSCHOOLOTHERSELF" then
		patternInfo = { "hit", 1, ParserLib_SELF, ParserLib_MELEE, 2, 3, true, false, false, }
	elseif patternName == "COMBATHITCRITSCHOOLSELFOTHER" then
		patternInfo = { "hit", ParserLib_SELF, 1, ParserLib_MELEE, 2, 3, true, false, false, }
	elseif patternName == "COMBATHITCRITSELFOTHER" then
		patternInfo = { "hit", ParserLib_SELF, 1, ParserLib_MELEE, 2, false, true, false, false, }
	elseif patternName == "COMBATHITOTHEROTHER" then
		patternInfo = { "hit", 1, 2, ParserLib_MELEE, 3, false, false, false, false, }
	elseif patternName == "COMBATHITOTHERSELF" then
		patternInfo = { "hit", 1, ParserLib_SELF, ParserLib_MELEE, 2, false, false, false, false, }
	elseif patternName == "COMBATHITSCHOOLOTHEROTHER" then
		patternInfo = { "hit", 1, 2, ParserLib_MELEE, 3, 4, false, false, false, }
	elseif patternName == "COMBATHITSCHOOLOTHERSELF" then
		patternInfo = { "hit", 1, ParserLib_SELF, ParserLib_MELEE, 2, 3, false, false, false, }
	elseif patternName == "COMBATHITSCHOOLSELFOTHER" then
		patternInfo = { "hit", ParserLib_SELF, 1, ParserLib_MELEE, 2, 3, false, false, false, }
	elseif patternName == "COMBATHITSELFOTHER" then
		patternInfo = { "hit", ParserLib_SELF, 1, ParserLib_MELEE, 2, false, false, false, false, }
	elseif patternName == "DAMAGESHIELDOTHEROTHER" then
		patternInfo = { "hit", 1, 4, ParserLib_DAMAGESHIELD, 2, 3, false, false, false, }
	elseif patternName == "DAMAGESHIELDOTHERSELF" then
		patternInfo = { "hit", 1, ParserLib_SELF, ParserLib_DAMAGESHIELD, 2, 3, false, false, false, }
	elseif patternName == "DAMAGESHIELDSELFOTHER" then
		patternInfo = { "hit", ParserLib_SELF, 3, ParserLib_DAMAGESHIELD, 1, 2, false, false, false, }
	elseif patternName == "PERIODICAURADAMAGEOTHEROTHER" then
		patternInfo = { "hit", 4, 1, 5, 2, 3, false, true, false, }
	elseif patternName == "PERIODICAURADAMAGEOTHERSELF" then
		patternInfo = { "hit", 3, ParserLib_SELF, 4, 1, 2, false, true, false, }
	elseif patternName == "PERIODICAURADAMAGESELFOTHER" then
		patternInfo = { "hit", ParserLib_SELF, 1, 4, 2, 3, false, true, false, }
	elseif patternName == "PERIODICAURADAMAGESELFSELF" then
		patternInfo = { "hit", ParserLib_SELF, ParserLib_SELF, 3, 1, 2, false, true, false, }
	elseif patternName == "SPELLLOGCRITOTHEROTHER" then
		patternInfo = { "hit", 1, 3, 2, 4, false, true, false, false, }
	elseif patternName == "SPELLLOGCRITOTHERSELF" then
		patternInfo = { "hit", 1, ParserLib_SELF, 2, 3, false, true, false, false, }
	elseif patternName == "SPELLLOGCRITSCHOOLOTHEROTHER" then
		patternInfo = { "hit", 1, 3, 2, 4, 5, true, false, false, }
	elseif patternName == "SPELLLOGCRITSCHOOLOTHERSELF" then
		patternInfo = { "hit", 1, ParserLib_SELF, 2, 3, 4, true, false, false, }
	elseif patternName == "SPELLLOGCRITSCHOOLSELFOTHER" then
		patternInfo = { "hit", ParserLib_SELF, 2, 1, 3, 4, true, false, false, }
	elseif patternName == "SPELLLOGCRITSCHOOLSELFSELF" then
		patternInfo = { "hit", ParserLib_SELF, ParserLib_SELF, 1, 2, 3, true, false, false, }
	elseif patternName == "SPELLLOGCRITSELFOTHER" then
		patternInfo = { "hit", ParserLib_SELF, 2, 1, 3, false, true, false, false, }
	elseif patternName == "SPELLLOGCRITSELFSELF" then
		patternInfo = { "hit", ParserLib_SELF, ParserLib_SELF, 1, 2, false, true, false, false, }
	elseif patternName == "SPELLLOGOTHEROTHER" then
		patternInfo = { "hit", 1, 3, 2, 4, false, false, false, false, }
	elseif patternName == "SPELLLOGOTHERSELF" then
		patternInfo = { "hit", 1, ParserLib_SELF, 2, 3, false, false, false, false, }
	elseif patternName == "SPELLLOGSCHOOLOTHEROTHER" then
		patternInfo = { "hit", 1, 3, 2, 4, 5, false, false, false, }
	elseif patternName == "SPELLLOGSCHOOLOTHERSELF" then
		patternInfo = { "hit", 1, ParserLib_SELF, 2, 3, 4, false, false, false, }
	elseif patternName == "SPELLLOGSCHOOLSELFOTHER" then
		patternInfo = { "hit", ParserLib_SELF, 2, 1, 3, 4, false, false, false, }
	elseif patternName == "SPELLLOGSCHOOLSELFSELF" then
		patternInfo = { "hit", ParserLib_SELF, ParserLib_SELF, 1, 2, 3, false, false, false, }
	elseif patternName == "SPELLLOGSELFOTHER" then
		patternInfo = { "hit", ParserLib_SELF, 2, 1, 3, false, false, false, false, }
	elseif patternName == "SPELLLOGSELFSELF" then
		patternInfo = { "hit", ParserLib_SELF, ParserLib_SELF, 1, 2, false, false, false, false, }
	elseif patternName == "SPELLSPLITDAMAGEOTHEROTHER" then
		patternInfo = { "hit", 1, 3, 2, 4, false, false, false, true, }
	elseif patternName == "SPELLSPLITDAMAGEOTHERSELF" then
		patternInfo = { "hit", 1, ParserLib_SELF, 2, 3, false, false, false, true, }
	elseif patternName == "SPELLSPLITDAMAGESELFOTHER" then
		patternInfo = { "hit", ParserLib_SELF, 2, 1, 3, false, false, false, true, }
	-- WoW2.0 new patterns.
	elseif patternName == "PERIODICAURADAMAGEOTHER" then -- "%s suffers %d %s damage from %s."
		patternInfo = { "hit", 1, 1, 4, 2, 3, false, true, false, }	-- NOTE: Source is incorrect!
	elseif patternName == "PERIODICAURADAMAGESELF" then -- "You suffer %d %s damage from %s."
		patternInfo = { "hit", ParserLib_SELF, ParserLib_SELF, 3, 1, 2, false, true, false, } -- NOTE: Source is incorrect!
	-- WoW2.0 new patterns : more info needed.
	--[[
		SPELLLOGCRITSCHOOLOTHER = "%s crits %s for %d %s damage."
		SPELLLOGCRITSCHOOLSELF = "%s crits you for %d %s damage."
		SPELLLOGCRITSELF = "%s crits you for %d."
		SPELLLOGOTHER = "%s hits %s for %d."
		SPELLLOGSCHOOLOTHER = "%s hits %s for %d %s damage."
		SPELLLOGSCHOOLSELF = "%s hits you for %d %s damage."
		SPELLLOGSELF = "%s hits you for %d."
	]]

	-- honor = { "amount", "source", "sourceRank" }, -- if amount == false then isDishonor = true.
	elseif patternName == "COMBATLOG_DISHONORGAIN" then
		patternInfo = { "honor", false, 1, false, }
	elseif patternName == "COMBATLOG_HONORAWARD" then
		patternInfo = { "honor", 1, false, false, }
	elseif patternName == "COMBATLOG_HONORGAIN" then
		patternInfo = { "honor", 3, 1, 2, }

	-- interrupt = { "source", "victim", "skill" },
	elseif patternName == "SPELLINTERRUPTOTHEROTHER" then
		patternInfo = { "interrupt", 1, 2, 3, }
	elseif patternName == "SPELLINTERRUPTOTHERSELF" then
		patternInfo = { "interrupt", 1, ParserLib_SELF, 2, }
	elseif patternName == "SPELLINTERRUPTSELFOTHER" then
		patternInfo = { "interrupt", ParserLib_SELF, 1, 2, }

	-- leech = { "source", "victim", "skill", "amount", "attribute", "sourceGained", "amountGained", "attributeGained" },
	elseif patternName == "SPELLPOWERLEECHOTHEROTHER" then
		patternInfo = { "leech", 1, 5, 2, 3, 4, 6, 7, 8, }
	elseif patternName == "SPELLPOWERLEECHOTHERSELF" then
		patternInfo = { "leech", 1, ParserLib_SELF, 2, 3, 4, 5, 6, 7, }
	elseif patternName == "SPELLPOWERLEECHSELFOTHER" then
		patternInfo = { "leech", ParserLib_SELF, 4, 1, 2, 3, ParserLib_SELF, 5, 6, }

	-- miss = { "source", "victim", "skill", "missType" },
	elseif patternName == "IMMUNEDAMAGECLASSOTHEROTHER" then
		patternInfo = { "miss", 2, 1, ParserLib_MELEE, "immune", }
	elseif patternName == "IMMUNEDAMAGECLASSOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, ParserLib_MELEE, "immune", }
	elseif patternName == "IMMUNEDAMAGECLASSSELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 1, ParserLib_MELEE, "immune", }
	elseif patternName == "IMMUNEOTHEROTHER" then
		patternInfo = { "miss", 1, 2, ParserLib_MELEE, "immune", }
	elseif patternName == "IMMUNEOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, ParserLib_MELEE, "immune", }
	elseif patternName == "IMMUNESELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 1, ParserLib_MELEE, "immune", }
	elseif patternName == "IMMUNESELFSELF" then
		patternInfo = { "miss", ParserLib_SELF, ParserLib_SELF, ParserLib_MELEE, "immune", }
	elseif patternName == "IMMUNESPELLOTHEROTHER" then
		patternInfo = { "miss", 2, 1, 3, "immune", }
	elseif patternName == "IMMUNESPELLOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, 2, "immune", }
	elseif patternName == "IMMUNESPELLSELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 1, 2, "immune", }
	elseif patternName == "IMMUNESPELLSELFSELF" then
		patternInfo = { "miss", ParserLib_SELF, ParserLib_SELF, 1, "immune", }
	elseif patternName == "MISSEDOTHEROTHER" then
		patternInfo = { "miss", 1, 2, ParserLib_MELEE, "miss", }
	elseif patternName == "MISSEDOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, ParserLib_MELEE, "miss", }
	elseif patternName == "MISSEDSELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 1, ParserLib_MELEE, "miss", }
	elseif patternName == "PROCRESISTOTHEROTHER" then
		patternInfo = { "miss", 2, 1, 3, "resist", }
	elseif patternName == "PROCRESISTOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, 2, "resist", }
	elseif patternName == "PROCRESISTSELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 1, 2, "resist", }
	elseif patternName == "PROCRESISTSELFSELF" then
		patternInfo = { "miss", ParserLib_SELF, ParserLib_SELF, 1, "resist", }
	elseif patternName == "SPELLBLOCKEDOTHEROTHER" then
		patternInfo = { "miss", 1, 3, 2, "block", }
	elseif patternName == "SPELLBLOCKEDOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, 2, "block", }
	elseif patternName == "SPELLBLOCKEDSELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 2, 1, "block", }
	elseif patternName == "SPELLDEFLECTEDOTHEROTHER" then
		patternInfo = { "miss", 1, 3, 2, "deflect", }
	elseif patternName == "SPELLDEFLECTEDOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, 2, "deflect", }
	elseif patternName == "SPELLDEFLECTEDSELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 2, 1, "deflect", }
	elseif patternName == "SPELLDEFLECTEDSELFSELF" then
		patternInfo = { "miss", ParserLib_SELF, ParserLib_SELF, 1, "deflect", }
	elseif patternName == "SPELLDODGEDOTHEROTHER" then
		patternInfo = { "miss", 1, 3, 2, "dodge", }
	elseif patternName == "SPELLDODGEDOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, 2, "dodge", }
	elseif patternName == "SPELLDODGEDSELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 2, 1, "dodge", }
	elseif patternName == "SPELLDODGEDSELFSELF" then
		patternInfo = { "miss", ParserLib_SELF, ParserLib_SELF, 1, "dodge", }
	elseif patternName == "SPELLEVADEDOTHEROTHER" then
		patternInfo = { "miss", 1, 3, 2, "evade", }
	elseif patternName == "SPELLEVADEDOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, 2, "evade", }
	elseif patternName == "SPELLEVADEDSELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 2, 1, "evade", }
	elseif patternName == "SPELLEVADEDSELFSELF" then
		patternInfo = { "miss", ParserLib_SELF, ParserLib_SELF, 1, "evade", }
	elseif patternName == "SPELLIMMUNEOTHEROTHER" then
		patternInfo = { "miss", 1, 3, 2, "immune", }
	elseif patternName == "SPELLIMMUNEOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, 2, "immune", }
	elseif patternName == "SPELLIMMUNESELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 2, 1, "immune", }
	elseif patternName == "SPELLIMMUNESELFSELF" then
		patternInfo = { "miss", ParserLib_SELF, ParserLib_SELF, 1, "immune", }
	elseif patternName == "SPELLLOGABSORBOTHEROTHER" then
		patternInfo = { "miss", 1, 3, 2, "absorb", }
	elseif patternName == "SPELLLOGABSORBOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, 2, "absorb", }
	elseif patternName == "SPELLLOGABSORBSELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 2, 1, "absorb", }
	elseif patternName == "SPELLLOGABSORBSELFSELF" then
		patternInfo = { "miss", ParserLib_SELF, ParserLib_SELF, 1, "absorb", }
	elseif patternName == "SPELLMISSOTHEROTHER" then
		patternInfo = { "miss", 1, 3, 2, "miss", }
	elseif patternName == "SPELLMISSOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, 2, "miss", }
	elseif patternName == "SPELLMISSSELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 2, 1, "miss", }
	elseif patternName == "SPELLMISSSELFSELF" then
		patternInfo = { "miss", ParserLib_SELF, ParserLib_SELF, 1, "miss", }
	elseif patternName == "SPELLPARRIEDOTHEROTHER" then
		patternInfo = { "miss", 1, 3, 2, "parry", }
	elseif patternName == "SPELLPARRIEDOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, 2, "parry", }
	elseif patternName == "SPELLPARRIEDSELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 2, 1, "parry", }
	elseif patternName == "SPELLPARRIEDSELFSELF" then
		patternInfo = { "miss", ParserLib_SELF, ParserLib_SELF, 1, "parry", }
	elseif patternName == "SPELLREFLECTOTHEROTHER" then
		patternInfo = { "miss", 1, 3, 2, "reflect", }
	elseif patternName == "SPELLREFLECTOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, 2, "reflect", }
	elseif patternName == "SPELLREFLECTSELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 2, 1, "reflect", }
	elseif patternName == "SPELLREFLECTSELFSELF" then
		patternInfo = { "miss", ParserLib_SELF, ParserLib_SELF, 1, "reflect", }
	elseif patternName == "SPELLRESISTOTHEROTHER" then
		patternInfo = { "miss", 1, 3, 2, "resist", }
	elseif patternName == "SPELLRESISTOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, 2, "resist", }
	elseif patternName == "SPELLRESISTSELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 2, 1, "resist", }
	elseif patternName == "SPELLRESISTSELFSELF" then
		patternInfo = { "miss", ParserLib_SELF, ParserLib_SELF, 1, "resist", }
	elseif patternName == "VSABSORBOTHEROTHER" then
		patternInfo = { "miss", 1, 2, ParserLib_MELEE, "absorb", }
	elseif patternName == "VSABSORBOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, ParserLib_MELEE, "absorb", }
	elseif patternName == "VSABSORBSELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 1, ParserLib_MELEE, "absorb", }
	elseif patternName == "VSBLOCKOTHEROTHER" then
		patternInfo = { "miss", 1, 2, ParserLib_MELEE, "block", }
	elseif patternName == "VSBLOCKOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, ParserLib_MELEE, "block", }
	elseif patternName == "VSBLOCKSELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 1, ParserLib_MELEE, "block", }
	elseif patternName == "VSDEFLECTOTHEROTHER" then
		patternInfo = { "miss", 1, 2, ParserLib_MELEE, "deflect", }
	elseif patternName == "VSDEFLECTOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, ParserLib_MELEE, "deflect", }
	elseif patternName == "VSDEFLECTSELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 1, ParserLib_MELEE, "deflect", }
	elseif patternName == "VSDODGEOTHEROTHER" then
		patternInfo = { "miss", 1, 2, ParserLib_MELEE, "dodge", }
	elseif patternName == "VSDODGEOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, ParserLib_MELEE, "dodge", }
	elseif patternName == "VSDODGESELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 1, ParserLib_MELEE, "dodge", }
	elseif patternName == "VSEVADEOTHEROTHER" then
		patternInfo = { "miss", 1, 2, ParserLib_MELEE, "evade", }
	elseif patternName == "VSEVADEOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, ParserLib_MELEE, "evade", }
	elseif patternName == "VSEVADESELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 1, ParserLib_MELEE, "evade", }
	elseif patternName == "VSIMMUNEOTHEROTHER" then
		patternInfo = { "miss", 1, 2, ParserLib_MELEE, "immune", }
	elseif patternName == "VSIMMUNEOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, ParserLib_MELEE, "immune", }
	elseif patternName == "VSIMMUNESELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 1, ParserLib_MELEE, "immune", }
	elseif patternName == "VSPARRYOTHEROTHER" then
		patternInfo = { "miss", 1, 2, ParserLib_MELEE, "parry", }
	elseif patternName == "VSPARRYOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, ParserLib_MELEE, "parry", }
	elseif patternName == "VSPARRYSELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 1, ParserLib_MELEE, "parry", }
	elseif patternName == "VSRESISTOTHEROTHER" then
		patternInfo = { "miss", 1, 2, ParserLib_MELEE, "resist", }
	elseif patternName == "VSRESISTOTHERSELF" then
		patternInfo = { "miss", 1, ParserLib_SELF, ParserLib_MELEE, "resist", }
	elseif patternName == "VSRESISTSELFOTHER" then
		patternInfo = { "miss", ParserLib_SELF, 1, ParserLib_MELEE, "resist", }
	-- WoW2.0 new patterns : more info needed.
	--[[
		IMMUNESPELLOTHER = "%s is immune to %s."
		IMMUNESPELLSELF = "You are immune to %s."
		SPELLIMMUNEOTHER = "%s fails. %s is immune."
		SPELLIMMUNESELF = "%s failed. You are immune."
		SPELLLOGABSORBOTHER = "%s is absorbed by %s."
		SPELLLOGABSORBSELF = "You absorb %s."
		SPELLRESISTOTHER = "%s was resisted by %s."
		SPELLRESISTSELF = "%s was resisted."
	]]

	-- reputation = { "faction", "amount", "rank", "isNegative" },
	elseif patternName == "FACTION_STANDING_CHANGED" then
		patternInfo = { "reputation", 2, false, 1, false, }
	elseif patternName == "FACTION_STANDING_DECREASED" then
		patternInfo = { "reputation", 1, 2, false, true, }
	elseif patternName == "FACTION_STANDING_INCREASED" then
		patternInfo = { "reputation", 1, 2, false, false, }
	end

	if not patternInfo then
		return false
	end

	-- Get the pattern from GlobalStrings.lua
	local pattern = _G[patternName]

	if not pattern then
		return false
	end


	
	-- How many regexp tokens in this pattern?
	local tc = 0
	for _ in pattern:gmatch("%%%d?%$?([sd])") do tc = tc + 1 end

	-- Record index of numeric tokens.
	local i = 0
	local nf
	string.gsub(pattern, "%%%d?%$?([sd])", function(capsule)
		i=i+1
		if capsule == 'd' then
			if not nf then
				nf = i
			elseif type(nf) == 'number' then	
				nf = { nf }
				table.insert(nf, i)
			else		
				table.insert(nf, i)
			end			
		end
	end )
	

	-- Store extra returns into t.
	local function GetConvertReturns(t, pattern, ...)
		for k in pairs(t) do
			t[k] = nil
		end
		for i=1, select('#', ...) do
			t[i] = select(i, ...)
		end
		return pattern, t
	end
			
	-- Convert string.format tokens into LUA regexp tokens.
	pattern, info = GetConvertReturns(info, ConvertPattern(pattern, true) )

	if next(info) then	
		for j in pairs(patternInfo) do
			if type(patternInfo[j]) == "number" and patternInfo[j] < 100 then
				patternInfo[j] = info[patternInfo[j]]	-- Remap to correct token sequence.
			end
		end
	end

	patternInfo.nf = nf
	patternInfo.tc = tc
	patternInfo.pattern = pattern


	return patternInfo
end


--------------------------------
--      Load this bitch!      --
--------------------------------
libobj:Register(lib)

function ConvertGlobalString(name, first)
	-- Check if the passed global string does not exist.
	local str = _G[name]
	if not str then
		return
	end


	-- Hold the capture order.
	local captureOrder
	local numCaptures = 0

	-- Escape lua magic chars.
	local pattern = str:gsub("([%(%)%.%*%+%-%[%]%?%^%$%%])", "%%%1")
	
	if pattern:find("%$") then
		captureOrder = {}
		-- Loop through each capture and setup the capture order.
		for index in pattern:gmatch("%%%%(%d)%%%$[sd]") do
			numCaptures = numCaptures + 1
			captureOrder[tonumber(index)] = numCaptures
		end
		-- Convert %1$s to (.+) and %1$d to (%d+).
		pattern = pattern:gsub("%%%%%d%%%$s", "(.+)")
		pattern = pattern:gsub("%%%%%d%%%$d", "(%%d+)")
	else
		-- Convert %s to (.+) and %d to (%d+).
		pattern = pattern:gsub("%%%%s", "(.+)")
		pattern = pattern:gsub("%%%%d", "(%%d+)")
	end
	

	if first then
		pattern = "^" .. pattern
	end
	
	return pattern, captureOrder and unpack(captureOrder)

end
