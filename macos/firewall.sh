################################################################################
# Firewall                                                                     #
################################################################################

# Enable the firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

# Enable logging on the firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on

# Enable stealth mode
# (computer does not respond to PING or TCP connections on closed ports)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on

# Prevent built-in software as well as code-signed, downloaded software from
# being whitelisted automatically
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned off
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp off

# Restart the firewall (this should remain last)
sudo pkill -HUP socketfilterfw
