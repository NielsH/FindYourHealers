-----------------------------------------------------------------------------------------------
--[[
	Client Lua Script for FindYourHealers
	
	This file is part of FindYourHealers.

    FindYourHealers is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    FindYourHealers is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with FindYourHealers.  If not, see <http://www.gnu.org/licenses/>.
--]]
-----------------------------------------------------------------------------------------------

require "Apollo"
require "ApolloTimer"
require "GroupLib"
require "GameLib"

-----------------------------------------------------------------------------------------------
-- FindYourHealers Module Definition
-----------------------------------------------------------------------------------------------
local FindYourHealers = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:NewAddon("FindYourHealers", false, {}, "Gemini:Timer-1.0")
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------

local DefaultSettings = {
	nHealthThreshold = 40,
}

local uPlayer
local bShowMarks = false
local tHealers = {}
local Timer

-----------------------------------------------------------------------------------------------
-- FindYourHealers OnInitialize
-----------------------------------------------------------------------------------------------
function FindYourHealers:OnInitialize()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("FindYourHealers.xml")
	Apollo.RegisterSlashCommand("fyh", "OnSlashCmd", self)
	self.settings = self.settings or self:recursiveCopyTable(DefaultSettings)
end
-----------------------------------------------------------------------------------------------
-- FindYourHealers OnEnable
-----------------------------------------------------------------------------------------------
function FindYourHealers:OnEnable()
	self.drawline = FindYourHealersLibs.DisplayLine.new(self.xmlDoc)
	uPlayer = GameLib.GetPlayerUnit()
	Timer = ApolloTimer.Create(1, true, "OnTimer", self)
end

-----------------------------------------------------------------------------------------------
-- FindYourHealers Save Functions
-----------------------------------------------------------------------------------------------

function FindYourHealers:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end
	local tSave = { nSaveVersion = knSaveVersion, }
	self:recursiveCopyTable(self.settings, tSave)
	return tSave
end

function FindYourHealers:OnRestore(eType, tSavedData)
	self.tSavedData = tSavedData
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end

	self.settings = self:recursiveCopyTable(DefaultSettings, self.settings)
	self.settings = self:recursiveCopyTable(tSavedData, self.settings)
end

function FindYourHealers:recursiveCopyTable(from, to)
	to = to or {}
	for k,v in pairs(from) do
		if type(v) == "table" then
			to[k] = self:recursiveCopyTable(v, to[k])
		else
			to[k] = v
		end
	end
	return to
end

-----------------------------------------------------------------------------------------------
-- FindYourHealers Functions
-----------------------------------------------------------------------------------------------
function FindYourHealers:OnTimer()
	if not GroupLib.InGroup() then
		if bShowMarks then
			self:RemoveMarks()
		end
		return
	end
	if not uPlayer then uPlayer = GameLib.GetPlayerUnit() return end

	local nHealthCurr = uPlayer:GetHealth()
	local nHealthMax = uPlayer:GetMaxHealth()
	if nHealthCurr and nHealthMax and nHealthCurr > 0 and nHealthMax >= nHealthCurr then
		local nHpPct = nHealthCurr / nHealthMax * 100
		if nHpPct < self.settings.nHealthThreshold then
			self:MarkHealers()
		elseif bShowMarks then
			self:RemoveMarks()
		end
	elseif nHealthCurr == 0 and nHealthMax == 0 then
		-- Dead
		self:RemoveMarks()
	end
end

function FindYourHealers:MarkHealers()
	if not uPlayer or not GroupLib.InGroup() then return false end
	for nMemberIdx=0, GroupLib.GetMemberCount() do
		local nGroupMember = GroupLib.GetGroupMember(nMemberIdx)
		if nGroupMember then
			local bHealer = nGroupMember.bHealer
			local strCharacterName = nGroupMember.strCharacterName
			if bHealer then
				local unit = GroupLib.GetUnitForGroupMember(nMemberIdx)
				if unit then
					local unitId = unit:GetId()
					if unitId then
						tHealers[unitId] = unit
					end
				end
			end
		end
	end
	for unitId, unit in pairs(tHealers) do
		if unit then
			self:AddPixie(unitId, 1, uPlayer, unit, "Blue", 5, 10, 10)
		end
		if not bShowMarks then
			bShowMarks = true
		end
	end
end

function FindYourHealers:RemoveMarks()
	for unitId, unit in pairs(tHealers) do
		self:DropPixie(unitId)
	end
	tHealers = {}
	bShowMarks = false
end

function FindYourHealers:AddPixie(...)
	self.drawline:AddPixie(...)
end

function FindYourHealers:DropPixie(key)
	self.drawline:DropPixie(key)
end

function FindYourHealers:OnSlashCmd(sCmd, sInput)
	local option = string.lower(sInput)
	if option == nil or option == "" then
		Print("Please use /fyh hp <number> to set the threshold for displaying lines, percentage based.")
	else
		local args = {}
		for word in sInput:gmatch("%S+") do table.insert(args, word) end
		if args[1] and args[1] == "hp" and args[2] then
			local threshold = tonumber(args[2])
			if threshold and threshold > 1 and threshold < 100 then
				self.settings.nHealthThreshold = threshold
				Print("Your new threshold is: " .. tostring(threshold))
			end
		else
			Print("Your current threshold is: " .. tostring(self.settings.nHealthThreshold))
		end
	end
end