#!/bin/sh

set -e

ip_mon=$1
mon_admin_key=$2

log_and_die()
{
	printf "$@\n" >&2
	exit 1
}

[ -n "$ip_mon" ] || log_and_die "Missing IP mon parameter"
[ -n "$mon_admin_key" ] || log_and_die "Missing admin/mon key parameter"

cat << EOF >/etc/ceph/ceph.conf
[global]
	mon host = $ip_mon
EOF

cat << EOF > /etc/ceph/ceph.client.admin.keyring
[client.admin]
	key = $mon_admin_key
	auid = 0
	caps mds = "allow"
	caps mon = "allow *"
	caps osd = "allow *"
EOF

fsid=$(ceph fsid)
cat << EOF >> /etc/ceph/ceph.conf
	fsid = $fsid
EOF

osd_num=$(ceph osd create)
[ -n "$osd_num" ] || log_and_die "Failed to retrieve OSD number"

cluster_name=ceph

mkdir -p /var/lib/ceph/osd/$cluster_name-$osd_num

ceph-osd -i $osd_num --mkfs --mkkey
ceph auth add osd.$osd_num osd 'allow *' mon 'allow profile osd' -i
/var/lib/ceph/osd/$cluster_name-$osd_num/keyring
ceph osd crush add-bucket $(hostname) host
ceph osd crush move $(hostname) root=default
ceph osd crush add osd.$osd_num 1.0 host=$(hostname)
touch /var/lib/ceph/osd/$cluster_name-$osd_num/done
touch /var/lib/ceph/osd/$cluster_name-$osd_num/sysvinit
/etc/init.d/ceph start osd.$osd_num
