FROM debian:12-slim

LABEL maintainer="Helm (Trinity)"
LABEL purpose="mt5-gateway image — Debian 12 base + KasmVNC X server variant (matches gmag11 production X stack); originated as trinity-mt5-image, imported+fixed under WO-MT5GW-0002"
LABEL wo="WO-NEO-FTMO-PRACTICE-EXECUTION-RET_CODE-10044-DIAGNOSTIC-0001"
LABEL origin.image.tag="trinity/mt5:0.1.3-kasmvnc"
LABEL gateway.image.tag="mt5-gateway:0.2.0-rc2"

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
        wget curl gnupg2 ca-certificates software-properties-common sudo locales \
    && sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen \
    && locale-gen \
    && rm -rf /var/lib/apt/lists/*

# Pin Wine 10.0 stable via apt preferences (matches gmag11 production exactly)
RUN mkdir -p /etc/apt/preferences.d && \
    printf "Package: winehq-stable wine-stable wine-stable-amd64 wine-stable-i386 wine-stable-amd64:amd64 wine-stable-i386:i386\nPin: version 10.0.0.0~bookworm-1\nPin-Priority: 1001\n" > /etc/apt/preferences.d/wine-pin

# WineHQ Debian bookworm repo
RUN dpkg --add-architecture i386 && \
    mkdir -pm755 /etc/apt/keyrings && \
    wget -qO /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
    wget -qNP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources

# Install Wine 10.0 + Openbox + tooling (NO TigerVNC — replaced by KasmVNC below)
RUN apt-get update && apt-get install -y --install-recommends \
        openbox obconf tint2 \
        websockify \
        python3 python3-pip \
        x11-apps net-tools dbus-x11 xfonts-base xauth \
        xterm git xdotool imagemagick procps \
        ssl-cert \
        winehq-stable=10.0.0.0~bookworm-1 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install KasmVNC 1.4.0 for bookworm (single architectural change vs 0.1.2)
RUN wget -q -O /tmp/kasmvnc.deb \
        https://github.com/kasmtech/KasmVNC/releases/download/v1.4.0/kasmvncserver_bookworm_1.4.0_amd64.deb && \
    apt-get update && \
    apt-get install -y --no-install-recommends /tmp/kasmvnc.deb && \
    rm -f /tmp/kasmvnc.deb && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Make the headless user
RUN useradd -m -s /bin/bash headless && \
    echo "headless ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    usermod -aG ssl-cert headless

# noVNC v1.4.0 + websockify v0.11.0 — git-tag pinned (still useful even if KasmVNC has built-in web)
RUN git clone --branch v1.4.0 --depth 1 https://github.com/novnc/noVNC.git /opt/noVNC && \
    git clone --branch v0.11.0 --depth 1 https://github.com/novnc/websockify.git /opt/noVNC/utils/websockify && \
    chown -R headless:headless /opt/noVNC

# Setup directories
RUN mkdir -p /home/headless/.vnc /home/headless/.config/openbox /Metatrader && \
    chown -R headless:headless /home/headless /Metatrader

# Scripts (KasmVNC variant uses a KasmVNC-specific start.sh)
COPY start.sh /start.sh
COPY bridge/rpyc_server.py /Metatrader/rpyc_server.py
RUN chmod +x /start.sh && \
    chown headless:headless /Metatrader/rpyc_server.py /start.sh

USER headless
WORKDIR /home/headless

EXPOSE 5901 6901 18812

HEALTHCHECK --interval=30s --timeout=10s --start-period=300s --retries=3 \
    CMD pgrep -f terminal64.exe >/dev/null && pgrep -f rpyc_server >/dev/null || exit 1

CMD ["/bin/bash", "/start.sh"]
