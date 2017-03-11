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
	_guihelper.MessageBox(L"点击后打开外部浏览器，点击地图选择坐标。", function(res)
	if(res and res == _guihelper.DialogResult.Yes) then
		local self = SelectLocationTask.GetInstance();
		local item = self:GetItem();
		
		if(item) then
			item:GoToMap();
		end
	end
end, _guihelper.MessageBoxButtons.YesNo);

end

function SelectLocationTask.OnClickConfirm()
	page:CloseWindow();
end

function SelectLocationTask.OnClickCancel()
	local self = SelectLocationTask.GetInstance();
	local item = self:GetItem();
	
	if(item) then
		item:Cancle();
	end

	page:CloseWindow();
end

function SelectLocationTask.setCoordinate(lat,lon)
	SelectLocationTask.isFirstSelect = false;

	if(lat ~= SelectLocationTask.lat or lon ~=SelectLocationTask.lon) then
		SelectLocationTask.isChange = true;
		SelectLocationTask.lat      = lat;
		SelectLocationTask.lon      = lon;
	end

	EarthMod:SetWorldData("coordinate",{lat=tostring(lat),lon=tostring(lon)});
	--EarthMod:SetWorldData("testString","OKOKOK");
	--EarthMod:SetWorldData("testNumber",123456.3333);
	--EarthMod:SetWorldData("testBool",false);
	EarthMod:SaveWorldData();
    local self = SelectLocationTask.GetInstance();
	local item = self:GetItem();
	
	if(item) then
		item:RefreshTask(self:GetItemStack());
	end
end

function SelectLocationTask:ShowPage()
	local window = self:CreateGetToolWindow();

	System.App.Commands.Call("File.MCMLWindowFrame", {
		url  = "Mod/EarthMod/SelectLocationTask.html", 
		name = "SelectLocationTask", 
		isShowTitleBar = false,
		DestroyOnClose = true, -- prevent many ViewProfile pages staying in memory / false will only hide window
		style = CommonCtrl.WindowFrame.ContainerStyle,
		zorder = 0,
		allowDrag = true,
		bShow = bShow,
		directPosition = true,
			align = "_ctb",
			x = 0,
			y = -55,
			width = 356,
			height = 100,
		cancelShowAnimation = true,
	});
end

function SelectLocationTask:Run()
	curInstance = self;
	self.finished = false;

	local coordinate = EarthMod:GetWorldData("coordinate");
	--local testString = EarthMod:GetWorldData("testString");
	--local testNumber = EarthMod:GetWorldData("testNumber");
	--local testBool   = EarthMod:GetWorldData("testBool");

	if(coordinate) then
		SelectLocationTask.isFirstSelect = false;
		SelectLocationTask.isChage       = false;

		SelectLocationTask.lat = coordinate.lat or 0;
		SelectLocationTask.lon = coordinate.lon or 0;
	end

	self:ShowPage();
end