FROM eclipse-temurin:17-jre

LABEL maintainer="Valentino Lauciani <valentino.lauciani@ingv.it>"

ENV DEBIAN_FRONTEND=noninteractive
ENV INITRD=No
ENV FAKE_CHROOT=1

RUN apt-get update \
    && apt-get dist-upgrade -y --no-install-recommends \
    && apt-get install -y --no-install-recommends \
        build-essential \
        vim \
        git \
        telnet \
        dnsutils \
        wget \
        ca-certificates \
        xvfb \
        x11vnc \
        x11-utils \
        novnc \
        websockify \
        procps \
    && rm -rf /var/lib/apt/lists/*

# Make http://localhost:8080/ open the noVNC client directly: a wrapper page
# puts the INGV logo in a dedicated top bar and embeds the auto-connecting
# noVNC client (no "Connect" landing button) in an iframe below it, so the logo
# never overlaps the SeisGram2K window.
#   autoconnect=true : start the session on load, skipping the Connect button
#   resize=scale     : keep the remote framebuffer at its native resolution
#                      (VNC_RESOLUTION, where the SeisGram2K window already fills
#                      it) and scale the image to the iframe, instead of growing
#                      the framebuffer and leaving grey desktop around the
#                      fixed-size window. Raise VNC_RESOLUTION for a sharper,
#                      higher-detail view (smaller relative UI).
#   reconnect=true   : re-establish the session if the websocket drops
COPY ingv-logo.png /usr/share/novnc/ingv-logo.png
RUN printf '%s\n' \
    '<!doctype html>' \
    '<html>' \
    '<head>' \
    '<meta charset="utf-8">' \
    '<title>SeisGram2K SeedLink Monitor</title>' \
    '<style>' \
    '  html,body{margin:0;height:100%;background:#000;overflow:hidden}' \
    '  body{display:flex;flex-direction:column}' \
    '  #bar{flex:0 0 auto;height:56px;background:#0b0b0b;display:flex;' \
    '       align-items:center;gap:12px;padding:0 14px;' \
    '       border-bottom:1px solid #222}' \
    '  #bar img{height:40px;width:auto}' \
    '  #bar span{color:#ccc;font:600 15px system-ui,sans-serif;' \
    '            letter-spacing:.3px}' \
    '  iframe{flex:1 1 auto;border:0;width:100%;display:block}' \
    '</style>' \
    '</head>' \
    '<body>' \
    '  <div id="bar">' \
    '    <img src="ingv-logo.png" alt="INGV"' \
    '         onerror="this.style.display='"'"'none'"'"'">' \
    '    <span>SeisGram2K &mdash; SeedLink Monitor</span>' \
    '  </div>' \
    '  <iframe src="vnc.html?autoconnect=true&resize=scale&reconnect=true"></iframe>' \
    '</body>' \
    '</html>' \
    > /usr/share/novnc/index.html

# Set .bashrc
RUN echo "" >> /root/.bashrc \
     && echo "alias ll='ls -l --color'" >> /root/.bashrc \
     && . /root/.bashrc

# Install SeisGram2K (vendored from http://alomax.free.fr/seisgram/)
WORKDIR /opt
COPY SeisGram2K70.jar /opt/SeisGram2K70.jar
RUN chmod +x /opt/SeisGram2K70.jar

ENV CLASSPATH=/opt/SeisGram2K70.jar

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
