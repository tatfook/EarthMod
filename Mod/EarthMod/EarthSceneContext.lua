--[[
Title: EarthSceneContext
Author(s): ray
Date: 2017.2
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/EarthSceneContext.lua");
local EarthSceneContext = commonlib.gettable("Mod.EarthMod.EarthSceneContext");
EarthSceneContext:ApplyToDefaultContext();
------------------------------------------------------------
]]

NPL.load("(gl)script/ide/System/os/GetUrl.lua");
NPL.load("(gl)script/ide/System/Core/SceneContext.lua");
NPL.load("(gl)script/ide/NPLExtension.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/World/ChunkGenerator.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Commands/CommandManager.lua");

local BlockEngine       = commonlib.gettable("MyCompany.Aries.Game.BlockEngine");
local block_types       = commonlib.gettable("MyCompany.Aries.Game.block_types");
local EntityManager     = commonlib.gettable("MyCompany.Aries.Game.EntityManager");
local names             = commonlib.gettable("MyCompany.Aries.Game.block_types.names");
local CommandManager    = commonlib.gettable("MyCompany.Aries.Game.CommandManager");
local GameLogic         = commonlib.gettable("MyCompany.Aries.Game.GameLogic");
local EarthSceneContext = commonlib.inherit(commonlib.gettable("System.Core.SceneContext"), commonlib.gettable("Mod.EarthMod.EarthSceneContext"));

function drawpixel(x, y, z)
		--local spawn_x, spawn_y, spawn_z = self:GetSpawnPosition();			
		--LOG.std(nil, "info", "spawn_x", spawn_x);
		--local x, y, z = BlockEngine:real(spawn_x, spawn_y, spawn_z); 
		EntityManager.GetPlayer():SetBlockPos(x, z, y); 

		local blockstr = "/box 1 1 1";
		--LOG.std(nil, "info", "Command", blockstr);
		CommandManager:RunCommand(blockstr);
end

function drawline(x1, y1, x2, y2, z)
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

	if(y2>y1) then
	s2=1;
	else
	s2=-1;
	end

	if(dy>dx) then
	temp=dx;
	dx=dy;
	dy=temp;
	interchange=1;	
	else
	interchange=0;
	end

	p=2*dy-dx;

	for i=1,dx do
		drawpixel(x,y,z);
		if(p>=0) then
			if(interchange==0) then
				y=y+s2;
			else
				x=x+s1;
			end
			p=p-2*dx;
		end

		if(interchange==0) then
			x=x+s1; 
		else
			y=y+s2;
		end
			p=p+2*dy;
	end
end

function tile2deg(x, y, z)
    local n = 2 ^ z
    local lon_deg = x / n * 360.0 - 180.0
    local lat_rad = math.atan(math.sinh(math.pi * (1 - 2 * y / n)))
    local lat_deg = lat_rad * 180.0 / math.pi
    return lon_deg, lat_deg
end

function deg2tile(lon, lat, zoom)
    local n = 2 ^ zoom
    local lon_deg = tonumber(lon)
    local lat_rad = math.rad(lat)
    local xtile = math.floor(n * ((lon_deg + 180) / 360))
    local ytile = math.floor(n * (1 - (math.log(math.tan(lat_rad) + (1 / math.cos(lat_rad))) / math.pi)) / 2)
    return xtile, ytile
end

function deg2pixel(lon, lat, zoom)
    local n = 2 ^ zoom
    local lon_deg = tonumber(lon)
    local lat_rad = math.rad(lat)
    local xtile = math.floor(n * ((lon_deg + 180) / 360) * 256 % 256 + 0.5)
    local ytile = math.floor(n * (1 - (math.log(math.tan(lat_rad) + (1 / math.cos(lat_rad))) / math.pi)) / 2 * 256 % 256 + 0.5)
    return xtile, ytile
end

function EarthSceneContext:ctor()
    self:EnableAutoCamera(true);
end

-- static method: use this demo scene context as default context
function EarthSceneContext:ApplyToDefaultContext()
	EarthSceneContext:ResetDefaultContext();
	GameLogic.GetFilters():add_filter("DefaultContext", function(context)
	   return EarthSceneContext:CreateGetInstance("MyDefaultSceneContext");
	end);
end

-- static method: reset scene context to vanila scene context
function EarthSceneContext:ResetDefaultContext()
	GameLogic.GetFilters():remove_all_filters("DefaultContext");
end

function EarthSceneContext:LoadOsm()
	--_guihelper.MessageBox("Load lujiazui.osm");

	local osmFilePath = "lujiazui3.osm";

	--上海浦东陆家嘴港务大厦坐标
	local zoom = 17;
	local lon = 121.493798467075;
	local lat = 31.2426585143162;
	
	tilex, tiley = deg2tile(lon, lat, zoom);

	local xmlRoot = ParaXML.LuaXML_ParseFile(osmFilePath);
	if (not xmlRoot) then
		LOG.std(nil, "info", "ParseOSM", "Failed loading lujiazui.osm");
		_guihelper.MessageBox("Failed loading lujiazui.osm");
		return;
	end	

	LOG.std(nil, "info", "ParseOSM", "Successfully loading lujiazui.osm");

	local osmnode = commonlib.XPath.selectNodes(xmlRoot, "/osm")[1];
	
	--LOG.std(nil, "info", "ParseOSM", osmnode.attr);
	
	local osmNodeList = {}
	local count = 1;
	for osmnode in commonlib.XPath.eachNode(osmnode, "/node") do
		osmNodeItem = { id = osmnode.attr.id; lat = osmnode.attr.lat; lon = osmnode.attr.lon; }
		osmNodeList[count] = osmNodeItem;
		count = count + 1;
	end
	--dump osmNodeList
	LOG.std(nil, "info", "osmnode count is", #osmNodeList);
	for i=1, #osmNodeList do
	    local item = osmNodeList[i];
		if (i < 2) then	
			LOG.std(nil, "info", "osmnode", item.id..","..item.lat..","..item.lon);
		    break;
		end
	end

	local osmBuildingList = {}
	local osmBuildingCount = 0;
	    
	local waynode;
	for waynode in commonlib.XPath.eachNode(osmnode, "/way") do
	    local found = false --only find one building nodes
	    
		local tagnode;
		for tagnode in commonlib.XPath.eachNode(waynode, "/tag") do	
			if (tagnode.attr.k == "building") then
				LOG.std(nil, "info", "way tag", waynode.attr.id);	

				local buildingPointList = {}
				local buildingPointCount = 0;

				--find node belong to building tag way
				--<nd ref="1765621163"/>
				local ndnode;
				for ndnode in commonlib.XPath.eachNode(waynode, "/nd") do 					
					for i=1, #osmNodeList do
						local item = osmNodeList[i];
						if (item.id == ndnode.attr.ref) then							
							cur_tilex, cur_tiley = deg2tile(item.lon, item.lat, zoom);
							if (cur_tilex == tilex) and (cur_tiley == tiley) then
								
								local str = item.id..","..item.lat..","..item.lon.." -> "..tostring(xpos)..","..tostring(ypos);
								LOG.std(nil, "info", "found building node:", str);

								--buildingPoint = {id = item.id; x = item.lon; y = item.lat; z = 1; }
								xpos, ypos = deg2pixel(item.lon, item.lat, zoom);
								buildingPoint = {id = item.id; x = xpos; y = ypos; z = 1; }
								buildingPointCount = buildingPointCount + 1;
								buildingPointList[buildingPointCount] = buildingPoint;
							end
						end
				    end
			    end

				osmBuilding = {id = waynode.id; points = buildingPointList; }
				LOG.std(nil, "info", "---------------->", osmBuilding);
				osmBuildingCount = osmBuildingCount + 1;
				osmBuildingList[osmBuildingCount] = osmBuilding;
				
				found = true;
			end
		end

	    if (found) then
	        --break;
	    end
	end
	
	self:ResetDefaultContext();
	GameLogic.ActivateDefaultContext();

	--self:RegisterWorldGenerator();
	--self:RegisterCommand();
	--self:RegisterMenuItem();

	CommandManager:RunCommand("/home");
	CommandManager:RunCommand("/take 28");
	--CommandManager:RunCommand("/box 1 1 1");

	--Draw buildings
	LOG.std(nil, "info", "---------------->", osmBuildingList);

	for k,v in pairs(osmBuildingList) do
		LOG.std(nil, "info", "-----------k----->", k);
		LOG.std(nil, "info", "-----------v----->", v);
		buildingPointList = v.points;

		if (buildingPointList) then
			LOG.std(nil, "info", "---------------->", buildingPointList);
			local length = #buildingPointList;
			if (length > 3) then
				for i = 1, length - 1 do				
					local building = buildingPointList[i];
					--building.x = 19200 + building.x;
					--building.y = 19200 + building.y;
					building.z = 5;

					--local gostr = "/tp "..tostring(building.x).." "..tostring(building.z).." "..tostring(building.y)
					--LOG.std(nil, "info", "Command", gostr);
					--CommandManager:RunCommand(gostr);

					local building2 = buildingPointList[i + 1];
					--building2.x = 19200 + building2.x;
					--building2.y = 19200 + building2.y;
					building2.z = 5;

					--local linestr1 = tostring(building.x).." "..tostring(building.y).." "..tostring(building2.x).." "..tostring(building2.y).." "..tostring(building.z)
					--LOG.std(nil, "info", "drawline", linestr1);
					--building.x, building.y = deg2pixel(building.x, building.y, zoom);
					--building2.x, building2.y = deg2pixel(building2.x, building2.y, zoom);
					local linestr = tostring(building.x).." "..tostring(building.y).." "..tostring(building2.x).." "..tostring(building2.y).." "..tostring(building.z)
					LOG.std(nil, "info", "drawline", linestr);

					factor = 4;
					if (building.x < building2.x) then
						drawline(building.x / factor + 19200, building.y / factor + 19200, building2.x / factor + 19200, building2.y / factor + 19200, building.z);
					else
						drawline(building2.x / factor + 19200, building2.y / factor + 19200, building.x / factor + 19200, building.y / factor + 19200, building.z);
					end
				end
			end
		end
	end

	LOG.std(nil, "info", "ParseOSM", "The end.");
end

function EarthSceneContext:mouseReleaseEvent(event)
	if (event:button() == "left") then
	
		self:LoadOsm();

		local z = 1;

		if (z) then
			return;
		end

		NPL.load("(gl)script/apps/Aries/Creator/Game/blocks/BlockImage.lua");
		local block = commonlib.gettable("MyCompany.Aries.Game.blocks.BlockImage");

		--NPL.SyncFile("http://mt2.google.cn/vt/lyrs=y@258000000&hl=zh-CN&gl=CN&src=app&x=214130&y=114212&z=18&s=Ga", "google.jpg", "DownloadCallback()", "google");
		NPL.SyncFile("http://webrd03.is.autonavi.com/appmaptile?x=1629&y=849&z=11&lang=zh_cn&size=1&scale=1&style=7", "gaode.htm", "DownloadCallback()", "gaode");
		--NPL.SyncFile("http://www.timegis.com/index.htm", "timegis.htm", "DownloadCallback()", "timegis");
		--System.os.GetUrl("http://www.timegis.com/index.htm", echo);

		--local img = "http://tile.openstreetmap.org/7/66/42.png";
		--NPL.SyncFile(img, "42.png", "DownloadCallback()", "open1");

		--_guihelper.MessageBox("You clicked in Demo Scene Context. Switching to default context?", function()
		self:ResetDefaultContext();
		GameLogic.ActivateDefaultContext();

		local img = "http://tile.openstreetmap.org/7/66/42.png";
		NPL.SyncFile(img, "42.png", "DownloadCallback()", "open1");

		NPL.load("(gl)script/apps/Aries/Creator/Game/Commands/CommandManager.lua");
		local CommandManager = commonlib.gettable("MyCompany.Aries.Game.CommandManager");
		CommandManager:RunCommand("/home");
		local cmd = "/blockimage colors:1 -xz 42.png";
		CommandManager:RunCommand(cmd);
		--end)
	end
end

--[[
Parse *.osm file which download from www.OpenStreetMap.org
<osm version="0.6" generator="CGImap 0.5.8 (5035 thorn-02.openstreetmap.org)" copyright="OpenStreetMap and contributors" 
		attribution="http://www.openstreetmap.org/copyright" license="http://opendatacommons.org/licenses/odbl/1-0/">
	 <bounds minlat="31.2312000" minlon="121.4892000" maxlat="31.2484000" maxlon="121.5136000"/>
	 <node id="59608490" visible="true" version="3" changeset="10130036" timestamp="2011-12-16T10:45:50Z" user="DAJIBA" uid="360397" 
			lat="31.2321150" lon="121.4917826">
		  <tag k="source" v="PGS"/>
	 </node>
	 <way id="415667793" visible="true" version="1" changeset="39109782" timestamp="2016-05-05T00:07:50Z" user="u_kubota" uid="421504">
		  <nd ref="4166616078"/>
		  <nd ref="4166616080"/>
		  <tag k="building" v="yes"/>
		  <tag k="building:levels" v="6"/>
		  <tag k="source" v="Bing"/>
	 </way>
</osm>
]]



