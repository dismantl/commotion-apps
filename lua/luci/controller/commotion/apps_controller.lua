--[[

appSplash - LuCI based Application Front end.
Copyright (C) <2012>  <Seamus Tuohy>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]--

module("luci.controller.commotion.apps_controller", package.seeall)

require "luci.model.uci"
require "luci.http"
require "luci.sys"
require "commotion_helpers"
function index()
    entry({"apps"}, call("load_apps"), "Local Applications", 20).dependent=false
    entry({"admin","commotion","apps"}, call("admin_load_apps"), "Local Applications", 50).dependent=false
    entry({"admin", "commotion", "apps", "list"}, cbi("commotion/apps_cbi")).dependent=true
    entry({"apps", "add"}, template("commotion/apps_add")).dependent=false
    entry({"apps", "add_submit"}).target = call("action_add")
    entry({"admin", "commotion", "apps", "blacklist"}, call("blacklist_app")).dependent=true
    entry({"admin", "commotion", "apps", "approve"}, call("approve_app")).dependent=true
end

function blacklist_app()
  local uci = luci.model.uci.cursor()
  local name = luci.http.formvalue("name")
  if (uci:set("applications", name, "approved", "0") and uci:save('applications') and uci:commit('applications')) then
  	luci.http.status(200, "OK")
  else
  	luci.http.status(500, "Internal Server Error")
  end
end

function approve_app()                                                                                                                                                
  local uci = luci.model.uci.cursor()                                                                                                                                   
  local name = luci.http.formvalue("name")                                                                                                                              
  if (uci:set("applications", name, "approved", "1") and uci:save('applications') and  uci:commit('applications')) then
  	luci.http.status(200, "OK")
  else 
  	luci.http.status(500, "Internal Server Error")
  end
end      

function admin_load_apps()
	load_apps({true})
end

function load_apps(admin_vars)

local name, nick, ip, port, apps, app,  description, i, r
local uci = luci.model.uci.cursor()
local categories = {}
local apps = {}
uci:foreach("applications", "application",
   function(s)
       if s.name then
	   if admin_vars then
	       table.insert(apps,s)
	   else
	       if s.approved and s.approved == '1' then
	           table.insert(apps,s)
	       end
	   end
       end 
   end)
   
for _, r in pairs(apps) do
	 if r.type then
	  	 for _, t in pairs(r.type) do
		  	if categories[t] then
                		appName = r.name
				categories[t][appName] = r
			else
		 		categories[t] = {}
				appName = r.name
				categories[t][appName] = r
			end
		end
	 else appName = r.name
	 	  if categories['misc'] then
		  	 categories['misc'][appName] = r
		  else
			categories['misc'] = {}
			categories['misc'][appName] = r
		  end
	 end
end
	 luci.template.render("commotion/apps_view", {categories=categories, admin_vars=admin_vars})
end


function action_add()
	
	local UUID, values, tmpl, type_tmpl, service_type, app_types, reverse_app_types, service_string, service_file, signing_tmpl, signing_msg, resp, signature, fingerprint
	local uci = luci.model.uci.cursor()

	values = {
		  name =  luci.http.formvalue("appName"),
		  ipaddr =  luci.http.formvalue("IP"),
		  port = luci.http.formvalue("port"),
		  icon =  luci.http.formvalue("icon"),
		  nick =  luci.http.formvalue("appNick"),
		  description =  luci.http.formvalue("desc"),
		  ttl = luci.http.formvalue("ttl"),
		  transport = luci.http.formvalue("transport"),
		  protocol = 'IPv4',
		  localapp = '1' -- all manually created apps get a 'localapp' flag
	}
	
	if (not is_port(values.port) or not is_uint(values.ttl)) then
		  DIE("Invalid input values")
		  return
	end
	
	-- escape input strings
        for i, field in pairs(values) do
		if (i ~= 'ipaddr' and i ~= 'icon') then
	                values[i] = html_encode(field)
		else
			values[i] = url_encode(field)
		end
        end
	
	UUID = uci_encode(values.ipaddr .. values.port)
	values.uuid = UUID
	
	uci:foreach("applications", "application", 
		function(app)
			if (UUID == app.uuid) then
				match = true
			end
		end)
		
	if (match) then
		DIE("echo This app already exists")
		return
	end

	-- IF USER INPUTS URL INTO luci.http.formvalue("IP") FIELD, NEED TO BE ABLE TO RESOLVE TO IP ADDRESS BEFORE ADDING APPLICATION
	if (not is_ip4addr(luci.http.formvalue("IP"))) then
		local url = string.gsub(luci.http.formvalue("IP"), 'http://', '', 1)
		url = url:gsub('https://', '', 1)
		url = url:match("^[^/]+") -- remove anything after the domain name
		 -- url = url:match("[%a%d-]+\.%w+$") -- remove subdomains (** actually we should probably keep subdomains **)
		local resolve = luci.sys.exec("nslookup " .. url .. "; echo $?")
		if (resolve:sub(-2,-2) ~= '0') then	-- exit status != 0 -> failed to resolve url
			DIE("echo Failed to resolve given URL: " .. url)
			return
		end
	end

	-- If TTL > 0, create avahi service file
	if (tonumber(luci.http.formvalue("ttl")) > 0) then
			
		type_tmpl = '<txt-record>type=${app_type}</txt-record>'
		signing_tmpl = [[<type>_${type}._${proto}</type>
<domain-name>mesh.local</domain-name>
<port>${port}</port>
<txt-record>application=${name}</txt-record>
<txt-record>nick=${nick}</txt-record>
<txt-record>ttl=${ttl}</txt-record>
<txt-record>ipaddr=${ipaddr}</txt-record>
${app_types}
<txt-record>icon=${icon}</txt-record>
<txt-record>description=${desc}</txt-record>]]
		tmpl = [[
<?xml version="1.0" standalone='no'?><!--*-nxml-*-->
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">

<!-- This file is part of commotion -->
<!-- Reference: http://en.gentoo-wiki.com/wiki/Avahi#Custom_Services -->
<!-- Reference: http://wiki.xbmc.org/index.php?title=Avahi_Zeroconf -->

<service-group>
<name replace-wildcards="yes">${uuid} on %h</name>

<service>
]] .. signing_tmpl .. [[

<txt-record>signature=${signature}</txt-record>
<txt-record>fingerprint=${fingerprint}</txt-record>
</service>
</service-group>
]]

		-- FILL IN ${TYPE} BY LOOKING UP PORT IN /ETC/SERVICES, DEFAULT TO 'commotion'
		if (values.transport == '') then                                      
			values.transport = 'tcp'                                                       
		end
		if (values.port ~= '') then
			local command = "grep " .. values.port .. "/" .. values.transport .. " /etc/services |awk '{ printf(\"%s\", $1) }'"
			service_type = luci.sys.exec(command)
			if (service_type == '') then
				service_type = 'commotion'
			end
		else
			service_type = 'commotion'
		end
			
		-- CREATE <txt-record>type=???</txt-record> FOR EACH APPLICATION TYPE
		app_types = ''
		reverse_app_types = ''
		if (type(luci.http.formvalue("types")) == "table") then
			for i, app_type in pairs(luci.http.formvalue("types")) do
				app_types = app_types .. printf(type_tmpl, {app_type = app_type})
			end
			for i = #luci.http.formvalue("types"), 1, -1 do
				reverse_app_types = reverse_app_types .. printf(type_tmpl, {app_type = luci.http.formvalue("types")[i]})
			end
		else
			app_types = printf(type_tmpl, {app_type = luci.http.formvalue("types")})
		end

		local fields = {
		  uuid = UUID,
		  name = values.name,
		  type = service_type,
		  ipaddr = values.ipaddr,
		  port = values.port,
		  icon = values.icon,
		  nick = values.nick,
		  desc = values.description,
		  ttl = values.ttl,
		  proto = values.transport or 'tcp',
		  app_types = app_types
		}
		
		-- create fingerprint/signature
		signing_msg = printf(signing_tmpl,fields)
		resp = luci.sys.exec("echo \"" .. signing_msg .. "\" |serval-sign")
		if (luci.sys.exec("echo $?") ~= '0\n') then
		  DIE("echo Failed to sign service advertisement")
		  return
		end
		
		_,_,fields.signature,fields.fingerprint = resp:find('([A-F0-9]+)\r?\n?([A-F0-9]+)')
		UUID = fields.fingerprint
		values.fingerprint = fields.fingerprint
		values.signature = fields.signature
		
		fields.app_types = reverse_app_types -- include service types in reverse order since avahi-client parses txt-records in reverse order
		                                                   
		service_string = printf(tmpl,fields)
		                                                   
		-- create service file, then restart avahi-daemon
		service_file = io.open("/etc/avahi/services/" .. UUID .. ".service", "w")
		if (service_file) then
		  service_file:write(service_string)
		  service_file:flush()
		  service_file:close()
		  luci.sys.call("/etc/init.d/avahi-daemon restart")
		else
		  DIE("echo Failed to create avahi service file")
		  return
		end			
		
	end -- if (luci.http.formvalue("ttl") > 0)
	    
	uci:section('applications', 'application', UUID, values)
	
	if (luci.http.formvalue("types") ~= nil) then
	    uci:set_list('applications', UUID, "type", luci.http.formvalue("types"))
	end
		
	uci:save('applications')
	uci:commit('applications')
		
	luci.http.redirect("/cgi-bin/luci/apps")

end -- action_add()