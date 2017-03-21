﻿--[[
Title: convert any gis to blocks
Author(s): big
Date: 2017/1/24
Desc: transparent pixel is mapped to air. creating in any plane one likes. 
TODO: support depth texture in future. 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/gisToBlocksTask.lua");
local Tasks = commonlib.gettable("MyCompany.Aries.Game.Tasks");
local task = Tasks.gisToBlocks:new({options="coordinate",lat=lat,lon=lon,cache=cache})
task:Run();
-------------------------------------------------------
]]
NPL.load("(gl)Mod/EarthMod/main.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Tasks/UndoManager.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Items/ItemColorBlock.lua");
NPL.load("(gl)script/ide/System/Core/Color.lua");
NPL.load("(gl)Mod/EarthMod/getOsmService.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Commands/CommandManager.lua");

local Color           = commonlib.gettable("System.Core.Color");
local ItemColorBlock  = commonlib.gettable("MyCompany.Aries.Game.Items.ItemColorBlock");
local UndoManager     = commonlib.gettable("MyCompany.Aries.Game.UndoManager");
local GameLogic       = commonlib.gettable("MyCompany.Aries.Game.GameLogic");
local BlockEngine     = commonlib.gettable("MyCompany.Aries.Game.BlockEngine");
local block_types     = commonlib.gettable("MyCompany.Aries.Game.block_types");
local names           = commonlib.gettable("MyCompany.Aries.Game.block_types.names");
local TaskManager     = commonlib.gettable("MyCompany.Aries.Game.TaskManager");
local getOsmService   = commonlib.gettable("Mod.EarthMod.getOsmService");
local EntityManager   = commonlib.gettable("MyCompany.Aries.Game.EntityManager");
local CommandManager  = commonlib.gettable("MyCompany.Aries.Game.CommandManager");
local EarthMod        = commonlib.gettable("Mod.EarthMod");

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
gisToBlocks.zoom   = 17;

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

local function pixel2deg(tileX,tileY,pixelX,pixelY,zoom)
	local n = 2 ^ zoom;
	local lon_deg = (tileX + pixelX/256) / n * 360.0 - 180.0;
	local lat_rad = math.atan(math.sinh(math.pi * (1 - 2 * (tileY + pixelY/256) / n)))
	local lat_deg = lat_rad * 180.0 / math.pi
	return tostring(lon_deg), tostring(lat_deg);
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

function gisToBlocks:ctor()
	self.step = 1;
	self.history = {};
end

function gisToBlocks:AddBlock(spx, spy, spz, block_id, block_data)
	if(self.add_to_history) then
		local from_id = BlockEngine:GetBlockId(spx,spy,spz);
		local from_data, from_entity_data;

		if(from_id and from_id>0) then
			from_data = BlockEngine:GetBlockData(spx,spy,spz);
			from_entity_data = BlockEngine:GetBlockEntityData(spx,spy,spz);
		end

		from_id = 0;
		--LOG.std(nil,"debug","AddBlock",{x,y,z,block_id,from_id,from_data,from_entity_data});
		self.history[#(self.history)+1] = {spx,spy,spz, block_id, from_id, from_data, from_entity_data};
	end
	local block_template = block_types.get(block_id);

	if(block_template) then
		block_template:Create(spx,spy,spz, false, block_data);
	end
end

function gisToBlocks:drawpixel(cx, cy, cz)
	self:AddBlock(cx,cz,cy,28,0);
end

function gisToBlocks:drawline(cx1, cy1, cx2, cy2, cz)
	--local x, y, dx, dy, s1, s2, p, temp, interchange, i;
	cx=cx1;
	cy=cy1;
	dcx=math.abs(cx2-cx1);
	dcy=math.abs(cy2-cy1);

	if(cx2>cx1) then
		s1=1;
	else
		s1=-1;
	end

	if(cy2 > cy1) then
		s2 = 1;
	else
		s2 = -1;
	end

	if(dcy > dcx) then
		temp = dcx;
		dcx   = dcy;
		dcy   = temp;
	    interchange = 1;
	else
	    interchange = 0;
	end

	p = 2*dcy - dcx;

	for i=1,dcx do
		self:drawpixel(cx,cy,cz);

		if(p>=0) then
			if(interchange==0) then
				cy = cy+s2;
			else
				cx = cx+s1;
			end
			p = p-2*dcx;
		end

		if(interchange == 0) then
			cx = cx+s1; 
		else
			cy = cy+s2;
		end

		p = p+2*dcy;
	end
end

function gisToBlocks:OSMToBlock(vector, px, py, pz)
	local xmlRoot = ParaXML.LuaXML_ParseString(vector);
	local tileX,tileY;

	if(self.options == "coordinate") then
		echo("coordinate");
		tileX = self.home.tileX;
		tileY = self.home.tileY;
	elseif(self.options == "already")then
		echo("already");
		tileX = self.more.tileX;
		tileY = self.more.tileY;
	end

	LOG.std(nil,"debug","tileX,tileY",{tileX,tileY});

	if (not xmlRoot) then
		LOG.std(nil, "info", "ParseOSM", "Failed loading OSM");
		_guihelper.MessageBox("Failed loading OSM");
		return;
	end

	local osmnode = commonlib.XPath.selectNodes(xmlRoot, "/osm")[1];

	local osmNodeList = {};
	local count = 1;

	for osmnode in commonlib.XPath.eachNode(osmnode, "/node") do
		osmNodeItem = { id = osmnode.attr.id; lat = osmnode.attr.lat; lon = osmnode.attr.lon; }
		osmNodeList[count] = osmNodeItem;
		count = count + 1;
	end

	local osmBuildingList = {}
	local osmBuildingCount = 0;

	local waynode;
	for waynode in commonlib.XPath.eachNode(osmnode, "/way") do
	    local found = false; --only find one building nodes

		local tagnode;
		for tagnode in commonlib.XPath.eachNode(waynode, "/tag") do	
			if (tagnode.attr.k == "building") then

				local buildingPointList = {};
				local buildingPointCount = 0;

				--find node belong to building tag way <nd ref="1765621163"/>
				local ndnode;
				for ndnode in commonlib.XPath.eachNode(waynode, "/nd") do 			
					for i=1, #osmNodeList do
						local item = osmNodeList[i];
						if (item.id == ndnode.attr.ref) then
							cur_tilex, cur_tiley = deg2tile(item.lon, item.lat, self.zoom);
							if (cur_tilex == tileX) and (cur_tiley == tileY) then
								
								--local str = item.id..","..item.lat..","..item.lon.." -> "..tostring(xpos)..","..tostring(ypos);
								--LOG.std(nil, "info", "found building node:", str);

								--buildingPoint = {id = item.id; x = item.lon; y = item.lat; z = 1; }
								xpos, ypos = deg2pixel(item.lon, item.lat, self.zoom);

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

	local factor = 1;
	local PNGSize = math.ceil(256/factor);

	for k,v in pairs(osmBuildingList) do
		buildingPointList = v.points;

		if (buildingPointList) then
			local length = #buildingPointList;
			if (length > 3) then
				for i = 1, length - 1 do
					local buildingA = buildingPointList[i];
					buildingA.cx    = px + math.ceil(buildingA.x/factor) - (256/2);
					buildingA.cy    = pz - math.ceil(buildingA.y/factor) + PNGSize - (256/2);
					buildingA.cz    = py+1;

					local buildingB = buildingPointList[i + 1];
					buildingB.cx    = px + math.ceil(buildingB.x/factor) - (256/2);
					buildingB.cy    = pz - math.ceil(buildingB.y/factor) + PNGSize - (256/2);
					buildingB.cz    = py+1;

					if (buildingA.x < buildingB.x) then
						self:drawline(buildingA.cx , buildingA.cy , buildingB.cx , buildingB.cy , buildingA.cz);
					else
						self:drawline(buildingB.cx , buildingB.cy , buildingA.cx , buildingA.cy , buildingB.cz);
					end
				end
			end
		end
	end
end

function gisToBlocks:PNGToBlock(raster, px, py, pz)
	local colors = self.colors;
	local factor = 1;

	if(raster:IsValid()) then
		local ver           = raster:ReadInt();
		local width         = raster:ReadInt();
		local height        = raster:ReadInt();
		local bytesPerPixel = raster:ReadInt();-- how many bytes per pixel, usually 1, 3 or 4
		LOG.std(nil, "info", "gisToBlocks", {ver, width, height, bytesPerPixel});

		local block_world = GameLogic.GetBlockWorld();

		local function CreateBlock_(ix, iy, block_id, block_data)
			local z;
			spx, spy, spz = px+ix-(256/2), py, pz+iy-(256/2);
			ParaBlockWorld.LoadRegion(block_world, spx, spy, spz);

			self:AddBlock(spx, spy, spz, block_id, block_data);
		end

		--array of {r,g,b,a}
		local pixel = {};

		if(bytesPerPixel >= 3) then
			local block_per_tick = 100;
			local count = 0;
			local row_padding_bytes = (bytesPerPixel*width)%4;

			if(row_padding_bytes > 0) then
				row_padding_bytes = 4-row_padding_bytes;
			end

--			local worker_thread_co = coroutine.create(function ()
				for iy=1, width do
					for ix=1, height do
						pixel = raster:ReadBytes(bytesPerPixel, pixel);
						if(pixel[4]~=0) then
							-- transparent pixel does not show up. 
							local block_id, block_data = GetBlockIdFromPixel(pixel, colors);
							if(block_id) then
								--LOG.std(nil,"debug","x,y,block_id,block_data",{x,y,block_id,block_data});
								--if(x>= 10 and x <= 128 and y >= 10 and y <= 128) then
									CreateBlock_(ix,iy, block_id, block_data);
								--end
								count = count + 1;
								if((count%block_per_tick) == 0) then
--									coroutine.yield(true);
								end
							end
						end
					end
					if(row_padding_bytes > 0) then
						file:ReadBytes(row_padding_bytes, pixel);
					end
				end
--				return;
--			end)

--			local timer = commonlib.Timer:new({callbackFunc = function(timer)
--				local status, result = coroutine.resume(worker_thread_co);
--				if not status then
--					LOG.std(nil, "info", "PNGToBlocks", "finished with %d blocks: %s ", count, tostring(result));
--					timer:Change();
--					raster:close();
--				end
--			end})
--			timer:Change(30,30);

			UndoManager.PushCommand(self);
		else
			LOG.std(nil, "error", "PNGToBlocks", "format not supported");
			raster:close();
		end
	end
end

function gisToBlocks:MoreScene()
	self.options = "already";
	self.more    = {};
	local absCoordinate = EarthMod:GetWorldData("absCoordinate");
	local px, py, pz    = EntityManager.GetFocus():GetBlockPos();

	local pright, pleft, pright, pleft, layerX, layerZ, morePx, morePz, distanceX, distanceZ;
	if(px > (self.home.px + 128)) then
		pright     = self.home.px + 128;
		distanceX  = math.abs(px - pright);
		layerX     = math.ceil(distanceX/256);
		morePx     = pright + (layerX * 256) - 128;

		self.home.dright = self.home.lat + (absCoordinate.lat/2);
		self.more.dright = self.home.dright + (absCoordinate.lat * layerX);
		self.more.dleft	 = self.home.dright + (absCoordinate.lat * (layerX - 1));
	elseif(px < (self.home.px-128)) then
		pleft      = self.home.px - 128;
		distanceX  = math.abs(px - pleft);
		layerX     = math.ceil(distanceX/256);
		morePx     = pleft - (layerX * 256) + 128;

		self.home.dleft  = self.home.lat - (absCoordinate.lat/2);
		self.more.dright = self.home.dleft - (absCoordinate.lat * (layerX - 1));
		self.more.dleft  = self.home.dleft - (absCoordinate.lat * layerX);
	end

	if(pz > (self.home.pz + 128)) then
		ptop      = self.home.pz + 128;
		distanceZ = math.abs(pz - ptop);
		layerZ    = math.ceil(distanceZ/256);
		morePz    = ptop + (layerZ * 256) - 128;

		self.home.dtop    = self.home.lon + (absCoordinate.lon/2);
		self.more.dtop    = self.home.dtop + (absCoordinate.lon * layerZ);
		self.more.dbottom = self.home.dtop + (absCoordinate.lon * (layerZ - 1));
	elseif(pz < (self.home.pz - 128)) then
		pbottom   = self.home.pz - 128;
		distanceZ = math.abs(pz - pbottom);
		layerZ    = math.ceil(distanceZ/256);
		morePz    = pbottom - (layerZ * 256) + 128;

		self.home.dbottom = self.home.lon - (absCoordinate.lon/2);
		self.more.dtop    = self.home.dbottom - (absCoordinate.lon * (layerZ - 1));
		self.more.dbottom = self.home.dbottom - (absCoordinate.lon * layerZ);
	end

	if(distanceX == 0 and distanceZ == 0) then
		LOG.std(nil,"error","error position");
		return;
	end

	LOG.std(nil,"debug","morePx,morePz",{morePx,morePz});

	if(morePx == nil) then
		morePx = self.home.px;
		self.more.dleft = self.home.lat - (absCoordinate.lat/2);
		self.more.dright = self.home.lat + (absCoordinate.lat/2);
	end

	if(morePz == nil) then
		morePz = self.home.pz;
		self.more.dtop = self.home.lon + (absCoordinate.lon/2);
		self.more.dbottom = self.home.lon - (absCoordinate.lon/2);
	end

	LOG.std(nil,"debug","dtop,dbottom,dleft,dright",{self.more.dtop,self.more.dbottom,self.more.dleft,self.more.dright});

	local morePy = 5;

	echo(morePx);
	echo(morePz);

	local moreLat = self.more.dright - (absCoordinate.lat/2);
	local moreLon = self.more.dtop - (absCoordinate.lon/2);

	self.more.tileX, self.more.tileY = deg2tile(moreLat, moreLon, self.zoom);

	LOG.std(nil,"debug","moreLat,moreLon",{moreLat, moreLon});
	LOG.std(nil,"debug","self.cache",self.cache);
	self:GetData(function(raster,vector)
		self:PNGToBlock(raster, morePx, morePy, morePz);
		self:OSMToBlock(vector, morePx, morePy, morePz);

		local allBoundary = EarthMod:GetWorldData("boundary");
		LOG.std(nil,"debug","allBoundary",allBoundary);
		allBoundary[#allBoundary +1 ] = {ptop = morePz + 128, pbottom = morePz - 128, pleft = morePx - 128, pright = morePx + 128};
		LOG.std(nil,"debug","allBoundary",allBoundary);
		EarthMod:SetWorldData("boundary",allBoundary);
	end);
end

function gisToBlocks:LoadToScene(raster,vector)
	local colors = self.colors;

	local px, py, pz = EntityManager.GetFocus():GetBlockPos();

	if(not px) then
		return;
	end

	local homeBoundary = {ptop = pz + 128, pbottom = pz - 128, pleft = px - 128, pright = px + 128};

	EarthMod:SetWorldData("homePosition",{px = px, py = py, pz = pz});
	EarthMod:SetWorldData("boundary",{homeBoundary});
	
	self:PNGToBlock(raster, px, py, pz);
	self:OSMToBlock(vector, px, py, pz);

	CommandManager:RunCommand("/save");
	EarthMod:SaveWorldData();
end

function gisToBlocks:GetData(_callback)
	local raster,vector;
	local tileX,tileY;
	local dtop,dbottom,dleft,dright;
	
	if(self.options == "coordinate") then
		tileX = self.home.tileX;
		tileY = self.home.tileY;

		dtop    = self.home.dtop;
		dbottom = self.home.dbottom;
		dleft   = self.home.dleft;
		dright  = self.home.dright;
	end

	if(self.options == "already") then
		tileX = self.more.tileX;
		tileY = self.more.tileY;
		
		dtop    = self.more.dtop;
		dbottom = self.more.dbottom;
		dleft   = self.more.dleft;
		dright  = self.more.dright;
	end

	LOG.std(nil,"debug","tileX,tileY,dtop,dbottom,dleft,dright",{tileX,tileY,dtop,dbottom,dleft,dright});

	if(self.cache == 'true') then
		GameLogic.SetStatus(L"下载数据中");
		getOsmService:getOsmPNGData(tileX,tileY,function(raster)
			getOsmService:getOsmXMLData(dleft,dbottom,dright,dtop,function(vector)
				raster = ParaIO.open("tile.png", "image");
				GameLogic.SetStatus(L"下载成功");
				_callback(raster,vector);
			end);
		end);
	else
		local vectorFile;

		raster     = ParaIO.open("tile.png", "image");
		vectorFile = ParaIO.open("xml.osm", "r");
		vector     = vectorFile:GetText(0, -1);
		vectorFile:close();

		_callback(raster,vector);
	end
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

function gisToBlocks:BoundaryCheck()
	local px, py, pz = EntityManager.GetFocus():GetBlockPos();

	local function common(text)
		GameLogic.SetStatus(text);
	end

	local allBoundary = EarthMod:GetWorldData("boundary");

	local exceeding = true;
	for key, boundary in pairs(allBoundary) do
		if(px <= boundary.pright and px >= boundary.pleft and pz <= boundary.ptop and pz >= boundary.pbottom) then
			--common(L"未超出");
			exceeding = false;
			break;
		end
	end

	return exceeding;
end

function gisToBlocks:Run()
	self.finished = true;

	getOsmService.zoom = self.zoom;

	if(self.options == "coordinate") then
		--LOG.std(nil,"debug","self.lon,self.lat",{self.lon,self.lon});
		self.home = {};
		self.home.tileX , self.home.tileY = deg2tile(self.lon,self.lat,self.zoom);
		
		self.home.dleft , self.home.dtop    = pixel2deg(self.home.tileX,self.home.tileY,0,0,self.zoom);
		self.home.dright, self.home.dbottom = pixel2deg(self.home.tileX,self.home.tileY,255,255,self.zoom);
		
		local abslat  = math.abs(self.home.dleft - self.home.dright);
		local abslon  = math.abs(self.home.dtop  - self.home.dbottom);
		local homelat = self.home.dleft + (abslat/2);
		local homelon = self.home.dtop  - (abslon/2);

		EarthMod:SetWorldData("selectCoordinate", {lat = tostring(self.lon), lon = tostring(self.lon)});
		EarthMod:SetWorldData("homeCoordinate", {lat = tostring(homelat), lon = tostring(homelon)});
		EarthMod:SetWorldData("absCoordinate", {lat = tostring(abslat), lon = tostring(abslon)});

		if(GameLogic.GameMode:CanAddToHistory()) then
			self.add_to_history = true;
		end

		self:GetData(function(raster,vector)
			self:LoadToScene(raster,vector);
		end);
	end

	if(self.options == "already") then
		local homePosition   = EarthMod:GetWorldData("homePosition");
		local homeCoordinate = EarthMod:GetWorldData("homeCoordinate");

		self.home = {};
		self.home.lat = homeCoordinate.lat;
		self.home.lon = homeCoordinate.lon;
		self.home.px  = homePosition.px;
		self.home.py  = homePosition.py;
		self.home.pz  = homePosition.pz;
	end
end