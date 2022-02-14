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
apt-get install -y clamav clamav-daemon ufw 

# Update fstab.
echo -e "${HIGHLIGHT}Writing fstab config...${NC}"
sed -ie '/\s\/home\s/ s/defaults/defaults,noexec,nosuid,nodev/' /etc/fstab
EXISTS=$(grep "/tmp/" /etc/fstab)
if [ -z "$EXISTS" ]; then
	echo "none /tmp tmpfs rw,noexec,nosuid,nodev 0 0" >> /etc/fstab
else
	sed -ie '/\s\/tmp\s/ s/defaults/defaults,noexec,nosuid,nodev/' /etc/fstab
fi
echo "none /run/shm tmpfs rw,noexec,nosuid,nodev 0 0" >> /etc/fstab
# Bind /var/tmp to /tmp to apply the same mount options during system boot
echo "/tmp /var/tmp none bind 0 0" >> /etc/fstab
# Temporarily make the /tmp directory executable before running apt-get and remove execution flag afterwards. This is because
# sometimes apt writes files into /tmp and executes them from there.
echo -e "DPkg::Pre-Invoke{\"mount -o remount,exec /tmp\";};\nDPkg::Post-Invoke {\"mount -o remount /tmp\";};" >> /etc/apt/apt.conf.d/99tmpexec
chmod 644 /etc/apt/apt.conf.d/99tmpexec

echo -e "${HIGHLIGHT}Configuring automatic updates...${NC}"
EXISTS=$(grep "APT::Periodic::Update-Package-Lists" /etc/apt/apt.conf.d/20auto-upgrades)
if [ -z "$EXISTS" ]; then
	sed '/APT::Periodic::Update-Package-Lists/d' /etc/apt/apt.conf.d/20auto-upgrades
	echo "APT::Periodic::Update-Package-Lists \"1\";" >> /etc/apt/apt.conf.d/20auto-upgrades
fi

EXISTS=$(grep "APT::Periodic::Unattended-Upgrade" /etc/apt/apt.conf.d/20auto-upgrades)
if [ -z "$EXISTS" ]; then
	sed '/APT::Periodic::Unattended-Upgrade/d' /etc/apt/apt.conf.d/20auto-upgrades
	echo "APT::Periodic::Unattended-Upgrade \"1\";" >> /etc/apt/apt.conf.d/20auto-upgrades
fi

EXISTS=$(grep "APT::Periodic::AutocleanInterval" /etc/apt/apt.conf.d/10periodic)
if [ -z "$EXISTS" ]; then
	sed '/APT::Periodic::AutocleanInterval/d' /etc/apt/apt.conf.d/10periodic
	echo "APT::Periodic::AutocleanInterval \"7\";" >> /etc/apt/apt.conf.d/10periodic
fi

chmod 644 /etc/apt/apt.conf.d/20auto-upgrades
chmod 644 /etc/apt/apt.conf.d/10periodic

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
enabled=false" >> /etc/dconf/db/local.d/00_custom-lock

echo "/org/gnome/system/location/max-accuracy-level
/org/gnome/system/location/enabled" >> /etc/dconf/db/local.d/locks/00_custom-lock

# Further Privacy Setting
echo "
[org/gnome/desktop/privacy]
report-technical-problems=false" >> /etc/dconf/db/local.d/00_custom-lock
echo "/org/gnome/desktop/privacy/report-technical-problems" >> /etc/dconf/db/local.d/locks/00_custom-lock

dconf update

# Disable apport (error reporting)
sed -ie '/^enabled=1$/ s/1/0/' /etc/default/apport

# Fix some permissions in /var that are writable and executable by the standard user.
echo -e "${HIGHLIGHT}Configuring additional directory permissions...${NC}"
chmod o-w /var/crash
chmod o-w /var/metrics
chmod o-w /var/tmp

# Setting up firewall without any rules.
echo -e "${HIGHLIGHT}Configuring firewall…  ${NC}"
ufw enable	


echo -e "${HIGHLIGHT}Installation complete.${NC}"