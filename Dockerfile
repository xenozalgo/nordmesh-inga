FROM ghcr.io/linuxserver/baseimage-ubuntu:jammy
LABEL maintainer="Julio Gutierrez julio.guti+nordvpn@pm.me"

ARG NORDVPN_VERSION=3.20.0
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && \
    apt-get install -y systemd cron curl iputils-ping libc6 wireguard vim  && \
    curl https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/n/nordvpn-release/nordvpn-release_1.0.0_all.deb --output /tmp/nordrepo.deb && \
    apt-get install -y /tmp/nordrepo.deb && \
    apt-get update -y && \
    apt-get install -y nordvpn${NORDVPN_VERSION:+=$NORDVPN_VERSION} && \
    apt-get remove -y nordvpn-release && \
    apt-get autoremove -y && \
    apt-get autoclean -y && \
    rm -rf \
		/tmp/* \
		/var/cache/apt/archives/* \
		/var/lib/apt/lists/* \
		/var/tmp/*

COPY /rootfs /
ENV S6_CMD_WAIT_FOR_SERVICES=1
CMD nord_login && nord_config && nord_connect && nord_migrate && nord_watch
