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

--local gisCommand = commonlib.inherit(nil,commonlib.gettable("Mod.gisCommand"));
local CmdParser      = commonlib.gettable("MyCompany.Aries.Game.CmdParser");
local EntityManager  = commonlib.gettable("MyCompany.Aries.Game.EntityManager");
local Tasks          = commonlib.gettable("MyCompany.Aries.Game.Tasks");
local LocalTextures  = commonlib.gettable("MyCompany.Aries.Game.Materials.LocalTextures");
LOG.std(nil,"debug","LocalTextures",LocalTextures);

local Commands       = commonlib.gettable("MyCompany.Aries.Game.Commands");
local CommandManager = commonlib.gettable("MyCompany.Aries.Game.CommandManager");

Commands["gis"] = {
	name="gis", 
	quick_ref="/gis [-croodinate] [lat] [lng]", 
	desc=[[
		
	]],
	handler = function(cmd_name, cmd_text, cmd_params, fromEntity)
		LOG.std(nil,"debug","Commands",{cmd_name,cmd_text,cmd_params,formEntity});

		local lat,lon;
		options, cmd_text = CmdParser.ParseOptions(cmd_text);
		LOG.std(nil,"debug","options, cmd_text",{options, cmd_text});

		lat, cmd_text = CmdParser.ParseString(cmd_text);
		lon, cmd_text = CmdParser.ParseString(cmd_text);
		LOG.std(nil,"debug","colors, cmd_text",{lat,lon,cmd_text});

		local task = Tasks.gisToBlocks:new({lat=lat,lon=lon});
		task:Run();

--		filename, cmd_text = CmdParser.ParseString(cmd_text);
--		LOG.std(nil,"debug","filename, cmd_text",{filename, cmd_text});
--		filename = filename or "preview.jpg";
--		filename = LocalTextures:GetByFileName(commonlib.Encoding.Utf8ToDefault(filename));

--		if(filename) then
--			local x, y, z;
--			x, y, z, cmd_text = CmdParser.ParsePos(cmd_text, fromEntity);
--
--			if(not x) then
--				x,y,z = EntityManager.GetFocus():GetBlockPos();	
--			end
--
--			LOG.std(nil,"debug","x,y,z",{x,y,z});
--			local task = Tasks.gisToBlocks:new({filename = filename,blockX = x,blockY = y, blockZ = z, colors=colors,options=options})
--			task:Run();
--		end
	end,
};
