#!/bin/bash

# some help from NCSC
# https://github.com/ukncsc/Device-Security-Guidance-Configuration-Packs/tree/main/Linux/UbuntuLTS

echo -e "${HIGHLIGHT}Running system updates...${NC}"

# Update.
apt-get update
# Upgrade.
apt-get dist-upgrade -y
# Remove packages.
apt-get remove -y popularity-contest
# And install required packages.
apt-get install -y apparmor-profiles apparmor-utils auditd 
apt-get install -y clamav clamav-daemon apt-utils

# Protect user home directories.
echo -e "${HIGHLIGHT}Configuring home directories and shell access...${NC}"
sed -ie '/^DIR_MODE=/ s/=[0-9]*\+/=0700/' /etc/adduser.conf
sed -ie '/^UMASK\s\+/ s/022/077/' /etc/login.defs

# Set some AppArmor profiles to enforce mode.
echo -e "${HIGHLIGHT}Configuring apparmor...${NC}"
aa-enforce /etc/apparmor.d/usr.sbin.avahi-daemon
aa-enforce /etc/apparmor.d/usr.sbin.dnsmasq
aa-enforce /etc/apparmor.d/bin.ping
aa-enforce /etc/apparmor.d/usr.sbin.rsyslogd

# Setup auditing.
echo -e "${HIGHLIGHT}Configuring system auditing...${NC}"
if [ ! -f /etc/audit/rules.d/tmp-monitor.rules ]; then
echo "# Monitor changes and executions within /tmp
-w /tmp/ -p wa -k tmp_write
-w /tmp/ -p x -k tmp_exec" > /etc/audit/rules.d/tmp-monitor.rules
fi

if [ ! -f /etc/audit/rules.d/admin-home-watch.rules ]; then
echo "# Monitor administrator access to /home directories
-a always,exit -F dir=/home/ -F uid=0 -C auid!=obj_uid -k admin_home_user" > /etc/audit/rules.d/admin-home-watch.rules
fi
augenrules


# disable location services
echo "
[org/gnome/system/location]
max-accuracy-level='country'
enabled=false" | sudo tee --append /etc/dconf/db/local.d/locks/00_custom-lock

echo "/org/gnome/system/location/max-accuracy-level
/org/gnome/system/location/enabled" | sudo tee --append /etc/dconf/db/local.d/locks/00_custom-lock

# Further Privacy Setting
echo "
[org/gnome/desktop/privacy]
report-technical-problems=false" | sudo tee --append /etc/dconf/db/local.d/locks/00_custom-lock
echo "/org/gnome/desktop/privacy/report-technical-problems"  | sudo tee --append /etc/dconf/db/local.d/locks/00_custom-lock

dconf update

# Disable apport (error reporting)
sed -ie '/^enabled=1$/ s/1/0/' /etc/default/apport

# Fix some permissions in /var that are writable and executable by the standard user.
echo -e "${HIGHLIGHT}Configuring additional directory permissions...${NC}"
chmod o-w /var/crash
chmod o-w /var/metrics
chmod o-w /var/tmp

