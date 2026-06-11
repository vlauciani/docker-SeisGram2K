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

# Make http://localhost:8080/ open the noVNC client and connect immediately,
# skipping the landing page with the "Connect" button. autoconnect starts the
# session on load; resize=remote keeps the SeisGram2K window fit to the browser;
# reconnect re-establishes the session if the websocket drops.
RUN printf '%s\n' \
    '<!doctype html>' \
    '<meta http-equiv="refresh" content="0; url=vnc.html?autoconnect=true&resize=remote&reconnect=true">' \
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
