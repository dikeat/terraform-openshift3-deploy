#!/bin/sh
echo "Execute the pre-install steps"
subscription-manager repos --enable="rhel-7-server-rpms"  --enable="rhel-7-server-extras-rpms"  --enable="rhel-7-server-ose-3.10-rpms" --enable="rhel-7-server-ansible-2.4-rpms" --enable="rhel-7-server-optional-rpms"
rm -fr /var/cache/yum/*
yum clean all
yum -y update
yum install -y wget vim-enhanced net-tools bind-utils tmux git iptables-services bridge-utils docker etcd rpcbind

sed -i -e 's/NM_CONTROLLED=.*/NM_CONTROLLED=yes/' /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e 's/NM_CONTROLLED=.*/NM_CONTROLLED=yes/' /etc/sysconfig/network-scripts/ifcfg-eth1
systemctl enable NetworkManager
systemctl start NetworkManager
systemctl start dnsmasq
systemctl enable dnsmasq
