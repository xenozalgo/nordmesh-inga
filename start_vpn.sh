#!/bin/bash
[[ -n ${DEBUG} ]] && set -x

iptables -F
iptables -X
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

ip6tables -F 2>/dev/null
ip6tables -X 2>/dev/null
ip6tables -P INPUT DROP 2>/dev/null
ip6tables -P FORWARD DROP 2>/dev/null
ip6tables -P OUTPUT DROP 2>/dev/null

echo "Firewall is up, everything has to go through the vpn"
echo "Enabling connection to secure interfaces"

iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i lo -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -o tap+ -j ACCEPT
iptables -A OUTPUT -o tun+ -j ACCEPT
iptables -A OUTPUT -o nordlynx+ -j ACCEPT
iptables -t nat -A POSTROUTING -o tap+ -j MASQUERADE
iptables -t nat -A POSTROUTING -o tun+ -j MASQUERADE
iptables -t nat -A POSTROUTING -o nordlynx+ -j MASQUERADE

ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null
ip6tables -A INPUT -p icmp -j ACCEPT 2>/dev/null
ip6tables -A INPUT -i lo -j ACCEPT 2>/dev/null
ip6tables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null
ip6tables -A FORWARD -p icmp -j ACCEPT 2>/dev/null
ip6tables -A FORWARD -i lo -j ACCEPT 2>/dev/null
ip6tables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null
ip6tables -A OUTPUT -o lo -j ACCEPT 2>/dev/null
ip6tables -A OUTPUT -o tap+ -j ACCEPT 2>/dev/null
ip6tables -A OUTPUT -o tun+ -j ACCEPT 2>/dev/null
ip6tables -A OUTPUT -o nordlynx+ -j ACCEPT 2>/dev/null
ip6tables -t nat -A POSTROUTING -o tap+ -j MASQUERADE 2>/dev/null
ip6tables -t nat -A POSTROUTING -o tun+ -j MASQUERADE 2>/dev/null
ip6tables -t nat -A POSTROUTING -o nordlynx+ -j MASQUERADE 2>/dev/null

echo "Enabling connection to nordvpn group"

iptables -A OUTPUT -m owner --gid-owner nordvpn -j ACCEPT || {
  echo "group match failed, fallback to open necessary ports"
  iptables -A OUTPUT -p udp -m udp --dport 53 -j ACCEPT
  iptables -A OUTPUT -p udp -m udp --dport 51820 -j ACCEPT
  iptables -A OUTPUT -p tcp -m tcp --dport 1194 -j ACCEPT
  iptables -A OUTPUT -p udp -m udp --dport 1194 -j ACCEPT
  iptables -A OUTPUT -p tcp -m tcp --dport 443 -j ACCEPT
}

ip6tables -A OUTPUT -m owner --gid-owner nordvpn -j ACCEPT 2>/dev/null || {
  echo "ip6 group match failed, fallback to open necessary ports"
  ip6tables -A OUTPUT -p udp -m udp --dport 53 -j ACCEPT 2>/dev/null
  ip6tables -A OUTPUT -p udp -m udp --dport 51820 -j ACCEPT 2>/dev/null
  ip6tables -A OUTPUT -p tcp -m tcp --dport 1194 -j ACCEPT 2>/dev/null
  ip6tables -A OUTPUT -p udp -m udp --dport 1194 -j ACCEPT 2>/dev/null
  ip6tables -A OUTPUT -p tcp -m tcp --dport 443 -j ACCEPT 2>/dev/null
}

echo "Enabling connection to docker network"

docker_network="$(ip -o addr show dev eth0 | awk '$3 == "inet" {print $4}')"
if [[ -n ${docker_network} ]]; then
  iptables -A INPUT -s "${docker_network}" -j ACCEPT
  iptables -A FORWARD -d "${docker_network}" -j ACCEPT
  iptables -A FORWARD -s "${docker_network}" -j ACCEPT
  iptables -A OUTPUT -d "${docker_network}" -j ACCEPT
fi

docker6_network="$(ip -o addr show dev eth0 | awk '$3 == "inet6" {print $4; exit}')"
if [[ -n ${docker6_network} ]]; then
  ip6tables -A INPUT -s "${docker6_network}" -j ACCEPT 2>/dev/null
  ip6tables -A FORWARD -d "${docker6_network}" -j ACCEPT 2>/dev/null
  ip6tables -A FORWARD -s "${docker6_network}" -j ACCEPT 2>/dev/null
  ip6tables -A OUTPUT -d "${docker6_network}" -j ACCEPT 2>/dev/null
fi

if [[ -n ${NETWORK} ]]; then
  gw=$(ip route | awk '/default/ {print $3}')
  for net in ${NETWORK//[;,]/ }; do
    echo "Enabling connection to network ${net}"
    ip route | grep -q "$net" || ip route add to "$net" via "$gw" dev eth0
    iptables -A INPUT -s "$net" -j ACCEPT
    iptables -A FORWARD -d "$net" -j ACCEPT
    iptables -A FORWARD -s "$net" -j ACCEPT
    iptables -A OUTPUT -d "$net" -j ACCEPT
  done
fi

if [[ -n ${NETWORK6} ]]; then
  gw6=$(ip -6 route | awk '/default/{print $3}')
  for net6 in ${NETWORK6//[;,]/ }; do
    echo "Enabling connection to network ${net6}"
    ip -6 route | grep -q "$net6" || ip -6 route add to "$net6" via "$gw6" dev eth0
    ip6tables -A INPUT -s "$net6" -j ACCEPT 2>/dev/null
    ip6tables -A FORWARD -d "$net6" -j ACCEPT 2>/dev/null
    ip6tables -A FORWARD -s "$net6" -j ACCEPT 2>/dev/null
    ip6tables -A OUTPUT -d "$net6" -j ACCEPT 2>/dev/null
  done
fi

if [[ -n ${WHITELIST} ]]; then
  for domain in ${WHITELIST//[;,]/ }; do
    domain=$(echo "$domain" | sed 's/^.*:\/\///;s/\/.*$//')
    echo "Enabling connection to host ${domain}"
    sg nordvpn -c "iptables  -A OUTPUT -o eth0 -d ${domain} -j ACCEPT"
    sg nordvpn -c "ip6tables -A OUTPUT -o eth0 -d ${domain} -j ACCEPT 2>/dev/null"
  done
fi

mkdir -p /dev/net
[[ -c /dev/net/tun ]] || mknod -m 0666 /dev/net/tun c 10 200

restart_daemon() {
  echo "Restarting the service"
  service nordvpn stop
  rm -rf /run/nordvpn/nordvpnd.sock
  service nordvpn start

  echo "Waiting for the service to start"
  attempt_counter=0
  max_attempts=50
  until [ -S /run/nordvpn/nordvpnd.sock ]; do
    if [ ${attempt_counter} -eq ${max_attempts} ]; then
      echo "Max attempts reached"
      exit 1
    fi
    echo -n '.'
    attempt_counter=$((attempt_counter + 1))
    sleep 0.1
  done
}
restart_daemon

nordvpn logout
nordvpn login -u "${USER}" -p "${PASS}" || exit 1

[[ -n ${CYBER_SEC} ]] && nordvpn set cybersec ${CYBER_SEC}
[[ -n ${DNS} ]] && nordvpn set dns ${DNS//[;,]/ }
[[ -n ${FIREWALL} ]] && nordvpn set firewall ${FIREWALL}
[[ -n ${KILLSWITCH} ]] && nordvpn set killswitch ${KILLSWITCH}
[[ -n ${OBFUSCATE} ]] && nordvpn set obfuscate ${OBFUSCATE}
[[ -n ${PROTOCOL} ]] && nordvpn set protocol ${PROTOCOL}
[[ -n ${TECHNOLOGY} ]] && nordvpn set technology ${TECHNOLOGY}

[[ -n ${docker_network} ]] && nordvpn whitelist add subnet ${docker_network}
[[ -n ${NETWORK} ]] && for net in ${NETWORK//[;,]/ }; do nordvpn whitelist add subnet "${net}"; done
[[ -n ${PORTS} ]] && for port in ${PORTS//[;,]/ }; do nordvpn whitelist add port "${port}"; done
[[ -n ${PORT_RANGE} ]] && nordvpn whitelist add ports ${PORT_RANGE}

nordvpn -version
nordvpn settings

connect() {
  nordvpn connect ${CONNECT} || {
    cat /var/log/nordvpn/daemon.log
    exit 1
  }
  tail -f --pid="$(cat /run/nordvpn/nordvpn.pid)" /var/log/nordvpn/daemon.log &
}
connect

cleanup() {
  nordvpn disconnect
  service nordvpn stop
  trap - SIGTERM SIGINT EXIT # https://bash.cyberciti.biz/guide/How_to_clear_trap
  exit 0
}
trap cleanup SIGTERM SIGINT EXIT # https://www.ctl.io/developers/blog/post/gracefully-stopping-docker-containers/

while true; do
  sleep "${RECONNECT:-300}"
  if [ "$(curl -m 20 -s https://api.nordvpn.com/v1/helpers/ips/insights | jq -r '.["protected"]')" != "true" ]; then
    echo "Reconnecting..."
    restart_daemon
    connect
  fi
done