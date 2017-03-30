--[[
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
gisToBlocks.crossPointLists = {};

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
    local x = math.floor(n * ((lon_deg + 180) / 360) * 256 % 256 + 0.5)
    local y = math.floor(n * (1 - (math.log(math.tan(lat_rad) + (1 / math.cos(lat_rad))) / math.pi)) / 2 * 256 % 256 + 0.5)
    return x, y
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

--function gisToBlocks:AddBlock(spx, spy, spz, block_id, block_data)
--	if(self.add_to_history) then
--		local from_id = BlockEngine:GetBlockId(spx,spy,spz);
--		local from_data, from_entity_data;
--
--		if(from_id and from_id>0) then
--			from_data = BlockEngine:GetBlockData(spx,spy,spz);
--			from_entity_data = BlockEngine:GetBlockEntityData(spx,spy,spz);
--		end
--
--		from_id = 0;
--		--LOG.std(nil,"debug","AddBlock",{x,y,z,block_id,from_id,from_data,from_entity_data});
--		self.history[#(self.history)+1] = {spx,spy,spz, block_id, from_id, from_data, from_entity_data};
--	end
--	local block_template = block_types.get(block_id);
--
--	if(block_template) then
--		block_template:Create(spx,spy,spz, false, block_data);
--	end
--end

function gisToBlocks:drawpixel(cx, cy, cz, blockId)
	BlockEngine:SetBlock(cx,cz,cy,blockId,0);
end

function gisToBlocks:floodFillScanline()
	
end

function gisToBlocks:drawline(cx1, cy1, cx2, cy2, cz, blockId)
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
		self:drawpixel(cx, cy, cz, blockId);

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
		--echo("coordinate");
		tileX = self.home.tileX;
		tileY = self.home.tileY;
	elseif(self.options == "already")then
		--echo("already");
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

	local function draw2Point(self,PointList,blockId,type)
		local factor = 1;
		local PNGSize = math.ceil(256*factor);
		local pointA,pointB;

		if (PointList) then
			local length = #PointList;

			if (length > 3) then
				for i = 1, length - 1 do
					pointA = PointList[i];
					pointB = PointList[i + 1];

					if(type ~= "buildingMore" and type ~= "waterMore") then
						pointA.cx = px + math.ceil(pointA.x*factor) - PNGSize/2;
						pointA.cy = pz - math.ceil(pointA.y*factor) + PNGSize - PNGSize/2;

						pointB.cx = px + math.ceil(pointB.x*factor) - PNGSize/2;
						pointB.cy = pz - math.ceil(pointB.y*factor) + PNGSize - PNGSize/2;
					end

					pointA.cz = pointA.z;
					pointB.cz = pointB.z;

					local function floor(self)
						if (pointA.cx < pointB.cx) then
							self:drawline(pointA.cx, pointA.cy, pointB.cx, pointB.cy, pointA.cz, blockId);
						else
							self:drawline(pointB.cx, pointB.cy, pointA.cx, pointA.cy, pointB.cz, blockId);
						end
					end

					if(type == "building" or type == "buildingMore") then
						--echo(pointA.level);
						for i = 1, 3 * pointA.level do
							floor(self);
							--echo(pointA.cz);
							pointA.cz = pointA.cz + 1;
							pointB.cz = pointB.cz + 1;
						end
					else
						floor(self);
					end
				end
			end
		end
	end

	local function draw2area(self,PointList,blockId,type)
		if (PointList) then
			local point = {left = PointList[1].cx, right = PointList[1].cx, top = PointList[1].cy, bottom = PointList[1].cy};
			local currentPoint;

			if(type == "building" or type == "buildingMore") then
				point.level = PointList[1].level;
			end

			local length = #PointList;

			if (length > 3) then
				for k,v in pairs(PointList) do
					currentPoint = PointList[k];

					--get right point
					if(currentPoint.cx < point.left) then
						point.left  = currentPoint.cx;
					end

					--get left point
					if(currentPoint.cx > point.right) then
						point.right = currentPoint.cx;
					end

					--get top point
					if(currentPoint.cy > point.top) then
						point.top    = currentPoint.cy;
					end

					--get bottom point
					if(currentPoint.cy < point.bottom) then
						point.bottom = currentPoint.cy;
					end

					--echo({k,v});
				end
			end

			local startPoint = {cx = point.left, cy = point.bottom, cz = 6};
			local endPoint   = {cx = point.right, cy = point.top, cz = 6};
			
			if(type == "building" or type == "buildingMore") then
				startPoint.level = point.level;
				endPoint.level   = point.level;
			end

			currentPoint = {};
			currentPoint = commonlib.copy(startPoint);

			--LOG.std(nil,"debug","currentPoint",currentPoint);

			local linePoint = {};

			if(currentPoint.cy)then
				while(currentPoint.cx <= endPoint.cx) do
					local loopY = commonlib.copy(currentPoint.cy);
					local currentblockId;
					local lastblockId

					while(loopY <= endPoint.cy) do
						local currentBlockId = BlockEngine:GetBlockId(currentPoint.cx,currentPoint.cz,loopY);
						local count = 0;

						if(currentBlockId == 0) then
							local judgeX = commonlib.copy(currentPoint.cx);
							while(judgeX <= endPoint.cx) do
								local judgeXBlockId = BlockEngine:GetBlockId(judgeX,currentPoint.cz,loopY);

								if(judgeXBlockId ~= 0) then
									count = count + 1;
									break;
								end

								judgeX = judgeX + 1;
							end

							local judgeX = commonlib.copy(currentPoint.cx);
							while(judgeX >= startPoint.cx) do
								local judgeXBlockId = BlockEngine:GetBlockId(judgeX,currentPoint.cz,loopY);

								if(judgeXBlockId ~= 0) then
									count = count + 1;
									break;
								end

								judgeX = judgeX - 1;
							end

							local judgeY = commonlib.copy(loopY);
							while(judgeY <= endPoint.cy) do
								local judgeXBlockId = BlockEngine:GetBlockId(currentPoint.cx,currentPoint.cz,judgeY);

								if(judgeXBlockId ~= 0) then
									count = count + 1;
									break;
								end

								judgeY = judgeY + 1;
							end

							local judgeY = commonlib.copy(loopY);
							while(judgeY >= startPoint.cy) do
								local judgeXBlockId = BlockEngine:GetBlockId(currentPoint.cx,currentPoint.cz,judgeY);

								if(judgeXBlockId ~= 0) then
									count = count + 1;
									break;
								end

								judgeY = judgeY - 1;
							end

							if(count == 4) then
								local height;
								if(type == "building" or type == "buildingMore") then
									height = (currentPoint.cz - 1) + currentPoint.level * 3;
								else
									height = currentPoint.cz;
								end
								BlockEngine:SetBlock(currentPoint.cx,height,loopY,blockId,0);
							end
						end

						loopY = loopY + 1;
					end
					currentPoint.cx = currentPoint.cx + 1;
				end
			end
		end
	end

	local osmBuildingList  = {}
	local osmBuildingCount = 0;

	local osmHighWayList   = {};
	local osmHighWayCount  = 0;

	local osmWaterList     = {};
	local osmWaterCount    = 0;

	for waynode in commonlib.XPath.eachNode(osmnode, "/way") do
		local buildingLevel = 1;
		for tagnode in commonlib.XPath.eachNode(waynode, "/tag") do	
			if(tagnode.attr.k == "building:levels") then
				buildingLevel = commonlib.copy(tagnode.attr.v);
			end

			LOG.std(nil,"debug","buildingLevel",buildingLevel);
		end

		for tagnode in commonlib.XPath.eachNode(waynode, "/tag") do	
			---------building start----------
			if(tagnode.attr.k == "building") then
				local buildingPoint;
				local buildingPointList  = {};
				local buildingPointCount = 0;

				local isNew = true;
				if(#gisToBlocks.crossPointLists ~= 0) then
					for key,crossBuildingList in pairs(gisToBlocks.crossPointLists) do
						if(crossBuildingList.id == waynode.attr.id) then
							isNew = false;
							for crossKey,point in pairs(crossBuildingList.points) do
								if(point.draw == "false") then
									for i=1, #osmNodeList do
										local item = osmNodeList[i];
										if (item.id == point.id) then
											cur_tilex, cur_tiley = deg2tile(item.lon, item.lat, self.zoom);
											if (cur_tilex == tileX) and (cur_tiley == tileY) then
												xpos, ypos = deg2pixel(item.lon, item.lat, self.zoom);
												point.cx = px + xpos - 256/2;
												point.cy = pz - ypos + 256 - 256/2;
												point.draw = "true";
											end
										end
									end
								end
							end
							--LOG.std(nil,"debug","crossBuildingList.points",crossBuildingList.points);
							isDraw = true;
							for drawKey,point in pairs(crossBuildingList.points) do
								if(point.draw == "false") then
									isDraw = false;
								end
							end

							if(isDraw) then
								draw2Point(self,crossBuildingList.points,51,"buildingMore");
								draw2area(self,crossBuildingList.points,51,"buildingMore");
								crossBuildingList = false;
							end
						end
					end
				end
				
				if(isNew) then
					local curNd        = {};
					local curNdCount   = 0;
					local drawNdcount  = 0;
					for ndnode in commonlib.XPath.eachNode(waynode, "/nd") do
						curNdCount             = curNdCount + 1;
						curNd[curNdCount]      = ndnode;
						curNd[curNdCount].draw = "false";

						for i=1, #osmNodeList do
							local item = osmNodeList[i];
							if (item.id == ndnode.attr.ref) then
								cur_tilex, cur_tiley = deg2tile(item.lon, item.lat, self.zoom);
								if (cur_tilex == tileX) and (cur_tiley == tileY) then
									xpos, ypos = deg2pixel(item.lon, item.lat, self.zoom);

									buildingPoint      = {id = item.id, x = xpos, y = ypos, z = 6, level = buildingLevel};
									buildingPointCount = buildingPointCount + 1;

									buildingPointList[buildingPointCount] = buildingPoint;

									drawNdcount       = drawNdcount + 1;
									curNd[curNdCount] = buildingPoint;
									curNd[curNdCount].draw = "true";
								else
									buildingPoint     = {id = item.id, z = 6, level = buildingLevel};
									curNd[curNdCount] = buildingPoint;
									curNd[curNdCount].draw = "false";
								end	
							end
						end
					end

					local osmBuilding;

					if(drawNdcount == curNdCount) then
						osmBuilding = {id = waynode.attr.id, points = buildingPointList};
						osmBuildingCount = osmBuildingCount + 1;
						osmBuildingList[osmBuildingCount] = osmBuilding;

						echo(osmBuildingList);
					else
						for key,point in pairs(curNd) do
							if(point.x) then
								point.cx = px + math.ceil(point.x) - 256/2;
							end

							if(point.y) then
								point.cy = pz - math.ceil(point.y) + 256 - 256/2;
							end

							point.cz = point.z;
						end

						osmBuilding = {id = waynode.attr.id, points = curNd};

						gisToBlocks.crossPointLists[#gisToBlocks.crossPointLists + 1] = osmBuilding;
					end
				end
			end
			---------building  end----------

			---------highway start----------
			if (tagnode.attr.k == "highway") then
				local highWayPoint;
				local highWayPointList  = {};
				local highWayPointCount = 0;

				for ndnode in commonlib.XPath.eachNode(waynode, "/nd") do 			
					for i=1, #osmNodeList do
						local item = osmNodeList[i];
						if (item.id == ndnode.attr.ref) then
							cur_tilex, cur_tiley = deg2tile(item.lon, item.lat, self.zoom);
							if (cur_tilex == tileX) and (cur_tiley == tileY) then
								xpos, ypos = deg2pixel(item.lon, item.lat, self.zoom);

								highWayPoint	   = {id = item.id, x = xpos, y = ypos , z = 5};
								highWayPointCount  = highWayPointCount + 1;

								highWayPointList[highWayPointCount] = highWayPoint;
							end
						end
				    end
			    end

				local osmHighWay;

				osmHighWay      = {id = waynode.attr.id, points = highWayPointList};
				osmHighWayCount = osmHighWayCount + 1;
				osmHighWayList[osmHighWayCount] = osmHighWay;
			end
			--------highway end----------

			--------water start----------
			if (tagnode.attr.k == "natural" and tagnode.attr.v == "water") then
				local waterPoint;
				local waterPointList  = {};
				local waterPointCount = 0;

				local isNew = true;
				LOG.std(nil,"debug","gisToBlocks.crossPointLists",gisToBlocks.crossPointLists);
				if(#gisToBlocks.crossPointLists ~= 0) then
					for key,crossWaterList in pairs(gisToBlocks.crossPointLists) do
						if(crossWaterList.id == waynode.attr.id) then
							isNew = false;
							for crossKey,point in pairs(crossWaterList.points) do
								if(point.draw == "false") then
									for i=1, #osmNodeList do
										local item = osmNodeList[i];
										if (item.id == point.id) then
											cur_tilex, cur_tiley = deg2tile(item.lon, item.lat, self.zoom);
											if (cur_tilex == tileX) and (cur_tiley == tileY) then
												xpos, ypos = deg2pixel(item.lon, item.lat, self.zoom);
												point.cx = px + xpos - 256/2;
												point.cy = pz - ypos + 256 - 256/2;
												point.draw = "true";
											end
										end
									end
								end
							end
							--LOG.std(nil,"debug","crossWaterList.points",crossWaterList.points);
							isDraw = true;
							for drawKey,point in pairs(crossWaterList.points) do
								if(point.draw == "false") then
									isDraw = false;
								end
							end

							if(isDraw) then
								draw2Point(self,crossWaterList.points,4,"waterMore");
								draw2area(self,crossWaterList.points,76);
								--crossWaterList = false;
							end
						end
					end
				end

				if(isNew) then
					local curNd        = {};
					local curNdCount   = 0;
					local drawNdcount  = 0;
					for ndnode in commonlib.XPath.eachNode(waynode, "/nd") do
						curNdCount             = curNdCount + 1;
						curNd[curNdCount]      = ndnode;
						curNd[curNdCount].draw = "false";

						for i=1, #osmNodeList do
							local item = osmNodeList[i];
							if (item.id == ndnode.attr.ref) then
								cur_tilex, cur_tiley = deg2tile(item.lon, item.lat, self.zoom);
								if (cur_tilex == tileX) and (cur_tiley == tileY) then
									xpos, ypos = deg2pixel(item.lon, item.lat, self.zoom);

									waterPoint	     = {id = item.id, x = xpos, y = ypos , z = 6};
									waterPointCount  = waterPointCount + 1;

									waterPointList[waterPointCount] = waterPoint;

									drawNdcount       = drawNdcount + 1;
									curNd[curNdCount] = waterPoint;
									curNd[curNdCount].draw = "true";
								else
									waterPoint        = {id = item.id, z = 6};
									curNd[curNdCount] = waterPoint;
									curNd[curNdCount].draw = "false";
								end	
							end
						end
					end

					local osmWater;
					
					if(drawNdcount == curNdCount) then
						osmWater      = {id = waynode.attr.id, points = waterPointList};
						osmWaterCount = osmWaterCount + 1;
						osmWaterList[osmWaterCount] = osmWater;
					else
						for key,point in pairs(curNd) do
							if(point.x) then
								point.cx = px + math.ceil(point.x) - 256/2;
							end

							if(point.y) then
								point.cy = pz - math.ceil(point.y) + 256 - 256/2;
							end

							point.cz = point.z;
						end

						osmWater = {id = waynode.attr.id, points = curNd};

						gisToBlocks.crossPointLists[#gisToBlocks.crossPointLists + 1] = osmWater;
					end
				end
			end
			--------water end----------
		end
	end

	local buildingPointList;
	for k,v in pairs(osmBuildingList) do
		buildingPointList = v.points;
		
		draw2Point(self,buildingPointList,51,"building");
		draw2area(self,buildingPointList,51,"buildingMore");
	end

	local waterPointList;
	if(osmWaterList) then
		for k,v in pairs(osmWaterList) do
			waterPointList = v.points;
		
			draw2Point(self,waterPointList,4,"water");
			draw2area(self,waterPointList,76);
		end
	end

	local highWayPointList;
	for k,v in pairs(osmHighWayList) do
		highWayPointList = v.points;

		draw2Point(self,highWayPointList,180,"highWay");

		local makemore = commonlib.copy(highWayPointList);

		for key,value in pairs(makemore) do
			--LOG.std(nil,"debug","value",value.cx);
			if(value.x and value.y) then
				makemore[key].x = value.x - 1;
			end
		end
		draw2Point(self,makemore,180,"highWay");

		for key,value in pairs(makemore) do
			--LOG.std(nil,"debug","value",value.cx);
			if(value.x and value.y) then
				makemore[key].x = value.x - 1;
			end
		end
		draw2Point(self,makemore,180,"highWay");

		for key,value in pairs(makemore) do
			--LOG.std(nil,"debug","value",value.cx);
			if(value.x and value.y) then
				makemore[key].x = value.x - 1;
			end
		end
		draw2Point(self,makemore,180,"highWay");

		-----

		local makemore = commonlib.copy(highWayPointList);

		for key,value in pairs(makemore) do
			--LOG.std(nil,"debug","value",value.cx);
			if(value.x and value.y) then
				makemore[key].y = value.y - 1;
			end
		end
		draw2Point(self,makemore,180,"highWay");

		for key,value in pairs(makemore) do
			--LOG.std(nil,"debug","value",value.cx);
			if(value.x and value.y) then
				makemore[key].y = value.y - 1;
			end
		end
		draw2Point(self,makemore,180,"highWay");

		for key,value in pairs(makemore) do
			--LOG.std(nil,"debug","value",value.cx);
			if(value.x and value.y) then
				makemore[key].y = value.y - 1;
			end
		end
		draw2Point(self,makemore,180,"highWay");
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
		--LOG.std(nil, "info", "gisToBlocks", {ver, width, height, bytesPerPixel});

		local block_world = GameLogic.GetBlockWorld();

		local function CreateBlock_(ix, iy, block_id, block_data)
			local z;
			spx, spy, spz = px+ix-(256/2), py, pz+iy-(256/2);
			ParaBlockWorld.LoadRegion(block_world, spx, spy, spz);

			BlockEngine:SetBlock(spx, spy, spz, block_id, block_data);
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

	--echo(morePx);
	--echo(morePz);

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
	LOG.std(nil,"debug","px,py,pz",{px,py,pz});
	if(not px) then
		return;
	end

	local homeBoundary = {ptop = pz + 128, pbottom = pz - 128, pleft = px - 128, pright = px + 128};

	EarthMod:SetWorldData("homePosition",{px = px, py = py, pz = pz});
	EarthMod:SetWorldData("boundary",{homeBoundary});
	
	self:PNGToBlock(raster, px, py, pz);
	self:OSMToBlock(vector, px, py, pz);

	self.home.px = px;
	self.home.py = py;
	self.home.pz = pz;

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

	--echo(BlockEngine:GetBlockId(px, py - 1, pz));

	local function common(text)
		GameLogic.SetStatus(text);
	end

	local allBoundary = EarthMod:GetWorldData("boundary");

	local exceeding = true;

	if(allBoundary) then
		for key, boundary in pairs(allBoundary) do
			if(px <= boundary.pright and px >= boundary.pleft and pz <= boundary.ptop and pz >= boundary.pbottom) then
				--common(L"未超出");
				exceeding = false;
				break;
			end
		end
	end

	return exceeding;
end

function gisToBlocks:Run()
	self.finished = true;

	if(GameLogic.GameMode:CanAddToHistory()) then
		self.add_to_history = false;
	end

	getOsmService.zoom = self.zoom;

	if(self.options == "coordinate") then
		--LOG.std(nil,"debug","self.lon,self.lat",{self.lon,self.lon});
		self.home = {};
		self.home.tileX , self.home.tileY = deg2tile(self.lon,self.lat,self.zoom);
		
		self.home.dleft , self.home.dtop    = pixel2deg(self.home.tileX,self.home.tileY,0,0,self.zoom);
		self.home.dright, self.home.dbottom = pixel2deg(self.home.tileX,self.home.tileY,255,255,self.zoom);
		
		local abslat  = math.abs(self.home.dleft - self.home.dright);
		local abslon  = math.abs(self.home.dtop  - self.home.dbottom);
		
		self.home.lat = self.home.dleft + (abslat/2);
		self.home.lon = self.home.dtop  - (abslon/2);

		EarthMod:SetWorldData("selectCoordinate", {lat = tostring(self.lat), lon = tostring(self.lon)});
		EarthMod:SetWorldData("homeCoordinate", {lat = tostring(self.home.lat), lon = tostring(self.home.lon)});
		EarthMod:SetWorldData("absCoordinate", {lat = tostring(abslat), lon = tostring(abslon)});

		self:GetData(function(raster,vector)
			self:LoadToScene(raster,vector);
		end);
	end

	if(self.options == "already") then
		local homePosition   = EarthMod:GetWorldData("homePosition");
		local homeCoordinate = EarthMod:GetWorldData("homeCoordinate");

		LOG.std(nil,"debug","homePosition",homePosition);

		self.home = {};
		self.home.lat = homeCoordinate.lat;
		self.home.lon = homeCoordinate.lon;
		self.home.px  = homePosition.px;
		self.home.py  = homePosition.py;
		self.home.pz  = homePosition.pz;
	end
end