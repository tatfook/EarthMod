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
NPL.load("(gl)Mod/EarthMod/main.lua");

local SelectLocationTask = commonlib.inherit(commonlib.gettable("MyCompany.Aries.Game.Task"), commonlib.gettable("MyCompany.Aries.Game.Tasks.SelectLocationTask"));
local EarthMod           = commonlib.gettable("Mod.EarthMod");

SelectLocationTask:Property({"LeftLongHoldToDelete", false, auto=true});

local curInstance;

SelectLocationTask.isFirstSelect = true;
-- this is always a top level task. 
SelectLocationTask.is_top_level  = true;

function SelectLocationTask:ctor()
end

function SelectLocationTask:SetItemStack(itemStack)
	--LOG.std(nil,"debug","SetItemStack","+++++++++000000000++++++++++");
	self.itemStack = itemStack;
end

function SelectLocationTask:GetItemStack()
	return self.itemStack;
end

local page;
function SelectLocationTask.InitPage(Page)
	page = Page;
end

function SelectLocationTask:RefreshPage()
	if(page) then
		page:Refresh(0.01);
	end
end

-- get current instance
function SelectLocationTask.GetInstance()
	return curInstance;
end

function SelectLocationTask:GetItem()
	local itemStack = self:GetItemStack();
	if(itemStack) then
		return itemStack:GetItem();
	end
end

function SelectLocationTask.OnClickSelectLocationScript()
	local self = SelectLocationTask.GetInstance();
	local item = self:GetItem();

	if(item) then
		item:GoToMap();
	end
end

function SelectLocationTask.setCoordinate(lat,lon)
	SelectLocationTask.isFirstSelect = false;
	SelectLocationTask.lat = lat;
	SelectLocationTask.lon = lon;

	EarthMod:SetWorldData("coordinate",{{tostring(lat),name="lat",attr={type="number"}},{tostring(lon),name="lon",attr={type="number"}}});

    local self = SelectLocationTask.GetInstance();
	local item = self:GetItem();
	
	if(item) then
		item:RefreshTask(self:GetItemStack());
	end
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
	curInstance = self;
	self.finished = false;

	local coordinate = EarthMod:GetWorldData("coordinate");

	if(coordinate) then
		SelectLocationTask.isFirstSelect = false;

		for key,value in pairs(coordinate) do
			if(type(value) == "table") then
				if(value.name == "lat") then
					SelectLocationTask.lat = value[1];
				elseif(value.name == "lon") then
					SelectLocationTask.lon = value[1];
				end
			end
		end

		SelectLocationTask.lat = SelectLocationTask.lat or 0;
		SelectLocationTask.lon = SelectLocationTask.lon or 0;
	end

	self:ShowPage();
end