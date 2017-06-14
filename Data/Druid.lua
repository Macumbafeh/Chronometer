--<< ====================================================================== >>--
-- Setup Timers                                                               --
--<< ====================================================================== >>--
local BS = AceLibrary("Babble-Spell-2.2")
local L = AceLibrary("AceLocale-2.2"):new("Chronometer")

function Chronometer:DruidSetup()
	local _, eclass = UnitClass("player")
	if eclass ~= "DRUID" then return end

	self:AddGroup(1, true,  "MAGENTA")
	self:AddGroup(2, false, "MAROON")
	self:AddGroup(3, true,  "MAGENTA")
	self:AddGroup(4, true,  "MAGENTA")

	self:AddTimer(self.SPELL, BS["Abolish Poison"],         8, 1,1,1)
	self:AddTimer(self.SPELL, BS["Bash"],                   2, 1,0,0, { d={rs=1, tn=BS["Brutal Impact"], tb=0.5}, dr=1 })
	self:AddTimer(self.SPELL, BS["Barkskin"],              15, 0,1,1)
	self:AddTimer(self.SPELL, BS["Challenging Roar"],       6, 0,0,0)
	self:AddTimer(self.SPELL, BS["Dash"],                  15, 0,1,1)
	self:AddTimer(self.SPELL, BS["Demoralizing Roar"],     30, 0,0,0)
	self:AddTimer(self.SPELL, BS["Enrage"],                10, 0,1,1)
	self:AddTimer(self.SPELL, BS["Entangling Roots"],      27, 1,0,0, { gr=1, d={rt={12,15,18,21,24}}, dr=2 })
	self:AddTimer(self.SPELL, BS["Faerie Fire"],           40, 1,0,0, { gr=2 })
	self:AddTimer(self.SPELL, BS["Faerie Fire (Feral)"],   40, 1,0,0, { gr=2 })
	self:AddTimer(self.SPELL, BS["Feral Charge"],           4, 1,0,0)
	self:AddTimer(self.SPELL, BS["Frenzied Regeneration"], 10, 0,1,1)
	self:AddTimer(self.SPELL, BS["Hibernate"],             20, 1,0,0, { gr=3, d={rs=10}  })
	self:AddTimer(self.SPELL, BS["Innervate"],             20, 1,1,1)
	self:AddTimer(self.SPELL, BS["Insect Swarm"],          12, 1,0,0)
	self:AddTimer(self.SPELL, BS["Nature's Grasp"],        45, 0,1,1, { cr="BLUE", ea={[BS["Entangling Roots"]]=45} })
	self:AddTimer(self.SPELL, BS["Moonfire"],              12, 1,0,0)
	self:AddTimer(self.SPELL, BS["Pounce"],                 3, 1,0,0, { ea={[BS["Pounce Bleed"]]=1}, d={tn=BS["Brutal Impact"], tb=0.5} })
	self:AddTimer(self.SPELL, BS["Rake"],                   9, 1,0,0)
	self:AddTimer(self.SPELL, BS["Regrowth"],              21, 1,1,1)
	self:AddTimer(self.SPELL, BS["Rejuvenation"],          12, 1,1,1)
	self:AddTimer(self.SPELL, BS["Rip"],                   12, 1,0,0)
	self:AddTimer(self.SPELL, BS["Soothe Animal"],         15, 1,0,0)
	self:AddTimer(self.SPELL, BS["Starfire"],               0, 1,0,0, { ea={[BS["Starfire Stun"]]=1} })
	self:AddTimer(self.SPELL, BS["Tiger's Fury"],           6, 0,1,1)
	self:AddTimer(self.SPELL, BS["Cyclone"],                6, 1,0,0)
	self:AddTimer(self.SPELL, BS["Mangle (Bear)"],         12, 1,0,0)
	self:AddTimer(self.SPELL, BS["Mangle (Cat)"],          12, 1,0,0)
	self:AddTimer(self.SPELL, BS["Lacerate"],              15, 1,0,0)
	self:AddTimer(self.SPELL, BS["Lifebloom"],              7, 1,1,1)
	self:AddTimer(self.SPELL, BS["Maim"],                   2, 1,0,0, { d={cp=1}, dr=3 })

	self:AddTimer(self.EVENT, BS["Entangling Roots"],      27, 1,0,1, { gr=1, d={rt={12,15,18,21,24}} })
	self:AddTimer(self.EVENT, BS["Nature's Grace"],        15, 0,1,1, { cr="GREEN", a=1 })

	self:AddTimer(self.EVENT, BS["Clearcasting"],          15, 0,1,1, { cr="GREEN", a=1, tx="Interface\\Icons\\Spell_Shadow_ManaBurn" })
	self:AddTimer(self.EVENT, BS["Pounce Bleed"],          18, 1,0,0, { xn=BS["Pounce"] })
	self:AddTimer(self.EVENT, BS["Starfire Stun"],          3, 1,0,0, { xn=BS["Starfire"] })
end

table.insert(Chronometer.dataSetup, Chronometer.DruidSetup)
