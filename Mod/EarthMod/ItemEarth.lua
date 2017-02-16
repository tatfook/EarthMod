--[[
Title: ItemEarth
Author(s): big
Date: 2017/2/8
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/ItemEarth.lua");
local ItemEarth = commonlib.gettable("MyCompany.Aries.Game.Items.ItemEarth");
-------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/Items/ItemBlockModel.lua");
NPL.load("(gl)Mod/EarthMod/SelectLocationTask.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/GUI/OpenFileDialog.lua");

local ItemBlockModel = commonlib.gettable("MyCompany.Aries.Game.Items.ItemBlockModel");
local ItemEarth      = commonlib.inherit(ItemBlockModel, commonlib.gettable("MyCompany.Aries.Game.Items.ItemEarth"));

local block_types    = commonlib.gettable("MyCompany.Aries.Game.block_types")
local ItemStack      = commonlib.gettable("MyCompany.Aries.Game.Items.ItemStack");
local OpenFileDialog = commonlib.gettable("MyCompany.Aries.Game.GUI.OpenFileDialog");

block_types.RegisterItemClass("ItemEarth", ItemEarth);

function ItemEarth:ctor()
	self:SetOwnerDrawIcon(true);
end

function ItemEarth:OnSelect(itemStack)
	ItemEarth._super.OnSelect(self,itemStack);
	GameLogic.SetStatus(L"点击下方按钮选择地图坐标");
end

--function ItemEarth:OnDeSelect()
	--ItemCAD._super.OnDeSelect(self);
	--GameLogic.SetStatus(nil);
--end

-- called whenever this item is clicked on the user interface when it is holding in hand of a given player (current player). 
function ItemEarth:OnClickInHand(itemStack, entityPlayer)
	-- if there is selected blocks, we will replace selection with current block in hand. 
	if(GameLogic.GameMode:IsEditor()) then
		
	end
end

function ItemEarth:GoToMap()
	local url = "npl://earth";
	GameLogic.RunCommand("/open " .. url);
end

function ItemEarth:RefreshTask(itemStack)
	local task = self:GetTask();
	if(task) then
		task:SetItemStack(itemStack);
		task:RefreshPage();
	end
end

function ItemEarth:CreateTask(itemStack)
	local SelectLocationTask = commonlib.gettable("MyCompany.Aries.Game.Tasks.SelectLocationTask");
	local task = SelectLocationTask:new();
	task:SetItemStack(itemStack);
	return task;
end





