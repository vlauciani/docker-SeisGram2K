FROM alpine

LABEL maintainer="Valentino Lauciani <valentino.lauciani@ingv.it>"

ENV DEBIAN_FRONTEND=noninteractive
ENV INITRD No
ENV FAKE_CHROOT 1

RUN apk add --no-cache \
	procps \
	sudo \
	bash \
	openssh-client \
	git \
	ttf-dejavu \
	openjdk8-jre \
	vim \
	wget \
	xterm

# Set .bashrc
RUN echo "" >> /root/.bashrc \
     && echo "alias ll='ls -l --color'" >> /root/.bashrc \
     && . /root/.bashrc

# Install SeisGram2K
WORKDIR /opt
RUN wget "http://alomax.free.fr/seisgram/beta/SeisGram2K70.jar" \
     && chmod +x /opt/SeisGram2K70.jar 

COPY ./test.sh /opt/
ENV CLASSPATH=/opt/SeisGram2K70.jar

ENTRYPOINT ["java", "net.alomax.seisgram2k.SeisGram2K"]
