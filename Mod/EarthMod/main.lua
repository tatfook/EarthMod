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
NPL.load("(gl)Mod/EarthMod/EarthSceneContext.lua");
NPL.load("(gl)Mod/EarthMod/gisCommand.lua");
NPL.load("(gl)Mod/EarthMod/ItemEarth.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Commands/CommandManager.lua");
NPL.load("(gl)script/apps/WebServer/WebServer.lua");

local EarthMod          = commonlib.inherit(commonlib.gettable("Mod.ModBase"),commonlib.gettable("Mod.EarthMod"));
local gisCommand        = commonlib.gettable("Mod.gisCommand");
local EarthSceneContext = commonlib.gettable("Mod.EarthMod.EarthSceneContext");
local CommandManager    = commonlib.gettable("MyCompany.Aries.Game.CommandManager");

--LOG.SetLogLevel("DEBUG");
EarthMod:Property({"Name", "EarthMod"});

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

	-- register a new block item, id < 10512 is internal items, which is not recommended to modify. 
	GameLogic.GetFilters():add_filter("block_types", function(xmlRoot)
		local blocks = commonlib.XPath.selectNode(xmlRoot, "/blocks/");

		if(blocks) then
			blocks[#blocks+1] = {name="block", attr = {name="Earth",
				id = 10512, item_class="ItemEarth", text="NPL Earth",
				icon = "Mod/EarthMod/textures/icon.png",
			}}
			LOG.std(nil, "info", "Earth", "Earth block is registered");
		end

		return xmlRoot;
	end);

	-- add block to category list to be displayed in builder window (E key)
	GameLogic.GetFilters():add_filter("block_list", function(xmlRoot)
		for node in commonlib.XPath.eachNode(xmlRoot, "/blocklist/category") do
			if(node.attr.name == "tool") then
				node[#node+1] = {name="block", attr={name="Earth"} };
			end
		end
		return xmlRoot;
	end)

	--EarthSceneContext:ApplyToDefaultContext();
end

function EarthMod:OnLogin()
end

-- called when a new world is loaded. 

function EarthMod:OnWorldLoad()
	LOG.std(nil, "info", "EarthMod", "OnNewWorld");
end
-- called when a world is unloaded. 

function EarthMod:OnLeaveWorld()
end

function EarthMod:OnDestroy()
end
