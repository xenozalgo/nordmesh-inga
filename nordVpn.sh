#!/bin/bash

firewall() { # Everything has to go through the vpn
    local docker_network="$(  ip -o addr show dev eth0 | awk '$3 == "inet"  {print $4}'      )" \
          docker6_network="$( ip -o addr show dev eth0 | awk '$3 == "inet6" {print $4; exit}')"

    echo "Staring firewall..." > /dev/stderr
    iptables  -F OUTPUT
    ip6tables -F OUTPUT 2> /dev/null
    iptables  -P OUTPUT DROP
    ip6tables -P OUTPUT DROP 2> /dev/null
    iptables  -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    ip6tables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2> /dev/null
    iptables  -A OUTPUT -o lo -j ACCEPT
    ip6tables -A OUTPUT -o lo -j ACCEPT 2> /dev/null
    iptables  -A OUTPUT -o tap0 -j ACCEPT
    ip6tables -A OUTPUT -o tap0 -j ACCEPT 2>/dev/null
    iptables  -A OUTPUT -o tun0 -j ACCEPT
    ip6tables -A OUTPUT -o tun0 -j ACCEPT 2> /dev/null
    iptables  -A OUTPUT -d ${docker_network} -j ACCEPT
    ip6tables -A OUTPUT -d ${docker6_network} -j ACCEPT 2> /dev/null
    iptables  -A OUTPUT -p udp --dport 53 -j ACCEPT
    ip6tables -A OUTPUT -p udp --dport 53 -j ACCEPT 2> /dev/null
    iptables  -A OUTPUT -p udp -m owner --gid-owner vpn -j ACCEPT || {
        iptables  -A OUTPUT -p tcp -m tcp --dport 1194 -j ACCEPT
        iptables  -A OUTPUT -p udp -m udp --dport 1194 -j ACCEPT; }
    ip6tables -A OUTPUT -p udp -m owner --gid-owner vpn -j ACCEPT 2>/dev/null || {
        ip6tables -A OUTPUT -p tcp -m tcp --dport 1194 -j ACCEPT 2>/dev/null
        ip6tables -A OUTPUT -p udp -m udp --dport 1194 -j ACCEPT 2>/dev/null; }

    [[ -n ${NETWORK} ]]  && for net in ${NETWORK//[;,]/ };  do return_route ${net};  done
    [[ -n ${NETWORK6} ]] && for net in ${NETWORK6//[;,]/ }; do return_route6 ${net}; done
}

return_route() { # Add a route back to your network, so that return traffic works
    local network="$1" gw="$(ip route | awk '/default/ {print $3}')"
    echo "Adding network route ${network}..." > /dev/stderr
    ip route add to ${network} via ${gw} dev eth0
    iptables -A OUTPUT --destination ${network} -j ACCEPT
}

return_route6() { # Add a route back to your network, so that return traffic works
    local network="$1" gw="$(ip -6 route | awk '/default/ {print $3}')"
    echo "Adding network route ${network}..." > /dev/stderr
    ip -6 route add to ${network} via ${gw} dev eth0
    ip6tables -A OUTPUT --destination ${network} -j ACCEPT 2> /dev/null
}

white_list() { # Allow unsecured traffic for an specific domain
    local domain=`echo $1 | awk -F/ '{print $3}'`
    echo "White listing ${domain}..." > /dev/stderr
    iptables  -A OUTPUT -o eth0 -d ${domain} -j ACCEPT
    ip6tables -A OUTPUT -o eth0 -d ${domain} -j ACCEPT 2> /dev/null
}

download_ovpn() { # Download ovpn files into the specified directory
    local nordvpn_ovpn="https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip" \
          ovpn_dir="/vpn/ovpn"

    mkdir -p ${ovpn_dir}
    if [[ $(ls -A ${ovpn_dir} | wc -l) -eq 0 ]]; then
        echo "Downloading config files..." > /dev/stderr
        white_list ${nordvpn_ovpn}
        curl -s ${nordvpn_ovpn} -o /tmp/ovpn.zip
        mkdir -p /tmp/ovpn/
        unzip -q /tmp/ovpn.zip -d /tmp/ovpn
        mv /tmp/ovpn/*/*.ovpn ${ovpn_dir}
        rm -rf /tmp/*
    fi

    echo ${ovpn_dir}
}

country_filter() { # curl -s "https://api.nordvpn.com/v1/servers/countries" | jq --raw-output '.[] | [.code, .name] | @tsv'
    local nordvpn_api=$1 country=(${COUNTRY//[;,]/ })
    if [[ ${#country[@]} -ge 1 ]]; then
        country=${country[0]//_/ }
        local country_id=`curl -s "${nordvpn_api}/v1/servers/countries" | jq --raw-output ".[] |
                          select( (.name|test(\"^${country}$\";\"i\")) or
                                  (.code|test(\"^${country}$\";\"i\")) ) |
                          .id" | head -n 1`
        if [[ -n ${country_id} ]]; then
            echo "Searching for country : ${country} (${country_id})" > /dev/stderr
            echo "filters\[country_id\]=${country_id}&"
        fi
    fi
}

group_filter() { # curl -s "https://api.nordvpn.com/v1/servers/groups" | jq --raw-output '.[] | [.identifier, .title] | @tsv'
    local nordvpn_api=$1 category=(${CATEGORY//[;,]/ })
    if [[ ${#category[@]} -ge 1 ]]; then
        category=${category[0]//_/ }
        local identifier=`curl -s "${nordvpn_api}/v1/servers/groups" | jq --raw-output ".[] |
                          select( .title | test(\"${category}\";\"i\") ) |
                          .identifier" | head -n 1`
        if [[ -n ${identifier} ]]; then
            echo "Searching for group: ${identifier}" > /dev/stderr
            echo "filters\[servers_groups\]\[identifier\]=${identifier}&"
        fi
    fi
}

technology_filter() { # curl -s "https://api.nordvpn.com/v1/technologies" | jq --raw-output '.[] | [.identifier, .name ] | @tsv' | grep openvpn
    local identifier
    if [[ ${PROTOCOL,,} =~ .*udp.* ]]; then
        identifier="openvpn_udp"
    elif [[ ${PROTOCOL,,} =~ .*tcp.* ]];then
        identifier="openvpn_tcp"
    fi
    if [[ -n ${identifier} ]]; then
        echo "Searching for technology: ${identifier}" > /dev/stderr
        echo "filters\[servers_technologies\]\[identifier\]=${identifier}&"
    fi
}

select_hostname() {
    local nordvpn_api="https://api.nordvpn.com" \
          filters hostname

    echo "Selecting the best server..." > /dev/stderr
    white_list ${nordvpn_api}
    filters+="$(country_filter ${nordvpn_api})"
    filters+="$(group_filter ${nordvpn_api})"
    filters+="$(technology_filter )"

    hostname=`curl -s "${nordvpn_api}/v1/servers/recommendations?${filters}limit=1" | jq --raw-output ".[].hostname"`
    if [[ -z ${hostname} ]]; then
        echo "Unable to find a server with the specified parameters, using any recommended server" > /dev/stderr
        hostname=`curl -s "${nordvpn_api}/v1/servers/recommendations?limit=1" | jq --raw-output ".[].hostname"`
    fi

    echo "Best server : ${hostname}" > /dev/stderr
    echo ${hostname}
}

select_config_file() {
    local hostname=$(select_hostname) \
          ovpn_dir=$1 \
          post_fix

    if [[ ${PROTOCOL,,} =~ .*udp.* ]]; then
        post_fix=".udp.ovpn"
    elif [[ ${PROTOCOL,,} =~ .*tcp.* ]];then
        post_fix=".tcp.ovpn"
    fi

    echo "${ovpn_dir}/$(ls ${ovpn_dir} | grep "${hostname}${post_fix}" | tail -n 1)"
}

write_auth_file() {
    local auth_file="/vpn/auth"

    if [[ ! -f ${auth_file} && ! -z ${USER} &&  ! -z ${PASS} ]]; then
        echo "${USER}" > ${auth_file}
        echo "${PASS}" >> ${auth_file}
    fi
    if [[ -f ${auth_file} ]]; then
        chmod 0600 ${auth_file}
    fi

    echo ${auth_file}
}

if [[ $# -ge 1 && -x $(which $1 2>&-) ]]; then
    exec "$@"
elif [[ $# -ge 1 ]]; then
    echo "ERROR: command not found: $1"
    exit 13
elif ps -ef | egrep -v 'grep|nordVpn.sh' | grep -q openvpn; then
    echo "Service already running, please restart container to apply changes"
else
    [[ ${GROUPID:-""} =~ ^[0-9]+$ ]] && groupmod -g ${GROUPID} -o vpn

    firewall # TODO optional

    ovpn_dir=$(download_ovpn)
    if [[ $(ls -A ${ovpn_dir} | wc -l) -eq 0 ]]; then
        echo "Unable to download config files"
        exit 1
    fi

    config_file=$(select_config_file ${ovpn_dir})
    if [[ ! -f ${config_file} ]]; then
        echo "Unable to find config file ${config_file}"
        exit 1
    fi
    echo "Using config file ${config_file}..."

    auth_file=$(write_auth_file)
    if [[ ! -f ${auth_file} ]]; then
        echo "Missing auth file, USER or PASS"
        exit 1
    fi

    mkdir -p /dev/net
    [[ -c /dev/net/tun ]] || mknod -m 0666 /dev/net/tun c 10 200

    echo "Connecting..."
    exec sg vpn -c "openvpn --config ${config_file} --auth-user-pass ${auth_file} --auth-nocache \
                            --script-security 2 --up /etc/openvpn/up.sh --down /etc/openvpn/down.sh" # TODO optional
fi