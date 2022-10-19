#!/bin/zsh

# remove ufw
systemctl disable ufw.service
apt purge ufw -y

# enable ip forwarding
sed -i 's/.*net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf

# disable ipv6
if ! (grep -iq "net.ipv6.conf.all.disable_ipv6" /etc/sysctl.conf && sed -i 's/.*net.ipv6.conf.all.disable_ipv6.*/net.ipv6.conf.all.disable_ipv6=1/' /etc/sysctl.conf); then
  echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
fi

# VM Overcommit Memory
# from https://gitlab.com/cyber5k/mistborn/-/blob/master/scripts/subinstallers/iptables.sh
if ! (grep -iq "vm.overcommit_memory" /etc/sysctl.conf && sed -i 's/.*vm.overcommit_memory.*/vm.overcommit_memory=1/' /etc/sysctl.conf); then
  echo "vm.overcommit_memory=1" >> /etc/sysctl.conf
fi

# Force re-read of sysctl.conf
sysctl -p /etc/sysctl.conf

# flush iptables
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# always accept already established and related packets
iptables -A INPUT -m state --state=ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state=ESTABLISHED,RELATED -j ACCEPT

eth0=$(ip -o -4 route show to default | grep -E -o 'dev [^ ]*' | awk 'NR==1{print $2}')
# accept ssh
iptables -A INPUT -i "${eth0}" -p tcp --dport 22 -j ACCEPT
# enable MASQUERADE on default interface for forwarding
iptables -t nat -A POSTROUTING -o "$eth0" -j MASQUERADE
iptables -A FORWARD -o "${eth0}" -j ACCEPT

# accept hub connections on udp
iptables -A INPUT -i "${eth0}" -p udp --dport 51820 -j ACCEPT
# accept ssh from wireguard as well
iptables -A INPUT -i wg-hub -p tcp --dport 22 -j ACCEPT
# enable forwarding from/to wireguard
iptables -A FORWARD -i wg-hub -j ACCEPT
iptables -A FORWARD -o wg-hub -j ACCEPT

# forward packets from docker-direct and docker-vpn to any network
networks=( docker-direct docker-vpn )
for network in "${networks[@]}" ; do
  inf="br-${$(docker network inspect -f {{.Id}} "${network}"):0:12}"
  iptables -A FORWARD -i "${inf}" -j ACCEPT
  iptables -A FORWARD -o "${inf}" -j ACCEPT
  # accept input requests from this docker network to host
  iptables -A INPUT -i "${inf}" -j ACCEPT
done

# setup firewall rules for gateway with fw_mark and routing table number
hub run-script mullvad setup-firewall

# setup firewall rules for gateway with fw_mark and routing table number
hub run-script gateway setup-firewall gateway-india 51821 101 2

# mark all outgoing connections from docker-vpn(10.10.3.0/24) to use mullvad routing table
iptables -A PREROUTING -t nat -s 10.10.3.0/24 -j MARK --set-mark 100

# port forward host to mailserver
ports=(25 143 465 587 993)
for port in ${ports[*]} ; do
  iptables -t nat -A PREROUTING -i "${eth0}" -p tcp --dport "${port}" -j DNAT --to 10.10.2.5:"${port}"
done

# add postup iptable rules if any
"${DATA_DIR}"/wireguard/post_up.sh

# port forward host to qbittorrent
source "${DATA_DIR}"/mullvad/mullvad.env
PEER_PORT=${MULLVAD_VPN_FORWARDED_PORT}
iptables -t nat -A PREROUTING -i wg-mullvad -p tcp --dport "${PEER_PORT}" -j DNAT --to 10.10.3.2:"${PEER_PORT}"

# save
iptables-save > /etc/iptables/rules.v4
