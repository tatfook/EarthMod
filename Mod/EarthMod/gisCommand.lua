--[[
Title: Gis Command
Author(s):  big
Date: 2017/1/24
Desc: Gis Command
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/main.lua");
local EarthMod = commonlib.gettable("Mod.EarthMod");
------------------------------------------------------------
]]
local gisCommand = commonlib.inherit(nil,commonlib.gettable("Mod.gisCommand"));

local Commands = commonlib.gettable("MyCompany.Aries.Game.Commands");
local CommandManager = commonlib.gettable("MyCompany.Aries.Game.CommandManager");

Commands["gis"] = {
	name="gis", 
	quick_ref="", 
	desc=[[]],
	handler = function(cmd_name, cmd_text, cmd_params, fromEntity)
		NPL.load("(gl)script/apps/Aries/Creator/Game/Materials/LocalTextures.lua");
		local LocalTextures = commonlib.gettable("MyCompany.Aries.Game.Materials.LocalTextures");
		
		local colors, filename, options
		options, cmd_text = CmdParser.ParseOptions(cmd_text);
		colors, cmd_text = CmdParser.ParseInt(cmd_text);
		colors = colors or 65535;
		filename, cmd_text = CmdParser.ParseString(cmd_text);
		filename = filename or "preview.jpg";
		filename = LocalTextures:GetByFileName(commonlib.Encoding.Utf8ToDefault(filename));

		if(filename) then
			local x, y, z;
			x, y, z, cmd_text = CmdParser.ParsePos(cmd_text, fromEntity);
			if(not x) then
				x,y,z = EntityManager.GetFocus():GetBlockPos();	
			end
			NPL.load("(gl)script/apps/Aries/Creator/Game/Tasks/ConvertImageToBlocksTask.lua");
			local Tasks = commonlib.gettable("MyCompany.Aries.Game.Tasks");
			local task = Tasks.ConvertImageToBlocks:new({filename = filename,blockX = x,blockY = y, blockZ = z, colors=colors,options=options})
			task:Run();
		end
	end,
};


function gisCommand:ctor()
end

function gisCommand:init()
	LOG.std(nil,"debug","gisCommand","init");
	-- body
end
