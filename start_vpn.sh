#!/bin/bash


if [ "$(cat /etc/timezone)" != "${TZ}" ]; then
  if [ -d "/usr/share/zoneinfo/${TZ}" ] || [ ! -e "/usr/share/zoneinfo/${TZ}" ] || [ -z "${TZ}" ]; then
    TZ="Etc/UTC"
  fi
  ln -fs "/usr/share/zoneinfo/${TZ}" /etc/localtime
  dpkg-reconfigure -f noninteractive tzdata 2>/dev/null
fi




echo "[$(date -Iseconds)] Post-logging settings $(nordvpn -version)"


if [[ -n ${docker_network} ]]; then
  nordvpn whitelist add subnet ${docker_network}
  [[ -n ${NETWORK} ]] && for net in ${NETWORK//[;,]/ }; do nordvpn whitelist add subnet "${net}"; done
fi
if [[ -n ${docker6_network} ]]; then
  nordvpn set ipv6 on
  nordvpn whitelist add subnet ${docker6_network}
  [[ -n ${NETWORK6} ]] && for net in ${NETWORK6//[;,]/ }; do nordvpn whitelist add subnet "${net}"; done
fi

[[ -n ${DEBUG} ]] && nordvpn settings

connect() {
  echo "[$(date -Iseconds)] Connecting..."
  current_sleep=1
  until nordvpn connect ${CONNECT}; do
    if [ ${current_sleep} -gt 4096 ]; then
      echo "[$(date -Iseconds)] Unable to connect."
      tail -n 200 /var/log/nordvpn/daemon.log
      exit 1
    fi
    echo "[$(date -Iseconds)] Unable to connect retrying in ${current_sleep} seconds."
    sleep ${current_sleep}
    current_sleep=$((current_sleep * 2))
  done

}
connect
[[ -n ${DEBUG} ]] && tail -n 1 -f /var/log/nordvpn/daemon.log &


[[ -n ${RECONNECT} && -z ${CHECK_CONNECTION_INTERVAL} ]] && CHECK_CONNECTION_INTERVAL=${RECONNECT}
while true; do
  sleep "${CHECK_CONNECTION_INTERVAL:-300}"
  if [[ ! $(curl -Is -m 30 -o /dev/null -w "%{http_code}" "${CHECK_CONNECTION_URL:-www.google.com}") =~ ^[23] ]]; then
    echo "[$(date -Iseconds)] Unstable connection detected!"
    nordvpn status
    restart_daemon
    connect
  fi
done
