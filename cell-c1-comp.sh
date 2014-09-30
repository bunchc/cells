source /vagrant/common.sh

# Cell C2 Compute Build
export CONTROLLER_HOST=172.16.0.102
export API_CONTROLLER=172.16.0.101

export GLANCE_HOST=${API_CONTROLLER}
export MYSQL_HOST=${CONTROLLER_HOST}
export KEYSTONE_ENDPOINT=${CONTROLLER_HOST}
export MYSQL_NEUTRON_PASS=openstack
export SERVICE_TENANT_NAME=service
export SERVICE_PASS=openstack
export ENDPOINT=${KEYSTONE_ENDPOINT}
export SERVICE_TOKEN=ADMIN
export SERVICE_ENDPOINT=http://${ENDPOINT}:35357/v2.0
export MONGO_KEY=MongoFoo

ETH3_IP=$(ifconfig eth3 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')

# Must define your environment
MYSQL_HOST=${CONTROLLER_HOST}
GLANCE_HOST=${CONTROLLER_HOST}

SERVICE_TENANT=service
NOVA_SERVICE_USER=nova
NOVA_SERVICE_PASS=nova

nova_compute_install() {

	# Install some packages:
	sudo apt-get -y install ntp nova-api-metadata nova-compute nova-compute-qemu nova-doc novnc nova-novncproxy nova-consoleauth
	sudo apt-get -y install neutron-common neutron-plugin-ml2 neutron-plugin-openvswitch-agent
	sudo apt-get -y install vlan bridge-utils
	sudo apt-get -y install libvirt-bin pm-utils sysfsutils
	sudo service ntp restart
}

nova_configure() {

# Networking 
# ip forwarding
echo "net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0" | tee -a /etc/sysctl.conf
sysctl -p

# restart libvirt
sudo service libvirt-bin restart

# OpenVSwitch
sudo apt-get install -y linux-headers-`uname -r` build-essential
sudo apt-get install -y openvswitch-switch 

# Edit the /etc/network/interfaces file for eth2?
sudo ifconfig eth2 0.0.0.0 up
sudo ip link set eth2 promisc on

# OpenVSwitch Configuration
#br-int will be used for VM integration
sudo ovs-vsctl add-br br-int

sudo ovs-vsctl add-br br-ex
sudo ovs-vsctl add-port br-ex eth3

# Edit the /etc/network/interfaces file for eth3?
sudo ifconfig eth3 0.0.0.0 up
sudo ip link set eth3 promisc on
# Assign IP to br-ex so it is accessible
sudo ifconfig br-ex $ETH3_IP netmask 255.255.255.0

# Config Files
NEUTRON_CONF=/etc/neutron/neutron.conf
NEUTRON_PLUGIN_ML2_CONF_INI=/etc/neutron/plugins/ml2/ml2_conf.ini
NEUTRON_L3_AGENT_INI=/etc/neutron/l3_agent.ini
NEUTRON_DHCP_AGENT_INI=/etc/neutron/dhcp_agent.ini
NEUTRON_METADATA_AGENT_INI=/etc/neutron/metadata_agent.ini

NEUTRON_SERVICE_USER=neutron
NEUTRON_SERVICE_PASS=neutron

# Configure Neutron
cat > ${NEUTRON_CONF} <<EOF
[DEFAULT]
verbose = True
debug = True
state_path = /var/lib/neutron
lock_path = \$state_path/lock
log_dir = /var/log/neutron

bind_host = 0.0.0.0
bind_port = 9696

# Plugin
core_plugin = ml2
service_plugins = router
allow_overlapping_ips = True

# auth
auth_strategy = keystone

# RPC configuration options. Defined in rpc __init__
# The messaging module to use, defaults to kombu.
rpc_backend = neutron.openstack.common.rpc.impl_kombu

rabbit_host = ${API_CONTROLLER}
rabbit_password = guest
rabbit_port = 5672
rabbit_userid = guest
rabbit_virtual_host = /
rabbit_ha_queues = false

# ============ Notification System Options =====================
notification_driver = neutron.openstack.common.notifier.rpc_notifier

[agent]
root_helper = sudo

[keystone_authtoken]
auth_host = ${API_CONTROLLER}
auth_port = 35357
auth_protocol = http
admin_tenant_name = ${SERVICE_TENANT}
admin_user = ${NEUTRON_SERVICE_USER}
admin_password = ${NEUTRON_SERVICE_PASS}
signing_dir = \$state_path/keystone-signing

[database]
connection = mysql://neutron:${MYSQL_NEUTRON_PASS}@${API_CONTROLLER}/neutron

[service_providers]
#service_provider=LOADBALANCER:Haproxy:neutron.services.loadbalancer.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default
#service_provider=VPN:openswan:neutron.services.vpn.service_drivers.ipsec.IPsecVPNDriver:default

EOF

cat > ${NEUTRON_PLUGIN_ML2_CONF_INI} <<EOF
[ml2]
type_drivers = gre
tenant_network_types = gre
mechanism_drivers = openvswitch

[ml2_type_gre]
tunnel_id_ranges = 1:1000

[ovs]
local_ip = ${MY_IP}
tunnel_type = gre
enable_tunneling = True

[securitygroup]
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
enable_security_group = True
EOF

echo "
Defaults !requiretty
neutron ALL=(ALL:ALL) NOPASSWD:ALL" | tee -a /etc/sudoers

# Restart Neutron Services
service neutron-plugin-openvswitch-agent restart


# Clobber the nova.conf file with the following
NOVA_CONF=/etc/nova/nova.conf
NOVA_API_PASTE=/etc/nova/api-paste.ini

cat > ${NOVA_CONF} <<EOF
[DEFAULT]
dhcpbridge_flagfile=/etc/nova/nova.conf
dhcpbridge=/usr/bin/nova-dhcpbridge
logdir=/var/log/nova
state_path=/var/lib/nova
lock_path=/var/lock/nova
root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf
verbose=True

use_syslog = True
syslog_log_facility = LOG_LOCAL0

api_paste_config=/etc/nova/api-paste.ini
enabled_apis=ec2,osapi_compute,metadata

# Libvirt and Virtualization
libvirt_use_virtio_for_bridges=True
connection_type=libvirt
libvirt_type=qemu

# Database
sql_connection=mysql://nova:openstack@${MYSQL_HOST}/nova

# Messaging
rabbit_host=${MYSQL_HOST}

# EC2 API Flags
ec2_host=${MYSQL_HOST}
ec2_dmz_host=${MYSQL_HOST}
ec2_private_dns_show_ip=True

# Network settings
network_api_class=nova.network.neutronv2.api.API
neutron_url=http://${API_CONTROLLER}:9696
neutron_auth_strategy=keystone
neutron_admin_tenant_name=service
neutron_admin_username=neutron
neutron_admin_password=neutron
neutron_admin_auth_url=http://${API_CONTROLLER}:5000/v2.0
libvirt_vif_driver=nova.virt.libvirt.vif.LibvirtHybridOVSBridgeDriver
linuxnet_interface_driver=nova.network.linux_net.LinuxOVSInterfaceDriver
#firewall_driver=nova.virt.libvirt.firewall.IptablesFirewallDriver
security_group_api=neutron
firewall_driver=nova.virt.firewall.NoopFirewallDriver

service_neutron_metadata_proxy=true
neutron_metadata_proxy_shared_secret=foo

#Metadata
#metadata_host = ${MYSQL_HOST}
#metadata_listen = ${MYSQL_HOST}
#metadata_listen_port = 8775

# Cinder #
volume_driver=nova.volume.driver.ISCSIDriver
enabled_apis=ec2,osapi_compute,metadata
volume_api_class=nova.volume.cinder.API
iscsi_helper=tgtadm
iscsi_ip_address=${CONTROLLER_HOST}

# Images
image_service=nova.image.glance.GlanceImageService
glance_api_servers=${API_CONTROLLER}:9292

# Scheduler
scheduler_default_filters=AllHostsFilter

# Auth
auth_strategy=keystone
keystone_ec2_url=http://${KEYSTONE_ENDPOINT}:5000/v2.0/ec2tokens

# NoVNC
novnc_enabled=true
novncproxy_host=${MY_IP}
novncproxy_base_url=http://${MY_IP}:6080/vnc_auto.html
novncproxy_port=6080

xvpvncproxy_port=6081
xvpvncproxy_host=${MY_IP}
xvpvncproxy_base_url=http://${MY_IP}:6081/console

vncserver_proxyclient_address=${MY_IP}
vncserver_listen=0.0.0.0

[keystone_authtoken]
service_protocol = http
service_host = ${CONTROLLER_HOST}
service_port = 5000
auth_host = ${CONTROLLER_HOST}
auth_port = 35357
auth_protocol = http
auth_uri = http://${CONTROLLER_HOST}:5000/
admin_tenant_name = ${SERVICE_TENANT}
admin_user = ${NOVA_SERVICE_USER}
admin_password = ${NOVA_SERVICE_PASS}

[cells]
name=c1
instance_updated_at_threshold=86400
enable=true
scheduler_filter_classes=nova.cells.filters.target_cell.TargetCellFilter,nova.cells.filters.image_properties.ImagePropertiesFilter
instance_update_num_instances=75
reserve_percent=0.0
#capabilities=flavor_classes=standard1;performance1;performance2;memory1;compute1
cell_type=compute
offset_weight_multiplier=100
EOF

sudo chmod 0640 $NOVA_CONF
sudo chown nova:nova $NOVA_CONF

}

nova_ceilometer() {
	/vagrant/ceilometer-compute.sh
}

nova_restart() {
	for P in $(ls /etc/init/nova* | cut -d'/' -f4 | cut -d'.' -f1)
	do
		sudo stop ${P}
		sudo start ${P}
	done
}

# Main
nova_compute_install
nova_configure
nova_ceilometer
nova_restart

apt-get install -y expect

sudo ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa
rm -f /vagrant/id_rsa*
sudo cp /root/.ssh/id_rsa /vagrant
sudo cp /root/.ssh/id_rsa.pub /vagrant
cat /vagrant/id_rsa.pub | sudo tee -a /root/.ssh/authorized_keys

ssh-keyscan cell-api-cont.lab >> /root/.ssh/known_hosts
ssh-keyscan cell-c1-cont.lab >> /root/.ssh/known_hosts

expect<<EOF
spawn ssh-copy-id cell-api-cont.lab
expect "root@cell-api-cont.lab's password:"
send "vagrant\n"
expect eof
EOF

expect<<EOF
spawn ssh-copy-id cell-c1-cont.lab
expect "root@cell-c1-cont.lab's password:"
send "vagrant\n"
expect eof
EOF

echo "[+] Restarting nova-* on cell-api-cont"
ssh root@cell-api-cont.lab "cd /etc/init; ls nova-* neutron-server.conf | cut -d '.' -f1 | while read N; do stop \$N; start \$N; done"

sleep 30; echo "[+] Restarting nova-* on cell-c1-cont"
ssh root@cell-c1-cont.lab "cd /etc/init; ls nova-* neutron-server.conf | cut -d '.' -f1 | while read N; do stop \$N; start \$N; done"

sleep 30; echo "[+] Restarting nova-* on cell-c1-comp"
cd /etc/init; ls nova-* neutron-server.conf | cut -d '.' -f1 | while read N; do stop $N; start $N; done
