--[[
Title: SelectLocation Task/Command
Author(s): big
Date: 2017/2/9
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/SelectLocationTask.lua");
local SelectLocationTask = commonlib.gettable("MyCompany.Aries.Game.Tasks.SelectLocationTask");
local task = SelectLocationTask:new();
task:Run();
-------------------------------------------------------
]]
local SelectLocationTask = commonlib.inherit(commonlib.gettable("MyCompany.Aries.Game.Task"), commonlib.gettable("MyCompany.Aries.Game.Tasks.SelectLocationTask"));

SelectLocationTask:Property({"LeftLongHoldToDelete", false, auto=true});

local curInstance;

-- this is always a top level task. 
SelectLocationTask.is_top_level = true;

function SelectLocationTask:ctor()
end

function SelectLocationTask:SetItemStack(itemStack)
	LOG.std(nil,"debug","SetItemStack","+++++++++000000000++++++++++");
	self.itemStack = itemStack;
end

function SelectLocationTask:GetItemStack()
	return self.itemStack;
end

local page;
function SelectLocationTask.InitPage(Page)
	page = Page;
end

-- get current instance
function SelectLocationTask.GetInstance()
	return curInstance;
end

function SelectLocationTask:ShowPage()
	local window = self:CreateGetToolWindow();
	window:Show({
		name="SelectLocationTask", 
		url="Mod/EarthMod/SelectLocationTask.html",
		alignment="_ctb", left=0, top=-55, width = 256, height = 64,
	});
end

function SelectLocationTask:Run()
	self:ShowPage();
end