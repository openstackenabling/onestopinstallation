#!/usr/bin/env bash
#
#    Copyright (C) 2013 Intel Corporation.  All rights reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.
set -o xtrace
source $STACK_DIR/localrc
source $STACK_DIR/utils/functions

apt-get install -y --force-yes vlan
#enable 8021q
modprobe 8021q

add_config "8021q" "/etc/modules"

apt-get install -y --force-yes bridge-utils nova-network nova-compute nova-api-metadata

#Fix the error:
#open /dev/kvm: Permission denied
#Could not initialize KVM, will disable KVM support
sed -i "s/#user = \"root\"/user = \"root\"/g" /etc/libvirt/qemu.conf
sed -i "s/#group = \"root\"/group = \"root\"/g" /etc/libvirt/qemu.conf
service libvirt-bin restart

#The whole nova.conf
cat <<EOF > /etc/nova/nova.conf
[DEFAULT]
# LOGS/STATE
verbose=True
logdir=/var/log/nova
state_path=/var/lib/nova
lock_path=/run/lock/nova

# AUTHENTICATION
auth_strategy=keystone

# SCHEDULER
scheduler_driver=nova.scheduler.multi.MultiScheduler
compute_scheduler_driver=nova.scheduler.filter_scheduler.FilterScheduler

# CINDER
volume_api_class=nova.volume.cinder.API

# DATABASE
sql_connection=mysql://$NOVA_DB_USER:$NOVA_DB_PASSWD@$MYSQL_HOST/nova

# COMPUTE
libvirt_type=kvm
libvirt_use_virtio_for_bridges=True
start_guests_on_host_boot=True
resume_guests_state_on_host_boot=True
api_paste_config=/etc/nova/api-paste.ini
allow_admin_api=True
use_deprecated_auth=False
nova_url=http://$CONTROLLER_MANAGEMENT_IP:8774/v1.1/
root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf
connection_type=libvirt

# APIS
ec2_host=$CONTROLLER_MANAGEMENT_IP
ec2_url=http://$CONTROLLER_MANAGEMENT_IP:8773/services/Cloud
keystone_ec2_url=http://$CONTROLLER_MANAGEMENT_IP:5000/v2.0/ec2tokens
s3_host=$CONTROLLER_MANAGEMENT_IP
cc_host=$CONTROLLER_MANAGEMENT_IP
metadata_host=$COMPUTE_MANAGEMENT_IP
dmz_cidr=$COMPUTE_MANAGEMENT_IP
my_ip=$COMPUTE_MANAGEMENT_IP


# RABBITMQ
rabbit_host=$CONTROLLER_MANAGEMENT_IP

# GLANCE
image_service=nova.image.glance.GlanceImageService
glance_api_servers=$CONTROLLER_MANAGEMENT_IP:9292

# NETWORK
network_manager=nova.network.manager.VlanManager
public_interface=$COMPUTE_MANAGEMENT_ETH
vlan_interface=$COMPUTE_VM_ETH
network_host=$COMPUTE_MANAGEMENT_IP
#The fixed_range option is a CIDR block which describes the IP address space for all of the instances:
#this space will be divided up into subnets. This range is typically a private network.
#The example above uses the private range 172.16.0.0/12.
fixed_range=$FIXIP_RANGE
#The network_size option refers to the default number of IP addresses in each network,
#although this can be overriden at network creation time .
#The example above uses a network size of 256, whicih corresponds to a /24 network.
network_size=$NETWORK_SIZE
dhcpbridge_flagfile=/etc/nova/nova.conf
dhcpbridge=/usr/bin/nova-dhcpbridge
force_dhcp_release=True
fixed_ip_disassociate_timeout=30
multi_host=True

## cloud-pipe vpn client ##
vpn_image_id=$VPN_IMAGE_ID
use_project_ca=True
cnt_vpn_clients=5


# NOVNC CONSOLE
novnc_enabled=True
novncproxy_base_url=http://$CONTROLLER_MANAGEMENT_IP:6080/vnc_auto.html

# Change vncserver_proxyclient_address and vncserver_listen to match each compute host
vncserver_proxyclient_address=$COMPUTE_MANAGEMENT_IP
vncserver_listen=0.0.0.0
EOF

sed -i "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g" /etc/sysctl.conf
sysctl -w net.ipv4.ip_forward=1

iptables -A POSTROUTING -t mangle -p udp --dport 68 -j CHECKSUM --checksum-fill

service nova-compute restart
service nova-network restart
service nova-api-meta restart
