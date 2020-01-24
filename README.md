# SeisGram2K

SeisGram2K in a Docker container

## Quickstart
SeisGram2K Seismogram Viewer is an easy-to-use, platform-independent, Java software package for interactive visualization and analysis of earthquake seismograms developed by Anthony Lomax anthony[at]alomax.net.   
More info here:
- http://alomax.free.fr/seisgram/SeisGram2K.html

### Build docker
```
$ git clone git@gitlab.rm.ingv.it:docker/SeisGram2K.git
$ cd SeisGram2K
$ docker build --tag seisgram2k70 . 
```

### Run docker (Mac OSX)
#### XQuartz
Download and install **XQuartz**:
- https://www.xquartz.org

Enable flag: **Preferences** -> **Security** -> **Allow connections from network clients**.

#### Quick Run
Using the bash script `runSeisGram2KInDocker.sh` all steps are automatic:
```
$ ./runSeisGram2KInDocker.sh
```

#### Run by your self
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

Check **SeisGram2K** version:
```
$ docker run -it --rm -e DISPLAY=<your_ip_address>:0 -v /tmp/.X11-unix:/tmp/.X11-unix seisgram2k70 -version
```

Example:
```
$ docker run -it --rm -e DISPLAY=<your_ip_address>:0 -v /tmp/.X11-unix:/tmp/.X11-unix seisgram2k70 -seedlink=eidaws.ingv.it:18000#IV_ACER:HH?
```

### Run docker (Linux)
(under development)

# Contribute
Please, feel free to contribute.

# Credit
The SeisGram2K software was developed by Anthony Lomax anthony[at]alomax.net
