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

# Make http://localhost:8080/ open the noVNC client directly.
RUN ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html

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
