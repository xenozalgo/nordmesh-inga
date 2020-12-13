FROM ubuntu:18.04

LABEL maintainer="Julio Gutierrez"
ARG NORDVPN_VERSION=3.7.4

HEALTHCHECK --interval=5m --timeout=20s --start-period=1m \
	CMD if test $( curl -m 10 -s https://api.nordvpn.com/vpn/check/full | jq -r '.["status"]' ) = "Protected" ; then exit 0; else nordvpn connect ${CONNECT} ; exit $?; fi

RUN addgroup --system vpn && \
	apt update && \
	apt install -y curl jq && \
	curl https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/nordvpn-release_1.0.0_all.deb --output /tmp/nordrepo.deb && \
    apt install -y /tmp/nordrepo.deb && \
    apt update && \
    apt install -y nordvpn${NORDVPN_VERSION:+=$NORDVPN_VERSION} && \
    apt remove -y nordvpn-release && \
    rm -rf \
		/tmp/* \
		/var/cache/apt/archives/* \
		/var/lib/apt/lists/* \
		/var/tmp/*

CMD /usr/bin/start_vpn.sh
COPY start_vpn.sh /usr/bin