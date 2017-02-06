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

local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic");
local EarthSceneContext = commonlib.inherit(commonlib.gettable("System.Core.SceneContext"), commonlib.gettable("Mod.Earth.EarthSceneContext"));

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
	local xmlRoot = ParaXML.LuaXML_ParseFile(osmFilePath);

	if (not xmlRoot) then
		LOG.std(nil, "info", "ParseOSM", "Failed loading lujiazui.osm");
		_guihelper.MessageBox("Failed loading lujiazui.osm");

		return;
	end	

	LOG.std(nil, "info", "ParseOSM", "Successfully loading lujiazui.osm");

	local osmnode = commonlib.XPath.selectNodes(xmlRoot, "/osm")[1];
	
	--LOG.std(nil, "info", "ParseOSM", osmnode.attr);
	
	local osmNodeList = {};
	local count = 1;

	for osmnode in commonlib.XPath.eachNode(osmnode, "/node") do
		osmNodeItem = {id = osmnode.attr.id;lat = osmnode.attr.lat;lon = osmnode.attr.lon;};
		osmNodeList[count] = osmNodeItem;
		count = count + 1;
	end

	--dump osmNodeList
	LOG.std(nil, "info", "osmnode count is", #osmNodeList);
	for i=1, #osmNodeList do
	    local item = osmNodeList[i];
		if (i < 2) then	
			LOG.std(nil, "info", "osmnode", item.id .. "," .. item.lat .. "," .. item.lon);
		    break;
		end
	end

	local osmBuildingList = {};
	local osmBuildingCount = 1;
	local waynode;

	for waynode in commonlib.XPath.eachNode(osmnode, "/way") do
	    local found = false; --only find one building nodes

		local tagnode;
		for tagnode in commonlib.XPath.eachNode(waynode, "/tag") do	
			if (tagnode.attr.k == "building") then
				LOG.std(nil, "info", "xxxtag", waynode.attr.id);	

				--<nd ref="1765621163"/>
				local ndnode;

				for ndnode in commonlib.XPath.eachNode(waynode, "/nd") do
					for i=1, #osmNodeList do
						local item = osmNodeList[i];
						if (item.id == ndnode.attr.ref) then
							xpos, ypos = deg2pixel(item.lon, item.lat, 17);
							local str = item.id..","..item.lat..","..item.lon.." -> "..tostring(xpos)..","..tostring(ypos);
							LOG.std(nil, "info", "found building node:", str);

							osmBuilding = { x = xpos; y = ypos; z = 1}
							osmBuildingList[osmBuildingCount] = osmBuilding;
							osmBuildingCount = osmBuildingCount + 1;
						end
				    end
			    end

			    found = true;
			end
		end

	    if (found) then
	        break;
	    end
	end
	
	self:ResetDefaultContext();
	GameLogic.ActivateDefaultContext();

	NPL.load("(gl)script/apps/Aries/Creator/Game/Commands/CommandManager.lua");
	local CommandManager = commonlib.gettable("MyCompany.Aries.Game.CommandManager");

	--CommandManager:RunCommand("/home");
	CommandManager:RunCommand("/take 126");
	--CommandManager:RunCommand("/box 1 1 1");

	--Draw buildings
	for i=1, #osmBuildingList do
	    local building = osmBuildingList[i];
		--building.x = 19200 + building.x;
		--building.y = 19200 + building.y;
		--building.z = 128;
		local gostr = "/tp " .. tostring(building.x) .. " " .. tostring(building.z) .. " " .. tostring(building.y);
		LOG.std(nil, "info", "Command", gostr);

		local spawn_x, spawn_y, spawn_z = self:GetSpawnPosition();	
		local x, y, z = BlockEngine:real(spawn_x, spawn_y, spawn_z); 
		EntityManager.GetPlayer():SetBlockPos(x, y, z); 
		--EntityManager.GetPlayer():SetBlockPos(building.x, building.z, building.y);
		--CommandManager:RunCommand(gostr);

		local blockstr = "/box 1 1 1";
		LOG.std(nil, "info", "Command", blockstr);
		--CommandManager:RunCommand(blockstr);
	end

	LOG.std(nil, "info", "ParseOSM", "The end.");
end

function EarthSceneContext:mouseReleaseEvent(event)
	if (event:button() == "left") then
	
	self:LoadOsm();

	local z = 1
	if (z) then
		return;
	end

	NPL.load("(gl)script/apps/Aries/Creator/Game/blocks/BlockImage.lua");
	local block = commonlib.gettable("MyCompany.Aries.Game.blocks.BlockImage");

		--NPL.SyncFile("http://mt2.google.cn/vt/lyrs=y@258000000&hl=zh-CN&gl=CN&src=app&x=214130&y=114212&z=18&s=Ga", "google.jpg", "DownloadCallback()", "google");
	

		NPL.SyncFile("http://webrd03.is.autonavi.com/appmaptile?x=1629&y=849&z=11&lang=zh_cn&size=1&scale=1&style=7", 
			"gaode.htm", "DownloadCallback()", "gaode");
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

function num2deg(x, y, z)
    local n = 2 ^ z
    local lon_deg = x / n * 360.0 - 180.0
    local lat_rad = math.atan(math.sinh(math.pi * (1 - 2 * y / n)))
    local lat_deg = lat_rad * 180.0 / math.pi
    return lon_deg, lat_deg
end

function deg2num(lon, lat, zoom)
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



