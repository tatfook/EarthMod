--[[
Title: getOsmService
Author(s):  big
Date:  2017.2.19
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/getOsmService.lua");
local getOsmService = commonlib.gettable("Mod.EarthMod.getOsmService");
------------------------------------------------------------
]]
NPL.load("(gl)script/ide/System/Encoding/base64.lua");
NPL.load("(gl)script/ide/Encoding.lua");
NPL.load("(gl)script/ide/Files.lua");

local getOsmService = commonlib.gettable("Mod.EarthMod.getOsmService");
local Encoding      = commonlib.gettable("System.Encoding");

getOsmService.osmHost   = "openstreetmap.org";
getOsmService.osmXMLUrl = "http://api."  .. getOsmService.osmHost .. "/api/0.6/map?bbox={left},{bottom},{right},{top}";
getOsmService.osmPNGUrl = "http://tile." .. getOsmService.osmHost .. "/" .. getOsmService.zoom .. "/{x}/{y}.png";
getOsmService.tryTimes  = 0;

function getOsmService:ctor()
end

function getOsmService:init()
end

function getOsmService:GetUrl(_params,_callback)
	System.os.GetUrl(_params,function(err, msg, data)
		self:retry(err, msg, data, _params, _callback);
	end);
end

function getOsmService:retry(_err, _msg, _data, _params, _callback)
	--失败时可直接返回的代码
	if(_err == 422 or _err == 404 or _err == 409) then
		_callback(_data,_err);
		return;
	end

	if(self.tryTimes >= 3) then
		_callback(_data,_err);
		self.tryTimes = 0;
		return;
	end

	if(_err == 200 or _err == 201 or _err == 204 and _data ~= "") then
		_callback(_data,_err);
		self.tryTimes = 0;
	else
		self.tryTimes = self.tryTimes + 1;
		
		commonlib.TimerManager.SetTimeout(function()
			self:GetUrl(_params, _callback); -- 如果获取失败则递归获取数据
		end, 2100);
	end
end

function getOsmService:getOsmXMLData(_callback)
	self.osmXMLUrl = self.osmXMLUrl:gsub("{left}",self.dleft);
	self.osmXMLUrl = self.osmXMLUrl:gsub("{bottom}",self.dbottom);
	self.osmXMLUrl = self.osmXMLUrl:gsub("{right}",self.dright);
	self.osmXMLUrl = self.osmXMLUrl:gsub("{top}",self.dtop);

	LOG.std(nil,"debug","osmXMLUrl",self.osmXMLUrl);

	self:GetUrl(self.osmXMLUrl,function(data,err)
		if(err == 200) then
			local file = ParaIO.open("/xml.osm", "w");
			file:write(data,#data);
			file:close();

			_callback(data);
		else
			return nil;
		end
	end);
end

function getOsmService:getOsmPNGData(_callback)
	self.osmPNGUrl = self.osmPNGUrl:gsub("{x}",tostring(self.tileX));
	self.osmPNGUrl = self.osmPNGUrl:gsub("{y}",tostring(self.tileY));

	self:GetUrl(self.osmPNGUrl,function(data,err)
		if(err == 200) then
			local file = ParaIO.open("/tile.png", "w");
			file:write(data,#data);
			file:close();

			_callback(data);
		else
			return nil;
		end
	end);
end