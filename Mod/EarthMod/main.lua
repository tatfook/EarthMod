--[[
Title: Earth Mod
Author(s):  big
Date: 2017/1/24
Desc: Earth Mod
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/main.lua");
local EarthMod = commonlib.gettable("Mod.EarthMod");
------------------------------------------------------------
]]
NPL.load("(gl)Mod/EarthMod/gisCommand.lua");

local EarthMod   = commonlib.inherit(commonlib.gettable("Mod.ModBase"),commonlib.gettable("Mod.EarthMod"));
local gisCommand = commonlib.gettable("Mod.gisCommand"); 

LOG.SetLogLevel("DEBUG");

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
	gisCommand:init();

end

function EarthMod:OnLogin()
end

-- called when a new world is loaded. 

function EarthMod:OnWorldLoad()
	LOG.std(nil, "info", "EarthMod", "OnNewWorld");

	NPL.load("(gl)script/apps/Aries/Creator/Game/Commands/CommandManager.lua");
	local CommandManager = commonlib.gettable("MyCompany.Aries.Game.CommandManager");

	CommandManager:RunCommand("/home");
	CommandManager:RunCommand("/gis b42.png");
	CommandManager:RunCommand("/take 126");
	CommandManager:RunCommand("/box 1 1 1");
	LOG.std(nil,"debug","CommandManager",CommandManager);
end
-- called when a world is unloaded. 

function EarthMod:OnLeaveWorld()
end

function EarthMod:OnDestroy()
end
