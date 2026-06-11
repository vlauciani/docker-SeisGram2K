#!/usr/bin/env bash
#
# Entrypoint for the SeisGram2K SeedLink Monitor container.
#
# Runs the SeisGram2K Swing GUI on a virtual X display (Xvfb) and exposes it
# in a web browser through x11vnc + noVNC. The SeedLink connection is driven
# entirely by environment variables, so the user only needs:
#
#   docker run --rm -p 8080:8080 \
#     -e SEEDLINK_HOST=hsl.int.ingv.it:18000 \
#     -e STREAMS="MN_AQU:HH?,IV_ROM9:HN?" \
#     seisgram2k70
#
# then open http://localhost:8080 in a browser.
#
set -euo pipefail

# --- Configuration (overridable via -e) --------------------------------------
SEEDLINK_HOST="${SEEDLINK_HOST:-}"
STREAMS="${STREAMS:-}"
REALTIME_UPDATE="${REALTIME_UPDATE:-5.0}"
SEEDLINK_BUFFER="${SEEDLINK_BUFFER:-1200#25000#25000}"
SEEDLINK_GROUPCHANNELS="${SEEDLINK_GROUPCHANNELS:-YES}"
VNC_RESOLUTION="${VNC_RESOLUTION:-1440x900}"
# Main window size at startup, as horizontal,vertical fraction of the screen.
# 1.0,1.0 makes SeisGram2K fill the virtual display natively. This must be set
# at startup: resizing the window afterwards (e.g. via a window manager) leaves
# the Swing content blank under Xvfb, so no window manager is used.
DISPLAY_SIZE="${DISPLAY_SIZE:-1.0,1.0}"

readonly DISPLAY_NUM=":0"
readonly VNC_PORT=5900
readonly NOVNC_PORT=8080
export DISPLAY="${DISPLAY_NUM}"

# --- Validation --------------------------------------------------------------
if [[ -z "${SEEDLINK_HOST}" || -z "${STREAMS}" ]]; then
    echo "ERROR: SEEDLINK_HOST and STREAMS must be set." >&2
    echo "Example:" >&2
    echo "  docker run --rm -p 8080:8080 \\" >&2
    echo "    -e SEEDLINK_HOST=hsl.int.ingv.it:18000 \\" >&2
    echo "    -e STREAMS=\"MN_AQU:HH?,IV_ROM9:HN?\" \\" >&2
    echo "    seisgram2k70" >&2
    exit 1
fi

# Assemble the SeisGram2K -seedlink argument:
#   host:port#NET_STA:CHAN?,...#<buffer fields>
readonly SEEDLINK_ARG="${SEEDLINK_HOST}#${STREAMS}#${SEEDLINK_BUFFER}"

# --- Process supervision -----------------------------------------------------
# Any background process dying brings the whole container down (wait -n).
PIDS=()

cleanup() {
    for PID in "${PIDS[@]}"; do
        kill "${PID}" 2>/dev/null || true
    done
}
trap cleanup EXIT

echo "Starting Xvfb on ${DISPLAY_NUM} (${VNC_RESOLUTION}x24) ..."
Xvfb "${DISPLAY_NUM}" -screen 0 "${VNC_RESOLUTION}x24" -nolisten tcp &
PIDS+=("$!")

# Wait for the X display to become available.
for _ in $(seq 1 50); do
    if xdpyinfo -display "${DISPLAY_NUM}" >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done

echo "Starting x11vnc on port ${VNC_PORT} ..."
x11vnc -display "${DISPLAY_NUM}" -rfbport "${VNC_PORT}" \
    -forever -shared -nopw -quiet -noxdamage &
PIDS+=("$!")

echo "Starting noVNC on port ${NOVNC_PORT} ..."
websockify --web /usr/share/novnc "${NOVNC_PORT}" "localhost:${VNC_PORT}" &
PIDS+=("$!")

echo "Launching SeisGram2K SeedLink Monitor:"
echo "  -seedlink \"${SEEDLINK_ARG}\""
# -Dsun.java2d.pmoffscreen=false forces direct rendering to the window;
# without it Swing draws to an offscreen pixmap that never reaches the
# Xvfb framebuffer, leaving x11vnc/noVNC showing a blank grey window.
java -Dsun.java2d.pmoffscreen=false \
    -cp /opt/SeisGram2K70.jar net.alomax.seisgram2k.SeisGram2K \
    -display.size="${DISPLAY_SIZE}" \
    -seedlink "${SEEDLINK_ARG}" \
    -seedlink.groupchannels "${SEEDLINK_GROUPCHANNELS}" \
    -commands.onread rmean \
    -realtime.update "${REALTIME_UPDATE}" \
    -seedlink.backfill=YES &
PIDS+=("$!")

echo "Ready. Open http://localhost:${NOVNC_PORT} in your browser."

# Exit (and trigger cleanup) as soon as any supervised process terminates.
wait -n
