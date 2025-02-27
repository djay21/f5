#!/bin/bash
# Setup console and startup-script logging
LOG_FILE=/var/log/cloud/startup-script.log
mkdir -p  /var/log/cloud
[[ -f $LOG_FILE ]] || /usr/bin/touch $LOG_FILE
npipe=/tmp/$$.tmp
trap "rm -f $npipe" EXIT
mknod $npipe p
tee <$npipe -a $LOG_FILE /dev/ttyS0 &
exec 1>&-
exec 1>$npipe
exec 2>&1

# Run Immediately Before MCPD starts
/usr/bin/setdb provision.extramb 1024
/usr/bin/setdb restjavad.useextramb true

# skip startup script if already complete
if [[ -f /config/startup_finished ]]; then
  echo "Onboarding complete, skip startup script"
  exit
fi

mkdir -p /config/cloud /var/config/rest/downloads /var/lib/cloud/icontrollx_installs

# Create runtime configuration on first boot
if [[ ! -f /config/nicswap_finished ]]; then
cat << 'EOF' > /config/cloud/runtime-init-conf.yaml
---
controls:
  extensionInstallDelayInMs: 60000
runtime_parameters:
  - name: USER_NAME
    type: static
    value: ${bigip_username}
  - name: SSH_KEYS
    type: static
    value: "${ssh_keypair}"
  - name: HOST_NAME
    type: metadata
    metadataProvider:
        environment: gcp
        type: compute
        field: name
EOF

if ${gcp_secret_manager_authentication}; then
   cat << 'EOF' >> /config/cloud/runtime-init-conf.yaml
  - name: ADMIN_PASS
    type: secret
    secretProvider:
      environment: gcp
      type: SecretsManager
      version: latest
      secretId: ${bigip_password}
pre_onboard_enabled: []
EOF
else
   cat << 'EOF' >> /config/cloud/runtime-init-conf.yaml
  - name: ADMIN_PASS
    type: static
    value: ${bigip_password}
pre_onboard_enabled: []
EOF
fi

cat /config/cloud/runtime-init-conf.yaml > /config/cloud/runtime-init-conf-backup.yaml

cat << 'EOF' >> /config/cloud/runtime-init-conf.yaml
extension_packages: 
  install_operations:
    - extensionType: do
      extensionVersion: ${DO_VER}
      extensionUrl: ${DO_URL}
    - extensionType: as3
      extensionVersion: ${AS3_VER}
      extensionUrl: ${AS3_URL}
    - extensionType: ts
      extensionVersion: ${TS_VER}
      extensionUrl: ${TS_URL}
    - extensionType: cf
      extensionVersion: ${CFE_VER}
      extensionUrl: ${CFE_URL}
    - extensionType: fast
      extensionVersion: ${FAST_VER}
      extensionUrl: ${FAST_URL}
extension_services:
  service_operations:
    - extensionType: do
      type: inline
      value:
        schemaVersion: 1.0.0
        class: Device
        async: true
        Common:
          class: Tenant
          hostname: '{{{HOST_NAME}}}.com'
          myNtp:
            class: NTP
            servers:
              - 169.254.169.254
            timezone: UTC
          myDns:
            class: DNS
            nameServers:
              - 169.254.169.254
          myProvisioning:
            class: Provision
            ltm: nominal
          admin:
            class: User
            partitionAccess:
              all-partitions:
                role: admin
            password: '{{{ADMIN_PASS}}}'
            shell: bash
            keys:
              - '{{{SSH_KEYS}}}'
            userType: regular
          '{{{USER_NAME}}}':
            class: User
            partitionAccess:
              all-partitions:
                role: admin
            password: '{{{ADMIN_PASS}}}'
            shell: bash
            keys:
              - '{{{SSH_KEYS}}}'
            userType: regular
post_onboard_enabled: []
EOF

cat << 'EOF' >> /config/cloud/runtime-init-conf-backup.yaml
extension_services:
  service_operations:
    - extensionType: do
      type: inline
      value:
        schemaVersion: 1.0.0
        class: Device
        async: true
        Common:
          class: Tenant
          hostname: '{{{HOST_NAME}}}.com'
          myNtp:
            class: NTP
            servers:
              - 169.254.169.254
            timezone: UTC
          myDns:
            class: DNS
            nameServers:
              - 169.254.169.254
          myProvisioning:
            class: Provision
            ltm: nominal
          admin:
            class: User
            partitionAccess:
              all-partitions:
                role: admin
            password: '{{{ADMIN_PASS}}}'
            shell: bash
            keys:
              - '{{{SSH_KEYS}}}'
            userType: regular
          '{{{USER_NAME}}}':
            class: User
            partitionAccess:
              all-partitions:
                role: admin
            password: '{{{ADMIN_PASS}}}'
            shell: bash
            keys:
              - '{{{SSH_KEYS}}}'
            userType: regular
post_onboard_enabled: []
EOF
fi

# Create nic_swap script when multi nic on first boot
COMPUTE_BASE_URL="http://metadata.google.internal/computeMetadata/v1"

if [[ ${NIC_COUNT} && ! -f /config/nicswap_finished ]]; then
   cat << 'EOF' >> /config/cloud/nic_swap.sh
   #!/bin/bash
   source /usr/lib/bigstart/bigip-ready-functions
   wait_bigip_ready
   echo "before nic swapping"
   tmsh list sys db provision.1nicautoconfig
   tmsh list sys db provision.managementeth
   echo "after nic swapping"
   bigstart stop tmm
   tmsh modify sys db provision.managementeth value eth1
   tmsh modify sys db provision.1nicautoconfig value disable
   bigstart start tmm
   wait_bigip_ready
   echo "---Mgmt interface setting---"
   tmsh list sys db provision.managementeth
   tmsh list sys db provision.1nicautoconfig
   sed -i "s/iface0=eth0/iface0=eth1/g" /etc/ts/common/image.cfg
   echo "Done changing interface"
   echo "Set TMM networks"
   MGMTADDRESS=$(curl -s -f --retry 10 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/1/ip)
   MGMTMASK=$(curl -s -f --retry 10 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/1/subnetmask)
   MGMTGATEWAY=$(curl -s -f --retry 10 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/1/gateway)
   MGMTMTU=$(curl -s -f --retry 10 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/1/mtu)
   MGMTNETWORK=$(/bin/ipcalc -n $MGMTADDRESS $MGMTMASK | cut -d= -f2)
   INT1ADDRESS=$(curl -s -f --retry 10 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
   INT1MASK=$(curl -s -f --retry 10 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/subnetmask) 
   INT1GATEWAY=$(curl -s -f --retry 10 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/gateway)
   INT1NETWORK=$(ipcalc -n $INT1ADDRESS $INT1MASK | cut -d= -f2)
   EXT1ADDRESS=$(/usr/bin/curl -s -f --retry 20 'http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip' -H 'Metadata-Flavor: Google')
   EXT1MASK=$(/usr/bin/curl -s -f --retry 20 'http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/subnetmask' -H 'Metadata-Flavor: Google') 
   EXT1GATEWAY=$(/usr/bin/curl -s -f --retry 20 'http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/gateway' -H 'Metadata-Flavor: Google')
   EXT1NETWORK=$(/bin/ipcalc -n $EXT1ADDRESS $EXT1MASK | cut -d= -f2)
   tmsh modify sys global-settings gui-setup disabled
   tmsh modify sys global-settings mgmt-dhcp disabled
   tmsh delete sys management-route all 
   tmsh delete sys management-ip all
   tmsh create sys management-ip $${MGMTADDRESS}/32
   tmsh create sys management-route mgmt_gw network $${MGMTGATEWAY}/32 type interface mtu $${MGMTMTU}
   tmsh create sys management-route mgmt_net network $${MGMTNETWORK}/$${MGMTMASK} gateway $${MGMTGATEWAY} mtu $${MGMTMTU}
   tmsh create sys management-route default gateway $${MGMTGATEWAY} mtu $${MGMTMTU}
   tmsh modify sys global-settings remote-host add { metadata.google.internal { hostname metadata.google.internal addr 169.254.169.254 } }
   tmsh modify sys management-dhcp sys-mgmt-dhcp-config request-options delete { ntp-servers }
   echo -e "MGMTADDRESS=$MGMTADDRESS \n MGMTMASK=$MGMTMASK \n MGMTGATEWAY=$MGMTGATEWAY \n INT1ADDRESS=$INT1ADDRESS \n INT1MASK=$INT1MASK \n INT1GATEWAY=$INT1GATEWAY \n EXT1ADDRESS=$EXT1ADDRESS \n EXT1MASK=$EXT1MASK \n EXT1GATEWAY=$EXT1GATEWAY \n EXT1NETWORK=$EXT1NETWORK \n HOSTNAME=$HOSTNAME"   
   tmsh list net interface 
   tmsh modify sys db failover.selinuxallowscripts value enable
   tmsh modify sys software update auto-phonehome enabled
   tmsh save /sys config
   /usr/bin/touch /config/nicswap_finished
   reboot
EOF
fi

# Create run_runtime_init.sh script on first boot
if [[ ! -f /config/nicswap_finished ]]; then
  cat << 'EOF' >> /config/cloud/run_runtime_init.sh
  #!/bin/bash
  source /usr/lib/bigstart/bigip-ready-functions
  wait_bigip_ready
  echo "${INIT_URL}"
  for i in {1..5}; do
    curl -fv --retry 1 --connect-timeout 5 -L ${INIT_URL} -o "/var/config/rest/downloads/f5-bigip-runtime-init.gz.run" && break || sleep 10
  done
  bash /var/config/rest/downloads/f5-bigip-runtime-init.gz.run -- '--cloud gcp' 2>&1
  /usr/local/bin/f5-bigip-runtime-init --config-file /config/cloud/runtime-init-conf.yaml 2>&1
  sleep 2
  /usr/local/bin/f5-bigip-runtime-init --config-file /config/cloud/runtime-init-conf-backup.yaml 2>&1
  sleep 2
   /usr/local/bin/f5-bigip-runtime-init --config-file /config/cloud/runtime-init-conf-backup.yaml 2>&1
   HOSTNAME=$(tmsh list sys global-settings hostname | grep hostname  | awk '{print $2}')
   if [[ $HOSTNAME == *".com" ]]; then
   echo "starting config utitlity **************************"
   INT1ADDRESS=$(/usr/bin/curl -s -f --retry 20 'http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip' -H 'Metadata-Flavor: Google')
   INT1MASK=$(/usr/bin/curl -s -f --retry 20 'http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/subnetmask' -H 'Metadata-Flavor: Google') 
   INT1GATEWAY=$(/usr/bin/curl -s -f --retry 20 'http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/gateway' -H 'Metadata-Flavor: Google')
   INT1NETWORK=$(/bin/ipcalc -n $INT1ADDRESS $INT1MASK | cut -d= -f2)
   echo -e "INT1ADDRESS=$INT1ADDRESS \n INT1MASK=$INT1MASK \n INT1GATEWAY=$INT1GATEWAY  \n INT1NETWORK=$INT1NETWORK \n HOSTNAME=$HOSTNAME"   
   tmsh modify sys software update auto-phonehome enabled
   for i in 1.0 1.1 1.2; do 
   a=$(tmsh list net interface | grep $i); 
   echo $a
   if [[ $a == "" ]];
   then echo "$i not found.. continuing"; 
   else 
   tmsh create net vlan external interfaces add { $i } mtu 1460
   echo "creating vlan with $i"
   break
   fi
   done
   tmsh create net self self_external address $INT1ADDRESS/32 vlan external allow-service add { tcp:4353 udp:1026 }
   tmsh create net route ext_gw_interface network $INT1GATEWAY/32 interface external
   tmsh create net route ext_rt network $INT1NETWORK/$INT1MASK gw $INT1GATEWAY
   tmsh create net route default gw $INT1GATEWAY
   HOSTNAME=$(tmsh list sys global-settings hostname | grep hostname  | awk '{print $2}')
   tmsh modify cm device $HOSTNAME configsync-ip $INT1ADDRESS
   tmsh modify cm device $HOSTNAME unicast-address { { effective-ip $INT1ADDRESS effective-port 1026 ip $INT1ADDRESS } }
   tmsh modify /cm device $HOSTNAME  mirror-ip $INT1ADDRESS
   tmsh modify /sys db log.accesscontrol.level value debug
   tmsh modify sys db failover.selinuxallowscripts value enable
   else
   echo "*************** Config-sync not configured. **************"
   fi
   sleep 80
   echo "Done"
  /usr/bin/touch /config/startup_finished
EOF
fi

# Run scripts based on number of nics
if ${NIC_COUNT}; then
  if [[ -f /config/nicswap_finished ]]; then
    echo "Running run_runtime_init.sh"
    chmod +x /config/cloud/run_runtime_init.sh
    nohup /config/cloud/run_runtime_init.sh &
  else
    chmod +x /config/cloud/nic_swap.sh
    nohup /config/cloud/nic_swap.sh &
  fi
else
    echo "Running run_runtime_init.sh"
    chmod +x /config/cloud/run_runtime_init.sh
    nohup /config/cloud/run_runtime_init.sh &
fi