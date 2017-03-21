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

local gisCommand     = commonlib.gettable("Mod.EarthMod.gisCommand");

local Commands       = commonlib.gettable("MyCompany.Aries.Game.Commands");
local CommandManager = commonlib.gettable("MyCompany.Aries.Game.CommandManager");

Commands["gis"] = {
	name="gis", 
	quick_ref="/gis [-coordinate] [lat] [lng] [-cache] [true/false]",
	desc=[[
		
	]],
	handler = function(cmd_name, cmd_text, cmd_params, fromEntity)
		local lat,lon;
		options, cmd_text = CmdParser.ParseOptions(cmd_text);
		--LOG.std(nil,"debug","cmd_text",cmd_text);

		if(options.coordinate) then
			lat, cmd_text = CmdParser.ParseString(cmd_text);
			lon, cmd_text = CmdParser.ParseString(cmd_text);

			options, cmd_text = CmdParser.ParseOptions(cmd_text);

			if(options.cache) then
				cache, cmd_text = CmdParser.ParseString(cmd_text);
			else
				cache = 'false';
			end

			gisCommand.gis = Tasks.gisToBlocks:new({options="coordinate",lat=lat,lon=lon,cache=cache});
			gisCommand.gis:Run();
			return;
		end

		if(options.already)then
			gisCommand.gis = Tasks.gisToBlocks:new({options="already"});
			gisCommand.gis:Run();
			return;
		end

		if(options.undo) then
			if(gisCommand.gis) then
				gisCommand.gis:Undo();
			end
			return;
		end

		if(options.boundary) then
			if(gisCommand.gis) then
				gisCommand.getMoreTiles = gisCommand.gis:BoundaryCheck();
			end
			return;
		end

		if(options.more) then
			more, cmd_text = CmdParser.ParseString(cmd_text);

			if(more == "true" and gisCommand.gis) then
				options, cmd_text = CmdParser.ParseOptions(cmd_text);

				if(options.cache) then
					cache, cmd_text = CmdParser.ParseString(cmd_text);
				else
					cache = 'false';
				end

				gisCommand.gis.cache = cache;
				gisCommand.gis:MoreScene();
			end
		end
	end,
};
