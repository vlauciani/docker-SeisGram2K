<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [SeisGram2K](#seisgram2k)
  - [Quickstart](#quickstart)
    - [Build docker](#build-docker)
  - [Run docker (Mac OSX)](#run-docker-mac-osx)
    - [XQuartz](#xquartz)
    - [Quick Run](#quick-run)
    - [Run by your self](#run-by-your-self)
  - [Run docker (Linux)](#run-docker-linux)
  - [Example](#example)
    - [Quick run](#quick-run)
    - [Run by your self](#run-by-your-self-1)
- [Contribute](#contribute)
- [Credit](#credit)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# SeisGram2K

SeisGram2K in a Docker container

## Quickstart
SeisGram2K Seismogram Viewer is an easy-to-use, platform-independent, Java software package for interactive visualization and analysis of earthquake seismograms developed by Anthony Lomax anthony[at]alomax.net.   
More info here:
- http://alomax.free.fr/seisgram/SeisGram2K.html

More info about SeisGram2k:
- https://gitlab.rm.ingv.it/uf/doc/-/wikis/manuali/seisgram2k

### Build docker
```
$ git clone git@gitlab.rm.ingv.it:docker/SeisGram2K.git
$ cd SeisGram2K
$ docker build --tag seisgram2k70 . 
```

## Run docker (Mac OSX)
### XQuartz
Download and install **XQuartz**:
- https://www.xquartz.org

Enable flag: **Preferences** -> **Security** -> **Allow connections from network clients**.

### Quick Run
Using the bash script `runSeisGram2KInDocker.sh` all steps are automatic:
```
$ ./runSeisGram2KInDocker.sh
```

### Run by your self
Get your IP address and use it to start docker below:
```
$ ifconfig | grep "inet"
    . . .
	inet 10.0.4.75 netmask 0xff800000 broadcast 10.127.255.255
    . . .
$
```

run the command:
```
$ xhost + <your_ip_address>
```

open XQuartz App and start docker:
```
$ docker run -it --rm -e DISPLAY=<your_ip_address>:0 -v /tmp/.X11-unix:/tmp/.X11-unix seisgram2k70
```

## Run docker (Linux)
show waveform for station `psca` with a `window-length` of one day (72000 seconds), showing `backfill` data:

```
$ docker run -it --rm --net host -e DISPLAY seisgram2k70 -seedlink=10.140.1.14:18000#ZZ_psca:UTZ#72000 --seedlink.backfill=YES
```

see [here](http://alomax.free.fr/seisgram/ver70/SeisGram2KHelp.html) for a detailed list of launch parameters

## Example
### Quick run
SeisGram2k version:
```
$ ./runSeisGram2KInDocker.sh -version
```
View streams:
```
$ ./runSeisGram2KInDocker.sh -seedlink=discovery.ingv.it:39962#IV_PTRJ:HH?
```

### Run by your self

SeisGram2k version:
```
$ docker run -it --rm -e DISPLAY=<your_ip_address>:0 -v /tmp/.X11-unix:/tmp/.X11-unix seisgram2k70 -version
```
View seedlink streams:
```
$ docker run -it --rm -e DISPLAY=<your_ip_address>:0 -v /tmp/.X11-unix:/tmp/.X11-unix seisgram2k70 -seedlink=discovery.ingv.it:39962#IV_PTRJ:HH?
```

# Contribute
Please, feel free to contribute.

# Credit
The SeisGram2K software was developed by Anthony Lomax anthony[at]alomax.net
