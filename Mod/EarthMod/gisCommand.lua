--[[
Title: Gis Command
Author(s):  big
Date: 2017/1/24
Desc: Gis Command
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/gisCommand.lua");
local gisCommand = commonlib.gettable("Mod.gisCommand");
------------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/Materials/LocalTextures.lua");
NPL.load("(gl)Mod/EarthMod/gisToBlocksTask.lua");

local CmdParser      = commonlib.gettable("MyCompany.Aries.Game.CmdParser");
local Tasks          = commonlib.gettable("MyCompany.Aries.Game.Tasks");
local LocalTextures  = commonlib.gettable("MyCompany.Aries.Game.Materials.LocalTextures");

local Commands       = commonlib.gettable("MyCompany.Aries.Game.Commands");
local CommandManager = commonlib.gettable("MyCompany.Aries.Game.CommandManager");

Commands["gis"] = {
	name="gis", 
	quick_ref="/gis [-croodinate] [lat] [lng] [-cache] [true/false]",
	desc=[[
		
	]],
	handler = function(cmd_name, cmd_text, cmd_params, fromEntity)
		local lat,lon;
		options, cmd_text = CmdParser.ParseOptions(cmd_text);

		lat, cmd_text = CmdParser.ParseString(cmd_text);
		lon, cmd_text = CmdParser.ParseString(cmd_text);

		options, cmd_text = CmdParser.ParseString(cmd_text);

		if(options == nil) then
			cache = 'false';
		else
			cache, cmd_text = CmdParser.ParseString(cmd_text);
		end

		local task = Tasks.gisToBlocks:new({lat=lat,lon=lon,cache=cache});
		
		task:Run();
	end,
};
