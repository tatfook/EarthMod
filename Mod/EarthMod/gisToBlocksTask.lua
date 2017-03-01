--[[
Title: convert any gis to blocks
Author(s): big
Date: 2017/1/24
Desc: transparent pixel is mapped to air. creating in any plane one likes. 
TODO: support depth texture in future. 
use the lib:
------------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Tasks/ConvertImageToBlocksTask.lua");
local Tasks = commonlib.gettable("MyCompany.Aries.Game.Tasks");
local task = Tasks.ConvertImageToBlocks:new({filename = filename,blockX, blockY, blockZ, height})
task:Run();
-------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/Tasks/UndoManager.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Items/ItemColorBlock.lua");
NPL.load("(gl)script/ide/System/Core/Color.lua");
NPL.load("(gl)Mod/EarthMod/DownloadService.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Commands/CommandManager.lua");

local Color           = commonlib.gettable("System.Core.Color");
local ItemColorBlock  = commonlib.gettable("MyCompany.Aries.Game.Items.ItemColorBlock");
local UndoManager     = commonlib.gettable("MyCompany.Aries.Game.UndoManager");
local GameLogic       = commonlib.gettable("MyCompany.Aries.Game.GameLogic");
local BlockEngine     = commonlib.gettable("MyCompany.Aries.Game.BlockEngine");
local block_types     = commonlib.gettable("MyCompany.Aries.Game.block_types");
local names           = commonlib.gettable("MyCompany.Aries.Game.block_types.names");
local TaskManager     = commonlib.gettable("MyCompany.Aries.Game.TaskManager");
local DownloadService = commonlib.gettable("Mod.EarthMod.DownloadService");
local EntityManager   = commonlib.gettable("MyCompany.Aries.Game.EntityManager");
local CommandManager  = commonlib.gettable("MyCompany.Aries.Game.CommandManager");

local gisToBlocks = commonlib.inherit(commonlib.gettable("MyCompany.Aries.Game.Task"), commonlib.gettable("MyCompany.Aries.Game.Tasks.gisToBlocks"));

-- operations enumerations
gisToBlocks.Operations = {
	-- load to scene
	Load  = 1,
	-- only load into memory
	InMem = 2,
}
-- current operation
gisToBlocks.operation = gisToBlocks.Operations.Load;
-- how many concurrent creation point allowed: currently this must be 1
gisToBlocks.concurrent_creation_point_count = 1;
-- the color schema. can be 1, 2, 16. where 1 is only a single color. 
gisToBlocks.colors = 32;

--RGB, block_id
local block_colors = {
	{221, 221, 221,	block_types.names.White_Wool},
	{219,125,62,	block_types.names.Orange_Wool},
	{179,80, 188,	block_types.names.Magenta_Wool},
	{107, 138, 201,	block_types.names.Light_Blue_Wool},
	{177,166,39,	block_types.names.Yellow_Wool},
	{65, 174, 56,	block_types.names.Lime_Wool},
	{208, 132, 153,	block_types.names.Pink_Wool},
	{64, 64, 64,	block_types.names.Gray_Wool},
	{154, 161, 161,	block_types.names.Light_Gray_Wool},
	{46, 110, 137,	block_types.names.Cyan_Wool},
	{126,61,181,	block_types.names.Purple_Wool},
	{46,56,141,		block_types.names.Blue_Wool},
	{79,50,31,		block_types.names.Brown_Wool},
	{53,70,27,		block_types.names.Green_Wool},
	{150, 52, 48,	block_types.names.Red_Wool},
	{25, 22, 22,	block_types.names.Black_Wool},
}

local function drawpixel(x, y, z)
		--local spawn_x, spawn_y, spawn_z = self:GetSpawnPosition();			
		--LOG.std(nil, "info", "spawn_x", spawn_x);
		--local x, y, z = BlockEngine:real(spawn_x, spawn_y, spawn_z); 
		--EntityManager.GetPlayer():SetBlockPos(x, z, y); 

		--local blockstr = "/box 1 1 1";
		--LOG.std(nil, "info", "Command", blockstr);
		--CommandManager:RunCommand(blockstr);
		LOG.std(nil,"debug","x,y,z",{x,y,z})
		BlockEngine:SetBlock(x,z,y,28);
end

local function drawline(x1, y1, x2, y2, z)
	--local x, y, dx, dy, s1, s2, p, temp, interchange, i;
	x=x1;
	y=y1;
	dx=math.abs(x2-x1);
	dy=math.abs(y2-y1);

	if(x2>x1) then
		s1=1;
	else
		s1=-1;
	end

	if(y2 > y1) then
		s2 = 1;
	else
		s2 = -1;
	end

	if(dy > dx) then
		temp = dx;
		dx   = dy;
		dy   = temp;
	    interchange = 1;
	else
	    interchange = 0;
	end

	p = 2*dy - dx;

	for i=1,dx do
		drawpixel(x,y,z);

		if(p>=0) then
			if(interchange==0) then
				y = y+s2;
			else
				x = x+s1;
			end
			p = p-2*dx;
		end

		if(interchange == 0) then
			x = x+s1; 
		else
			y = y+s2;
		end

		p = p+2*dy;
	end
end

local function tile2deg(x, y, z)
    local n = 2 ^ z
    local lon_deg = x / n * 360.0 - 180.0
    local lat_rad = math.atan(math.sinh(math.pi * (1 - 2 * y / n)))
    local lat_deg = lat_rad * 180.0 / math.pi
    return lon_deg, lat_deg
end

local function deg2tile(lon, lat, zoom)
    local n = 2 ^ zoom
    local lon_deg = tonumber(lon)
    local lat_rad = math.rad(lat)
    local xtile = math.floor(n * ((lon_deg + 180) / 360))
    local ytile = math.floor(n * (1 - (math.log(math.tan(lat_rad) + (1 / math.cos(lat_rad))) / math.pi)) / 2)
    return xtile, ytile
end

local function deg2pixel(lon, lat, zoom)
    local n = 2 ^ zoom
    local lon_deg = tonumber(lon)
    local lat_rad = math.rad(lat)
    local xtile = math.floor(n * ((lon_deg + 180) / 360) * 256 % 256 + 0.5)
    local ytile = math.floor(n * (1 - (math.log(math.tan(lat_rad) + (1 / math.cos(lat_rad))) / math.pi)) / 2 * 256 % 256 + 0.5)
    return xtile, ytile
end

-- Calculates distance between two RGB colors
local function GetColorDist(colorRGB, blockRGB)
	return math.max(math.abs(colorRGB[1]-blockRGB[1]), math.abs(colorRGB[2]-blockRGB[2]), math.abs(colorRGB[3]-blockRGB[3]));
end

local function GetColorDistBGR(colorBGR, blockRGB)
	return math.max(math.abs(colorBGR[3]-blockRGB[1]), math.abs(colorBGR[2]-blockRGB[2]), math.abs(colorBGR[1]-blockRGB[3]));
end

-- square distance
local function GetColorDist2(colorRGB, blockRGB)
	return ((colorRGB[1]-blockRGB[1])^2) + ((colorRGB[2]-blockRGB[2])^2) + ((colorRGB[3]-blockRGB[3])^2);
end

-- square distance
local function GetColorDist2BGR(colorRGB, blockRGB)
	return ((colorRGB[3]-blockRGB[1])^2) + ((colorRGB[2]-blockRGB[2])^2) + ((colorRGB[1]-blockRGB[3])^2);
end

-- find the closest color
local function FindClosetBlockColor(pixelRGB)
	local closest_block_color;
	local smallestDist = 100000;
	local smallestDistIndex = -1;
	for i = 1, #block_colors do
		local curDist = GetColorDistBGR(pixelRGB, block_colors[i]);
		-- local curDist = GetColorDist2BGR(pixelRGB, block_colors[i]);

		if (curDist < smallestDist) then
			smallestDist = curDist
			smallestDistIndex = i;
		end
	end
	return block_colors[smallestDistIndex];
end

function gisToBlocks:ctor()
	self.step = 1;
	self.history = {};
end

function gisToBlocks:GetData(_callback)
	--echo(DownloadService,true);
	local raster,vector;
	DownloadService:getOsmPNGData(self.lat,self.lon,function(raster)
		DownloadService:getOsmXMLData(function(vector)
			_callback(raster,vector);
		end);
	end);
end

-- @param pixel: {r,g,b,a}
-- @param colors: 1, 2, 3, 16
local function GetBlockIdFromPixel(pixel, colors)
	if(colors == 1) then
		return block_types.names.White_Wool;
	elseif(colors == 2) then
		if((pixel[1]+pixel[2]+pixel[3]) > 128) then
			return block_types.names.White_Wool;
		else
			return block_types.names.Black_Wool;
		end
	elseif(colors == 3) then
		local total = pixel[1]+pixel[2]+pixel[3];
		if(total > 400) then
			return block_types.names.White_Wool;
		elseif(total > 128) then
			return block_types.names.Brown_Wool;
		else
			return block_types.names.Black_Wool;
		end
	elseif(colors == 4) then
		local total = pixel[1]+pixel[2]+pixel[3];
		if(total > 500) then
			return block_types.names.White_Wool;
		elseif(total > 400) then
			return block_types.names.Light_Gray_Wool;
		elseif(total > 128) then
			return block_types.names.Brown_Wool;
		elseif(total > 64) then
			return block_types.names.Gray_Wool;
		else
			return block_types.names.Black_Wool;
		end
	elseif(colors <= 16) then
		local block_color = FindClosetBlockColor(pixel);
		return block_color[4];
	else  -- for 65535 colors, use color block
		return block_types.names.ColorBlock, ItemColorBlock:ColorToData(Color.RGBA_TO_DWORD(pixel[3],pixel[2],pixel[1], 0));
	end
end

function gisToBlocks:AddBlock(x,y,z, block_id, block_data)
	if(self.add_to_history) then
		local from_id = BlockEngine:GetBlockId(x,y,z);
		local from_data, from_entity_data;
		if(from_id and from_id>0) then
			from_data = BlockEngine:GetBlockData(x,y,z);
			from_entity_data = BlockEngine:GetBlockEntityData(x,y,z);
		end
		self.history[#(self.history)+1] = {x,y,z, block_id, from_id, from_data, from_entity_data};
	end
	local block_template = block_types.get(block_id);

	if(block_template) then
		block_template:Create(x,y,z, false, block_data);
	end
end

function gisToBlocks:OSMToBlock(vector,px, py, pz)
	
	local xmlRoot = ParaXML.LuaXML_ParseString(vector);
	--LOG.std(nil,"debug","xmlRoot",xmlRoot);
	if (not xmlRoot) then
		LOG.std(nil, "info", "ParseOSM", "Failed loading OSM");
		_guihelper.MessageBox("Failed loading OSM");
		return;
	end

	local osmnode = commonlib.XPath.selectNodes(xmlRoot, "/osm")[1];
	LOG.std(nil,"debug","osmnode-attr",osmnode.attr);

	local osmNodeList = {};
	local count = 1;

	for osmnode in commonlib.XPath.eachNode(osmnode, "/node") do
		--LOG.std(nil,"debug","osmnode",osmnode);
		osmNodeItem = { id = osmnode.attr.id; lat = osmnode.attr.lat; lon = osmnode.attr.lon; }
		osmNodeList[count] = osmNodeItem;
		count = count + 1;
	end

--	for i=1, #osmNodeList do
--		LOG.std(nil,"debug","i",i);
--	    local item = osmNodeList[i];
--		if (i < 2) then	
--			LOG.std(nil, "info", "osmnode", item.id..","..item.lat..","..item.lon);
--		    break;
--		end
--	end

	local osmBuildingList = {}
	local osmBuildingCount = 0;

	local waynode;
	for waynode in commonlib.XPath.eachNode(osmnode, "/way") do
	    local found = false; --only find one building nodes
		--LOG.std(nil,"debug","waynode",waynode);
		local tagnode;
		for tagnode in commonlib.XPath.eachNode(waynode, "/tag") do	
			--LOG.std(nil,"debug","tagnode",tagnode);

			if (tagnode.attr.k == "building") then
				LOG.std(nil, "info", "way tag", waynode.attr.id);

				local buildingPointList = {};
				local buildingPointCount = 0;

				--find node belong to building tag way
				--<nd ref="1765621163"/>
				local ndnode;
				for ndnode in commonlib.XPath.eachNode(waynode, "/nd") do 
					--LOG.std(nil,"debug","#osmNodeList",#osmNodeList);				
					for i=1, #osmNodeList do
						local item = osmNodeList[i];
						if (item.id == ndnode.attr.ref) then
							cur_tilex, cur_tiley = deg2tile(item.lon, item.lat, 17);
							if (cur_tilex == self.tileX) and (cur_tiley == self.tileY) then
								
								local str = item.id..","..item.lat..","..item.lon.." -> "..tostring(xpos)..","..tostring(ypos);
								--LOG.std(nil, "info", "found building node:", str);

								--buildingPoint = {id = item.id; x = item.lon; y = item.lat; z = 1; }
								xpos, ypos = deg2pixel(item.lon, item.lat, 17);
								--LOG.std(nil,"debug","xpos,ypos",{xpos,ypos});
								buildingPoint = {id = item.id; x = xpos; y = ypos; z = 1; }
								buildingPointCount = buildingPointCount + 1;
								buildingPointList[buildingPointCount] = buildingPoint;
							end					
						end
				    end
			    end

				osmBuilding = {id = waynode.id, points = buildingPointList};
				--LOG.std(nil, "info", "osmBuilding", osmBuilding);
				osmBuildingCount = osmBuildingCount + 1;
				osmBuildingList[osmBuildingCount] = osmBuilding;
				
				found = true;
			end
		end

	    if (found) then
	        --break;
	    end
	end

	--CommandManager:RunCommand("/take 28");

	--LOG.std(nil, "info", "osmBuildingList", osmBuildingList);
	for k,v in pairs(osmBuildingList) do
		LOG.std(nil, "info", "k", k);
		LOG.std(nil, "info", "v", v);

		buildingPointList = v.points;

		if (buildingPointList) then
			LOG.std(nil, "info", "buildingPointList", buildingPointList);
			local length = #buildingPointList;
			if (length > 3) then
				for i = 1, length - 1 do				
					local building = buildingPointList[i];
					--building.x = 19200 + building.x;
					--building.y = 19200 + building.y;
					building.z = 6;

					--local gostr = "/tp "..tostring(building.x).." "..tostring(building.z).." "..tostring(building.y)
					--LOG.std(nil, "info", "Command", gostr);
					--CommandManager:RunCommand(gostr);

					local building2 = buildingPointList[i + 1];
					--building2.x = 19200 + building2.x;
					--building2.y = 19200 + building2.y;
					building2.z = 6;

					--local linestr1 = tostring(building.x).." "..tostring(building.y).." "..tostring(building2.x).." "..tostring(building2.y).." "..tostring(building.z)
					--LOG.std(nil, "info", "drawline", linestr1);
					--building.x, building.y = deg2pixel(building.x, building.y, zoom);
					--building2.x, building2.y = deg2pixel(building2.x, building2.y, zoom);
					local linestr = tostring(building.x).." "..tostring(building.y).." "..tostring(building2.x).." "..tostring(building2.y).." "..tostring(building.z)
					LOG.std(nil, "info", "drawline", linestr);



					if (building.x < building2.x) then
						drawline(px + building.x , pz - building.y + 256, px + building2.x, pz - building2.y + 256, building.z);
					else
						drawline(px + building2.x, pz - building2.y + 256, px + building.x, pz - building.y + 256, building.z);
					end
				end
			end
		end
	end
end

function gisToBlocks:PNGToBlock(px,py,pz)
	local file   = ParaIO.open("tile.png", "image");
	local colors = self.colors;
	local plane  = "xz";
	--echo(file);
	if(file:IsValid()) then
		local ver           = file:ReadInt();
		local width         = file:ReadInt();
		local height        = file:ReadInt();
		local bytesPerPixel = file:ReadInt();-- how many bytes per pixel, usually 1, 3 or 4
		LOG.std(nil, "info", "gisToBlocks", {ver, width, height, bytesPerPixel});

		local block_world = GameLogic.GetBlockWorld();
		local function CreateBlock_(x, y, block_id, block_data)
			local z;
			if(plane == "xy") then
				x, y, z = px+x, py+y, pz;
			elseif(plane == "yz") then
				x, y, z = px, py+y, pz+x;
			elseif(plane == "xz") then
				x, y, z = px+x, py, pz+y;
			end
			ParaBlockWorld.LoadRegion(block_world, x, y, z);
			self:AddBlock(x, y, z, block_id, block_data);
		end

		--array of {r,g,b,a}
		local pixel = {};

		if(bytesPerPixel >= 3) then
			local block_per_tick = 100;
			local count = 0;
			local row_padding_bytes = (bytesPerPixel*width)%4;
			if(row_padding_bytes >0) then
				row_padding_bytes = 4-row_padding_bytes;
			end
			local worker_thread_co = coroutine.create(function ()
				for y=1, height do
					for x=1, width do
						pixel = file:ReadBytes(bytesPerPixel, pixel);

						if(pixel[4]~=0) then
							-- transparent pixel does not show up. 
							--LOG.std(nil,"debug","pixel,colors",{pixel});
							local block_id, block_data = GetBlockIdFromPixel(pixel, colors);
							if(block_id) then
								--LOG.std(nil,"debug","x,y,block_id,block_data",{x,y,block_id,block_data});
								CreateBlock_(x,y, block_id, block_data);
								count = count + 1;
								if((count%block_per_tick) == 0) then
									coroutine.yield(true);
								end
							end
						end
					end
					if(row_padding_bytes > 0) then
						file:ReadBytes(row_padding_bytes, pixel);
					end
				end	
				return;
			end)

			local timer = commonlib.Timer:new({callbackFunc = function(timer)
				local status, result = coroutine.resume(worker_thread_co);
				if not status then
					LOG.std(nil, "info", "PNGToBlocks", "finished with %d blocks: %s ", count, tostring(result));
					timer:Change();
					file:close();
				end
			end})
			timer:Change(30,30);

			UndoManager.PushCommand(self);
		else
			LOG.std(nil, "error", "PNGToBlocks", "format not supported");
			file:close();
		end
	end
end

-- Load template using a coroutine, 100 blocks per second. 
-- @param self.blockX, self.blockY, self.blockZ
-- @param self.colors: 1 | 2 | 16 | 65535   how many colors to use
-- @param self.options: {xy=true, yz=true, xz=true}
function gisToBlocks:LoadToScene(raster,vector)
	--local filename = self.filename;
	--if(not filename) then
		--return;
	--end

	local colors = self.colors;
	--local px, py, pz = self.blockX, self.blockY, self.blockZ;
	local px, py, pz = EntityManager.GetFocus():GetBlockPos();	

	if(not px) then
		return
	end

	self:PNGToBlock(px,py,pz);
	self:OSMToBlock(vector,px, py, pz);
end

function gisToBlocks:FrameMove()
	self.finished = true;
end

function gisToBlocks:Redo()
	if((#self.history)>0) then
		for _, b in ipairs(self.history) do
			BlockEngine:SetBlock(b[1],b[2],b[3], b[4]);
		end
	end
end

function gisToBlocks:Undo()
	if((#self.history)>0) then
		for _, b in ipairs(self.history) do
			BlockEngine:SetBlock(b[1],b[2],b[3], b[5] or 0, b[6], b[7]);
		end
	end
end

function gisToBlocks:Run()
	--echo(self,true);
	self.finished = true;

	if(GameLogic.GameMode:CanAddToHistory()) then
		self.add_to_history = true;
	end

	self.tileX,self.tileY = deg2tile(self.lon,self.lat,17);

	self:GetData(function(raster,vector)
		self:LoadToScene(raster,vector);
	end);

--	if(self.operation == gisToBlocks.Operations.Load) then
--		return self:LoadToScene();
--	elseif(self.operation == gisToBlocks.Operations.InMem) then
--		return self:LoadToMemory();
--	end
end