--[[
Title: 
Author(s):  
Date: 
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/main.lua");
local EarthMod = commonlib.gettable("Mod.EarthMod");
------------------------------------------------------------
]]
local EarthMod = commonlib.inherit(commonlib.gettable("Mod.ModBase"),commonlib.gettable("Mod.EarthMod"));

function EarthMod:ctor()
end

-- virtual function get mod name

function EarthMod:GetName()
	return "EarthMod"
end

-- virtual function get mod description 

function EarthMod:GetDesc()
	return "EarthMod is a plugin in paracraft"
end

function EarthMod:init()
	LOG.std(nil, "info", "EarthMod", "plugin initialized");
end

function EarthMod:OnLogin()
end
-- called when a new world is loaded. 

function EarthMod:OnWorldLoad()
end
-- called when a world is unloaded. 

function EarthMod:OnLeaveWorld()
end

function EarthMod:OnDestroy()
end
