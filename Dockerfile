ARG ARCH=amd64
FROM balenalib/${ARCH}-ubuntu

ARG VERSION
LABEL maintainer="Julio Gutierrez"

HEALTHCHECK --interval=1m --timeout=5s --start-period=1m \
  CMD if test $( curl -s https://api.nordvpn.com/vpn/check/full | jq -r '.["status"]' ) = "Protected" ; then exit 0; else exit 1; fi

COPY start_vpn.sh /usr/bin
CMD /usr/bin/start_vpn.sh

#CROSSRUN [ "cross-build-start" ]
RUN addgroup --system vpn && \
    apt-get update && apt-get upgrade -y && \
    apt-get install -y wget dpkg curl gnupg2 jq && \
    wget -nc https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/nordvpn-release_1.0.0_all.deb && dpkg -i nordvpn-release_1.0.0_all.deb && \
    apt-get update && apt-get install -yqq nordvpn${VERSION:+=$VERSION} || sed -i "s/init)/$(ps --no-headers -o comm 1))/" /var/lib/dpkg/info/nordvpn.postinst && \
    apt-get install -yqq && apt-get clean && \
    rm -rf \
        ./nordvpn* \
        /tmp/* \
        /var/lib/apt/lists/* \
        /var/tmp/*
#CROSSRUN [ "cross-build-end" ]

