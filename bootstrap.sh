#!/bin/sh

fsid=$(uuidgen)
ipaddr=$(ip -o -4 addr show eth0 | sed 's:^.*inet \([^/]*\).*$:\1:')
hostname=$(hostname)

cat << EOF > /etc/ceph/ceph.conf
[global]
        fsid = $fsid
        mon host = $ipaddr
        auth cluster required = cephx
        auth service required = cephx
        auth client required = cephx
        osd journal size = 1024
        filestore xattr use omap = true
        osd pool default size = 2
        osd pool default min size = 1
        osd pool default pg num = 333
        osd pool default pgp num = 333
EOF

ceph-authtool --create-keyring /tmp/ceph.mon.keyring --gen-key -n mon. --cap mon 'allow *'

monmaptool --create --add $hostname $ipaddr --fsid $fsid /tmp/monmap

mkdir /var/lib/ceph/mon/ceph-$hostname
ceph-mon --mkfs -i $hostname --monmap /tmp/monmap --keyring /tmp/ceph.mon.keyring

touch /var/lib/ceph/mon/ceph-$hostname/done
touch /var/lib/ceph/mon/ceph-$hostname/sysvinit
/etc/init.d/ceph start mon.$hostname

echo "[client.admin]" > /tmp/ceph.admin.keyring
grep "key = " /tmp/ceph.mon.keyring >> /tmp/ceph.admin.keyring
ceph auth import -i /tmp/ceph.admin.keyring
mv /tmp/ceph.admin.keyring /etc/ceph/ceph.client.admin.keyring

mkdir /home/osd
ceph-disk prepare --cluster ceph --cluster-uuid $fsid --fs-type ext4 /home/osd
ceph-disk activate /home/osd


