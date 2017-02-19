--[[
Title: DownloadService
Author(s):  big
Date:  2017.2.19
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/EarthMod/DownloadService.lua");
local DownloadService = commonlib.gettable("Mod.EarthMod.DownloadService");
------------------------------------------------------------
]]
NPL.load("(gl)script/ide/System/Encoding/base64.lua");

local DownloadService  = commonlib.gettable("Mod.EarthMod.DownloadService");
local Encoding         = commonlib.gettable("System.Encoding");

DownloadService.osmHost   = "osm.org";
DownloadService.osmXMLUrl = "http://api."  .. self.osmHost .. "/api/0.6/map?bbox={{left}},{{bottom}},{{right}},{{top}}";
DownloadService.osmPNGUrl = "http://tile." .. self.osmHost .. "/{{zoom}}/{{x}}/{{y}}.png";
DownloadService.tryTimes  = 0;

function DownloadService:ctor()
end

function DownloadService:init()
end

function DownloadService:GetUrl(_params,_callback)
	System.os.GetUrl(_params,function(err, msg, data)
		self:retry(err, msg, data, _params, _callback);
	end);
end

function DownloadService:retry(_err, _msg, _data, _params, _callback)
	LOG.std(nil,"debug","DownloadService:retry",{_err});

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

function DownloadService:getOsmXMLData()

end

function DownloadService:getOsmPNGData()

end