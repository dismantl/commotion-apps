m = Map("applications", translate("Commotion Applications"), translate("Applications used in the Commotion bundle. Only applications manually created on this node with TTL values of zero can be modified from this page."))

s = m:section(TypedSection, "application", translate("Applications"))
function s.filter(self, section)
	if luci.http.formvalue("app") then
		return self.map:get(section, "uuid") == luci.http.formvalue("app") and not self.map:get(section, "signature") and self.map:get(section, "ttl") == '0'
	end
	return not self.map:get(section, "signature")
end

name = s:option(Value, "name", "App Name"); name.optional=false; name.rmempty=false;
ipaddr = s:option(Value, "ipaddr", "IP Address or URL"); ipaddr.optional=false; ipaddr.rmempty=false;
port = s:option(Value, "port", "Port"); port.optional=true; port.rmempty = true;
icon = s:option(Value, "icon", "Icon"); icon.optional=false; icon.rmemtpy=false;
desc = s:option(TextValue, "description", "Description"); desc.optional=false; desc.rmempty=false;
type = s:option(DynamicList, "type", "Type"); type.default = misc;
approved = s:option(ListValue, "approved", "Approved"); approved.optional=false; approved.rmempty=true; approved:value("",""); approved:value("1","approved"); approved:value("0","blacklisted");

return m
