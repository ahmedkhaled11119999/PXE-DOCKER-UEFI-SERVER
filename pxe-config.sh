#!/bin/bash

touch /ks/meta-data
#--------------replace ENV with values---------------
default_pxe_settings=/srv/tftp/pxelinux.cfg/default.tmp
if [ -f "$default_pxe_settings" ]; then
    envsubst < /srv/tftp/pxelinux.cfg/default.tmp > /srv/tftp/pxelinux.cfg/default
	envsubst < /etc/dhcp/dhcpd.conf.tmp > /etc/dhcp/dhcpd.conf
	envsubst < /etc/apache2/sites-available/ks-server.conf.tmp > /etc/apache2/sites-available/ks-server.conf
	rm /srv/tftp/pxelinux.cfg/default.tmp /etc/dhcp/dhcpd.conf.tmp /etc/apache2/sites-available/ks-server.conf.tmp 
fi
#---------------apache configurations------------------
service apache2 start
a2ensite ks-server.conf
service apache2 reload
#---------------tftp configurations------------------
cat > /etc/default/tftpd-hpa <<EOF
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/srv/tftp"
TFTP_ADDRESS=":69"
TFTP_OPTIONS="--secure"
EOF
service tftpd-hpa restart
#---------------dhcp configurations------------------
re='^[0-9]+$'
pid=$(cat /var/run/dhcpd.pid)
if ! [[ $pid =~ $re ]] ; then
cat > /etc/default/isc-dhcp-server <<EOF
INTERFACESv4="eth0"
INTERFACESv6=""
EOF
service isc-dhcp-server restart
fi