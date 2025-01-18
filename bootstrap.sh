
   MGMTADDRESS=$(curl -s -f --retry 10 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/1/ip)
   MGMTMASK=$(curl -s -f --retry 10 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/1/subnetmask)
   MGMTGATEWAY=$(curl -s -f --retry 10 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/1/gateway)
   MGMTMTU=$(curl -s -f --retry 10 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/1/mtu)
   INT1ADDRESS=$(/usr/bin/curl -s -f --retry 20 'http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/2/ip' -H 'Metadata-Flavor: Google')
   INT1MASK=$(/usr/bin/curl -s -f --retry 20 'http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/2/subnetmask' -H 'Metadata-Flavor: Google') 
   INT1GATEWAY=$(/usr/bin/curl -s -f --retry 20 'http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/2/gateway' -H 'Metadata-Flavor: Google')
   EXT1ADDRESS=$(/usr/bin/curl -s -f --retry 20 'http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip' -H 'Metadata-Flavor: Google')
   EXT1MASK=$(/usr/bin/curl -s -f --retry 20 'http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/subnetmask' -H 'Metadata-Flavor: Google') 
   EXT1GATEWAY=$(/usr/bin/curl -s -f --retry 20 'http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/gateway' -H 'Metadata-Flavor: Google')
   EXT1NETWORK=$(/bin/ipcalc -n $EXT1ADDRESS $EXT1MASK | cut -d= -f2)
   INT1NETWORK=$(/bin/ipcalc -n $INT1ADDRESS $INT1MASK | cut -d= -f2)
   MGMTNETWORK=$(/bin/ipcalc -n $MGMTADDRESS $MGMTMASK | cut -d= -f2)
   echo -e "MGMTADDRESS=$MGMTADDRESS \n MGMTMASK=$MGMTMASK \n MGMTGATEWAY=$MGMTGATEWAY \n INT1ADDRESS=$INT1ADDRESS \n INT1MASK=$INT1MASK \n INT1GATEWAY=$INT1GATEWAY \n EXT1ADDRESS=$EXT1ADDRESS \n EXT1MASK=$EXT1MASK \n EXT1GATEWAY=$EXT1GATEWAY \n EXT1NETWORK=$EXT1NETWORK \n HOSTNAME=$HOSTNAME"   
   tmsh modify sys software update auto-phonehome enabled
   for i in 1.0 1.1 1.2; do 
   a=$(tmsh list net interface | grep $i); 
   echo "**********:$a"
   if [[ $a == "" ]];
   then echo "$i not found.. continuing"; 
   else 
   b=$(tmsh list net vlan | grep EXTERNAL)
   if [[ $b == "" ]];then
   tmsh create net vlan EXTERNAL interfaces add { $i } mtu 1460
   echo "creating External vlan with $i"
   else 
    tmsh create net vlan INTERNAL interfaces add { $i } mtu 1460
    echo "creating Internal Vlan with $i"
    fi
   fi
   done
   tmsh list net vlan
   tmsh create net self self_external address $EXT1ADDRESS/32 vlan EXTERNAL allow-service add { tcp:4353 udp:1026 }
   tmsh create net self self_internal address $INT1ADDRESS/32 vlan INTERNAL allow-service add { tcp:4353 udp:1026 }
   tmsh create net route ext_gw_interface network $EXT1GATEWAY/32 interface EXTERNAL
   tmsh create net route int_gw_interface network $INT1GATEWAY/32 interface INTERNAL
   tmsh create net route int_rt network $INT1NETWORK/$INT1MASK gw $INT1GATEWAY
   tmsh create net route ext_rt network $EXT1NETWORK/$EXT1MASK gw $EXT1GATEWAY
   tmsh create net route default gw $EXT1GATEWAY

   HOSTNAME=$(tmsh list sys global-settings hostname | grep hostname  | awk '{print $2}')
   tmsh modify cm device $HOSTNAME configsync-ip $EXT1ADDRESS
   tmsh modify cm device $HOSTNAME unicast-address { { effective-ip $EXT1ADDRESS effective-port 1026 ip $EXT1ADDRESS } }
   tmsh modify /cm device $HOSTNAME  mirror-ip $EXT1ADDRESS mirror-secondary-ip $INT1ADDRESS
   tmsh modify sys db failover.selinuxallowscripts value enable
   tmsh modify /sys db log.accesscontrol.level value debug


   for i in $(echo $aliasIps | tr -d "\"|[|]") ; 
   do
   i=$(echo $i | cut -d "/" -f1)
   echo "$i"
   /usr/bin/tmsh create ltm virtual-address $i
   done
