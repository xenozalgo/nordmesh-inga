<p align="center">
    <a href="https://nordvpn.com/"><img src="https://github.com/bubuntux/nordvpn/raw/master/NordVpn_logo.png"/></a>
    </br>
    <a href="https://github.com/bubuntux/nordvpn/blob/master/LICENSE"><img src="https://badgen.net/github/license/bubuntux/nordvpn?color=cyan"/></a>
    <a href="https://cloud.docker.com/u/bubuntux/repository/docker/bubuntux/nordvpn"><img src="https://badgen.net/docker/size/bubuntux/nordvpn?icon=docker&label=size"/></a>
    <a href="https://cloud.docker.com/u/bubuntux/repository/docker/bubuntux/nordvpn"><img src="https://badgen.net/docker/pulls/bubuntux/nordvpn?icon=docker&label=pulls"/></a>
    <a href="https://cloud.docker.com/u/bubuntux/repository/docker/bubuntux/nordvpn"><img src="https://badgen.net/docker/stars/bubuntux/nordvpn?icon=docker&label=stars"/></a>
    <a href="https://github.com/bubuntux/nordvpn"><img src="https://badgen.net/github/forks/bubuntux/nordvpn?icon=github&label=forks&color=black"/></a>
    <a href="https://github.com/bubuntux/nordvpn"><img src="https://badgen.net/github/stars/bubuntux/nordvpn?icon=github&label=stars&color=black"/></a>
    <a href="https://github.com/bubuntux/nordvpn/actions?query=workflow%3Arelease"><img src="https://github.com/bubuntux/nordvpn/workflows/release/badge.svg"/></a>
</p>

Official `NordVPN` client in a docker container; it makes routing traffic through the `NordVPN` network easy.

# How to use this image

This container was designed to be started first to provide a connection to other containers (using `--net=container:vpn`, see below *Starting an NordVPN client instance*).

**NOTE**: More than the basic privileges are needed for NordVPN. With docker 1.2 or newer you can use the `--cap-add=NET_ADMIN` option. Earlier versions, or with fig, and you'll have to run it in privileged mode.

## Starting an NordVPN instance

    docker run -ti --cap-add=NET_ADMIN --name vpn \
                -e USER=user@email.com -e PASS='pas$word' \
                -e CONNECT=country -e TECHNOLOGY=NordLynx -d ghcr.io/bubuntux/nordvpn

Once it's up other containers can be started using its network connection:

    docker run -it --net=container:vpn -d some/docker-container

## Local Network access to services connecting to the internet through the VPN.
However to access them from your normal network (off the 'local' docker bridge), you'll also need to run a web proxy, like so:
```
sudo docker run -it --name web -p 80:80 -p 443:443 \
            --link vpn:<service_name> -d dperson/nginx \
            -w "http://<service_name>:<PORT>/<URI>;/<PATH>"
```
Which will start a Nginx web server on local ports 80 and 443, and proxy any requests under /<PATH> to the to http://<service_name>:<PORT>/<URI>. To use a concrete example:

```
sudo docker run -it --name bit --net=container:vpn -d dperson/transmission
sudo docker run -it --name web -p 80:80 -p 443:443 --link vpn:bit \
            -d dperson/nginx -w "http://bit:9091/transmission;/transmission"
```

For multiple services (non-existant 'foo' used as an example):

```
sudo docker run -it --name bit --net=container:vpn -d dperson/transmission
sudo docker run -it --name foo --net=container:vpn -d dperson/foo
sudo docker run -it --name web -p 80:80 -p 443:443 --link vpn:bit \
            --link vpn:foo -d dperson/nginx \
            -w "http://bit:9091/transmission;/transmission" \
            -w "http://foo:8000/foo;/foo"
```
## Routing access without the web proxy.

The environment variable NETWORK must be your local network that you would connect to the server running the docker containers on. Running the following on your docker host should give you the correct network: `ip route | awk '!/ (docker0|br-)/ && /src/ {print $1}'`

    docker run -ti --cap-add=NET_ADMIN --name vpn \
                -p 8080:80 -e NETWORK=192.168.1.0/24 \ 
                -e USER=user@email.com -e PASS='pas$word' -d ghcr.io/bubuntux/nordvpn               

Now just create the second container _without_ the `-p` parameter, only inlcude the `--net=container:vpn`, the port should be declare in the vpn container.

    docker run -ti --rm --net=container:vpn -d ghcr.io/bubuntux/element-web

now the service provided by the second container would be available from the host machine (http://localhost:8080) or anywhere inside the local network (http://192.168.1.xxx:8080).

## docker-compose example with web proxy
```
version: "3"
services:
  vpn:
    image: ghcr.io/bubuntux/nordvpn
    cap_add:
      - NET_ADMIN               # Required
    environment:                # Review https://github.com/bubuntux/nordvpn#environment-variables
      - USER=user@email.com     # Required
      - "PASS=pas$word"         # Required
      - CONNECT=United_States
      - TECHNOLOGY=NordLynx
    ulimits:                    # Recommended for High bandwidth scenarios
      memlock:
        soft: -1
        hard: -1

  torrent:
    image: linuxserver/qbittorrent
    network_mode: service:vpn
    depends_on:
      - vpn

  web:
    image: dperson/nginx        # https://github.com/dperson/nginx
    links:                                                                                   
      - vpn:torrent                                                                          
    depends_on:                                                                              
      - torrent                                                                              
    tmpfs:                                                                                   
      - /run                                                                                 
      - /tmp                                                                                 
      - /var/cache/nginx                                                                     
    ports:                                                                                   
      - 80:80                                                                                
      - 443:443                                                                              
    command: -w "http://torrent:8080/;/" 
    
# The torrent service would be available at http://localhost/ 
```

## docker-compose example without web proxy
```
version: "3"
services:
  vpn:
    image: ghcr.io/bubuntux/nordvpn
    network_mode: bridge        # Required
    cap_add:
      - NET_ADMIN               # Required
    environment:                # Review https://github.com/bubuntux/nordvpn#environment-variables
      - USER=user@email.com     # Required
      - "PASS=pas$word"         # Required
      - CONNECT=United_States
      - TECHNOLOGY=NordLynx
      - NETWORK=192.168.1.0/24 
    ulimits:                    # Recommended for High bandwidth scenarios
      memlock:
        soft: -1
        hard: -1
    ports:
      - 8080:8080

  torrent:
    image: linuxserver/qbittorrent
    network_mode: service:vpn
    depends_on:
      - vpn
      
# The torrent service would be available at https://localhost:8080/ or anywhere inside the local network http://192.168.1.xxx:8080
 ```

# ENVIRONMENT VARIABLES

* `USER`     - User for NordVPN account.
* `PASS`     - Password for NordVPN account, surrounding the password in single quotes will prevent issues with special characters such as `$`.
* `CONNECT`  -  [country]/[server]/[country_code]/[city]/[group] or [country] [city], if none provide you will connect to  the recommended server.
   - Provide a [country] argument to connect to a specific country. For example: Australia , Use `docker run --rm ghcr.io/bubuntux/nordvpn countries` to get the list of countries.
   - Provide a [server] argument to connect to a specific server. For example: jp35 , [Full List](https://nordvpn.com/servers/tools/)
   - Provide a [country_code] argument to connect to a specific country. For example: us 
   - Provide a [city] argument to connect to a specific city. For example: 'Hungary Budapest' , Use `docker run --rm ghcr.io/bubuntux/nordvpn cities [country]` to get the list of cities. 
   - Provide a [group] argument to connect to a specific servers group. For example: P2P , Use `docker run --rm ghcr.io/bubuntux/nordvpn n_groups` to get the full list.
   - --group value, -g value  Specify a server group to connect to. For example: 'us -g p2p'
* `CYBER_SEC`  - Enable or Disable. When enabled, the CyberSec feature will automatically block suspicious websites so that no malware or other cyber threats can infect your device. Additionally, no flashy ads will come into your sight. More information on how it works: https://nordvpn.com/features/cybersec/.
* `DNS` -   Can set up to 3 DNS servers. For example 1.1.1.1,8.8.8.8 or Disable, Setting DNS disables CyberSec.
* `FIREWALL`  - Enable or Disable.
* `KILLSWITCH`  - Enable or Disable. (Enabled by default using iptables) This security feature blocks your device from accessing the Internet while not connected to the VPN or in case connection with a VPN server is lost.
* `OBFUSCATE`  - Enable or Disable. When enabled, this feature allows to bypass network traffic sensors which aim to detect usage of the protocol and log, throttle or block it (only valid when using OpenVpn).
* `PROTOCOL`   - TCP or UDP (only valid when using OpenVPN).
* `TECHNOLOGY` - Specify Technology to use: 
   * OpenVPN    - Traditional connection.
   * NordLynx   - NordVpn wireguard implementation (3x-5x times faster).
* `WHITELIST` - List of domains that are going to be accessible _outside_ vpn (IE rarbg.to,yts.mx).
* `NETWORK`  - CIDR networks (IE 192.168.1.0/24), add a route to allows replies once the VPN is up.
* `NETWORK6` - CIDR IPv6 networks (IE fe00:d34d:b33f::/64), add a route to allows replies once the VPN is up.
* `PORTS`  - Semicolon delimited list of ports to whitelist for both UDP and TCP. For example '- PORTS=9091;9095'
* `PORT_RANGE`  - Port range to whitelist for both UDP and TCP. For example '- PORT_RANGE=9091 9095'
* `DEBUG`    - Set to 'on' for troubleshooting (User and Pass would be logged).

# Issues

If you have any problems with or questions about this image, please contact me through a [GitHub issue](https://github.com/bubuntux/nordvpn/issues).
