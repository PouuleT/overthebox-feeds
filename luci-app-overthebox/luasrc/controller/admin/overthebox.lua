-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2011 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.

module("luci.controller.admin.overthebox", package.seeall)

function index()
	entry({"admin", "overthebox"}, firstchild(), _("OverTheBox"), 19).index = true

	local e = entry({"admin", "overthebox", "overview"}, template("overthebox/index"), _("Overview"), 1)
	e.sysauth = false

	local e = entry({"admin", "overthebox", "multipath"}, template("overthebox/multipath"), _("Realtime graphs"), 2)
	e.leaf = true
	e.sysauth = false

	local e = entry({"admin", "overthebox", "bandwidth_status"}, call("action_bandwidth_data"))
	e.sysauth = false

	local e = entry({"admin", "overthebox", "interfaces_status"}, call("interfaces_status"))
	e.sysauth = false

	--
        local e = entry({"admin", "overthebox", "dhcp", "overview"},  call("dhcpdiscovert_status"))
        e.sysauth = false

        entry({"admin", "overthebox", "dhcp", "recheck"},  call("action_recheck"))

        entry({"admin", "overthebox", "dhcp", "skiptimer"},  call("action_skiptimer"))

        entry({"admin", "overthebox", "startdhcpserver"},  call("action_startdhcpserver"))

        entry({"admin", "overthebox", "confmwan"},  call("action_confmwan"))

end

-- Multipath overview functions
function interfaces_status()
        return require("luci.controller.mwan3").interfaceStatus()
end

function action_bandwidth_data(dev)
	if dev ~= "all" then
		return require('luci.controller.admin.status').action_bandwidth(dev)
	else
		return multipath_bandwidth()
	end
end

function multipath_bandwidth()
	local result = { };
	local uci = luci.model.uci.cursor()

	for _, dev in luci.util.vspairs(luci.sys.net.devices()) do
		if dev ~= "lo" then
                	if uci:get("network", dev, "multipath") == "on" then
				result[dev] = "[" .. string.gsub((luci.sys.exec("luci-bwc -i %q 2>/dev/null" % dev)), '[\r\n]', '') .. "]"
			end
		end
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json(result)
end

-- DHCP overview functions
function getDhcpd()
        local result = {}
        local dhcpd = (sys.exec("cat /var/etc/dnsmasq.conf | grep dhcp-range | cut -c12- | cut -f1 -d','"))
        for line in string.gmatch(dhcpd,'[^\r\n]+') do
                result[line] = true
        end
        return result
end

function dhcpdiscovert_status()
        local uci = luci.model.uci.cursor()
        local result = {}

        result.dhcpservers = {}
        result.mwan3 = {}
        result.user = {}

        uci:foreach("dhcpdiscovery", "lease",
                function (section)
                        result.dhcpservers[section[".name"]] = section
                end
        )

        local dhcpd = getDhcpd()
        uci:foreach("dhcp", "dhcp",
                function (section)
                        if dhcpd[section[".name"]] then
                                result.dhcpservers[section[".name"]] = section
                                result.dhcpservers[section[".name"]].ipaddr = uci:get("network", section[".name"], "ipaddr")
                        end
                end
        )

        local oldchecksum = uci:get("mwan3", "netconfchecksum")
        if oldchecksum then
                local newchecksum = (sys.exec("uci -q export network | md5sum | cut -f1 -d' '"))
                newchecksum = string.sub(newchecksum, 1, 32)
                oldchecksum = string.sub(oldchecksum, 1, 32)
                result.mwan3["new_netconfchecksum"] = newchecksum
                result.mwan3["old_netconfchecksum"] = oldchecksum

                if oldchecksum == newchecksum then
                        result.mwan3["status"] = "uptodate"
                else
                        result.mwan3["status"] = "outofdate"
                end
        end

        result.user["remote_addr"] = luci.http.getenv("REMOTE_ADDR") or ""
        result.user["isFromDhcpLease"] = "false"

        local leases=tools.dhcp_leases()
        for _, value in pairs(leases) do
                if value["ipaddr"] == result.user["remote_addr"] then
                        result.user["isFromDhcpLease"] = "true"
                end
        end
        luci.http.prepare_content("application/json")
        luci.http.write_json(result)
end

function action_recheck()
	sys.exec("uci set dhcpdiscovery.if0.lastcheck=`date +%s`")
	sys.exec("uci delete dhcpdiscovery.if0.siaddr")
	sys.exec("uci delete dhcpdiscovery.if0.serverid")
	-- workaround for time jump at first startup
	local uci = luci.model.uci.cursor()
	local timestamp = uci:get("dhcpdiscovery", "if0", "timestamp")
	local lastcheck = uci:get("dhcpdiscovery", "if0", "lastcheck")
	if tonumber(timestamp) > tonumber(lastcheck) then
		sys.exec("uci set dhcpdiscovery.if0.timestamp=" .. lastcheck)
	end

	sys.exec("uci commit")
	sys.exec("pkill -USR1 udhcpc")

	luci.http.prepare_content("application/json")
	luci.http.write_json("OK")
end

function action_skiptimer()
	sys.exec("uci delete dhcpdiscovery.if0.timestamp")
	sys.exec("pkill -USR1 \"dhcpc -p /var/run/udhcpc-if0.pid\"")

	luci.http.prepare_content("application/json")
	luci.http.write_json("OK")
end

function action_startdhcpserver()
        local result = require('overthebox').create_dhcp_server()
	luci.http.prepare_content("application/json")
	luci.http.write_json(result)
end

function update_confmwan()
        local result = require('overthebox').update_confmwan()
        luci.http.prepare_content("application/json")
        luci.http.write_json(result)
end
