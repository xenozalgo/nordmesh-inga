ARG ARCH=amd64
FROM balenalib/${ARCH}-alpine

LABEL maintainer="Julio Gutierrez <bubuntux@gmail.com>"

#CROSSRUN [ "cross-build-start" ]
RUN apk --no-cache --no-progress upgrade && \
    apk --no-cache --no-progress add bash curl jq ip6tables iptables openvpn shadow tini tzdata && \
    addgroup -S vpn && \
    rm -rf /tmp/*
#CROSSRUN [ "cross-build-end" ]

VOLUME ["/vpn"]

HEALTHCHECK --timeout=15s --interval=60s --start-period=120s \
            CMD curl -fL "https://api.ipify.org" || exit 1

COPY nordVpn.sh /usr/bin
ENTRYPOINT ["/sbin/tini", "--", "/usr/bin/nordVpn.sh"]