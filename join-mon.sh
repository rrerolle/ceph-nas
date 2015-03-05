#!/bin/sh

mon_ip=$1
mon_key=$2

[ -z "$mon_ip" ] && echo "Please specify initial monitor ip" && exit 1
[ -z "$mon_key" ] && echo "Please specify initial monitor key" && exit 1

ipaddr=$(ip -o -4 addr show eth0 | sed 's:^.*inet \([^/]*\).*$:\1:')
hostname=$(hostname)

cat << EOF > /etc/ceph/ceph.conf
[global]
	mon host = $mon_ip
EOF

cat << EOF > /etc/ceph/ceph.client.admin.keyring
[client.admin]
	key = $mon_key
	auid = 0
	caps mds = "allow"
	caps mon = "allow *"
	caps osd = "allow *"
EOF

fsid=$(ceph fsid)
cat << EOF >> /etc/ceph/ceph.conf
	fsid = $fsid
	public addr = $ipaddr
EOF

mkdir /var/lib/ceph/mon/ceph-$hostname
ceph auth get mon. -o /tmp/mon.keyring
ceph mon getmap -o /tmp/mon.map
ceph-mon -i $hostname --mkfs --monmap /tmp/mon.map --keyring /tmp/mon.keyring
touch /var/lib/ceph/mon/ceph-$hostname/done
touch /var/lib/ceph/mon/ceph-$hostname/sysvinit
service ceph start mon.$hostname
ceph mon add $hostname $ipaddr
