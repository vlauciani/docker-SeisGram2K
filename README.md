# docker_SeisGram2K

SeisGram2K SeedLink Monitor in a Docker container, viewable in a web browser.

## Quickstart
SeisGram2K Seismogram Viewer is an easy-to-use, platform-independent, Java software package for interactive visualization and analysis of earthquake seismograms developed by Anthony Lomax anthony[at]alomax.net.
More info here:
- http://alomax.free.fr/seisgram/SeisGram2K.html

This image runs SeisGram2K in **SeedLink Monitor mode** on a virtual X display
(Xvfb) and streams the GUI to your browser through x11vnc + noVNC. No XQuartz,
no VNC client, no X11 forwarding: just `docker run` and open a browser. It runs
natively on Apple Silicon (arm64) and Intel (amd64).

### Build docker
```
$ git clone git@gitlab.rm.ingv.it:uf/docker_SeisGram2K.git
$ cd docker_SeisGram2K
$ docker build --tag seisgram2k70 .
```

### Run docker (browser, plug-and-play)
Start the container, passing the SeedLink server and the streams you want to
watch via environment variables:
```
$ docker run --rm -p 8080:8080 \
    -e SEEDLINK_HOST=hsl.int.ingv.it:18000 \
    -e STREAMS="MN_AQU:HH?,IV_ROM9:HN?" \
    seisgram2k70
```
Then open the viewer in your browser:
- http://localhost:8080

Waveforms flow in near-realtime as SeedLink packets arrive.

#### Environment variables
| Variable          | Required | Default            | Description                                                        |
|-------------------|----------|--------------------|--------------------------------------------------------------------|
| `SEEDLINK_HOST`   | yes      | -                  | SeedLink server as `host:port` (e.g. `hsl.int.ingv.it:18000`)      |
| `STREAMS`         | yes      | -                  | Comma-separated `NET_STA:CHAN?` selectors (e.g. `IV_AQU:HH?`)      |
| `REALTIME_UPDATE` | no       | `5.0`              | Display refresh interval, in seconds                               |
| `VNC_RESOLUTION`  | no       | `1440x900`         | Virtual display / browser canvas size                              |
| `DISPLAY_SIZE`    | no       | `1.0,1.0`          | Main window size at startup, as `horizontal,vertical` screen fraction |
| `SEEDLINK_GROUPCHANNELS` | no | `YES`             | Group the channels of each station together                        |
| `SEEDLINK_BUFFER` | no       | `1200#25000#25000` | SeisGram2K SeedLink buffer fields                                  |

#### Stream selector syntax
The `STREAMS` value uses the SeisGram2K SeedLink selector format
`NET_STA:CHAN?`, where `?` is a single-character wildcard. Examples:
- `MN_AQU:HH?`             - broadband (HH) components of station AQU, network MN
- `IV_ROM9:HN?`            - accelerometer (HN) components of station ROM9, network IV
- `MN_AQU:HH?,IV_ROM9:HN?` - two stations at once
- `IV_*:HH?`               - all IV stations with HH channels (can be heavy)

The network code and channel band must match what the station actually streams:
e.g. AQU lives on network `MN` (not `IV`), and ROM9 only has `HN?`
(accelerometer) channels, not `HH?`. If the waveforms do not appear, the
selector is almost always the cause. List the streams a server offers with:
```
slinktool -Q hsl.int.ingv.it:18000
```

### Run docker (Linux)
Same as above: `docker run --rm -p 8080:8080 -e SEEDLINK_HOST=... -e STREAMS="..." seisgram2k70`,
then open http://localhost:8080. No `xhost`/X11 setup is needed.

# Contribute
Please, feel free to contribute.

# Credit
The SeisGram2K software was developed by Anthony Lomax anthony[at]alomax.net.
SeisGram2K supports SeedLink Monitor mode:
- http://alomax.free.fr/seisgram/seedlink/
