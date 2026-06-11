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
# STREAMS is optional: if it is omitted, the entrypoint asks the server which
# streams it offers and watches all channels of every station (up to
# MAX_AUTO_STATIONS). Convenient for small, single-station servers:
#
#   docker run --rm -p 8080:8080 \
#     -e SEEDLINK_HOST=basiluzzo.dyn.ingv.it:18000 \
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
# Used only when STREAMS is empty (auto-discovery): channel selector applied to
# every discovered station ("???" = all channels), and the maximum number of
# stations to auto-load before refusing (to avoid flooding the viewer).
AUTO_CHANNELS="${AUTO_CHANNELS:-???}"
MAX_AUTO_STATIONS="${MAX_AUTO_STATIONS:-10}"
# If set to any non-empty value, list the streams (stations + channels) offered
# by SEEDLINK_HOST and exit, instead of launching the viewer. Lets the user pick
# a STREAMS value before starting.
LIST_STREAMS="${LIST_STREAMS:-}"

readonly DISPLAY_NUM=":0"
readonly VNC_PORT=5900
readonly NOVNC_PORT=8080
export DISPLAY="${DISPLAY_NUM}"

# --- Validation --------------------------------------------------------------
if [[ -z "${SEEDLINK_HOST}" ]]; then
    echo "ERROR: SEEDLINK_HOST must be set (host:port)." >&2
    echo "Example:" >&2
    echo "  docker run --rm -p 8080:8080 \\" >&2
    echo "    -e SEEDLINK_HOST=hsl.int.ingv.it:18000 \\" >&2
    echo "    -e STREAMS=\"MN_AQU:HH?,IV_ROM9:HN?\" \\" >&2
    echo "    seisgram2k70" >&2
    exit 1
fi
if [[ "${SEEDLINK_HOST}" != *:* ]]; then
    echo "ERROR: SEEDLINK_HOST must be in 'host:port' form, got '${SEEDLINK_HOST}'." >&2
    exit 1
fi

# Connect to SEEDLINK_HOST, request the stream inventory (INFO STREAMS) and
# write the raw response to the file given as $1.
fetch_info() {
    local OUT="$1"
    local HOST="${SEEDLINK_HOST%:*}"
    local PORT="${SEEDLINK_HOST##*:}"
    if ! exec 3<>"/dev/tcp/${HOST}/${PORT}"; then
        echo "ERROR: cannot connect to SeedLink server ${SEEDLINK_HOST}." >&2
        exit 1
    fi
    printf 'HELLO\r\nINFO STREAMS\r\n' >&3
    timeout 8 cat <&3 > "${OUT}" || true
    exec 3>&- 3<&- || true
}

# Print one "NET_STA" per line (sorted, unique) from an INFO STREAMS dump ($1).
# The "name" and "network" attributes are extracted independently of their
# position in the <station> tag: some servers (e.g. Nanometrics Centaur) emit
# them after other attributes like begin_seq/description/end_seq, so a regex
# that assumes "<station name=... network=..." adjacency matches nothing.
parse_netsta() {
    grep -aoE '<station[^>]*>' "$1" \
        | awk '{
            net=""; sta="";
            if (match($0, /[[:space:]]network="[A-Z0-9]+"/)) net=substr($0,RSTART+10,RLENGTH-11);
            if (match($0, /[[:space:]]name="[A-Z0-9_]+"/))   sta=substr($0,RSTART+7,RLENGTH-8);
            if (net!="" && sta!="") print net"_"sta;
          }' | sort -u || true
}

# List every station with its channels, then exit. Triggered by LIST_STREAMS.
list_streams() {
    local TMP; TMP="$(mktemp)"
    echo "Listing streams available on ${SEEDLINK_HOST} ..." >&2
    fetch_info "${TMP}"
    # Walk the <station>/<stream> tags in document order, extracting name and
    # network independently of attribute order (see parse_netsta) and grouping
    # each station's channels (seedname) under it.
    grep -aoE '<station[^>]*>|seedname="[A-Z0-9?]+"' "${TMP}" \
        | awk '
            /^<station/ {
                net=""; sta="";
                if (match($0, /[[:space:]]network="[A-Z0-9]+"/)) net=substr($0,RSTART+10,RLENGTH-11);
                if (match($0, /[[:space:]]name="[A-Z0-9_]+"/))   sta=substr($0,RSTART+7,RLENGTH-8);
                cur=net"_"sta;
                if (cur!="_" && !(cur in seen)){seen[cur]=1; order[++n]=cur}
                next
            }
            /^seedname/ {
                if (cur=="_"||cur=="") next;
                c=$0; sub(/^seedname="/,"",c); sub(/"$/,"",c);
                k=cur"|"c; if(!(k in ck)){ck[k]=1; ch[cur]=ch[cur]" "c}
            }
            END{for(i=1;i<=n;i++) print "  "order[i]":"ch[order[i]]}'
    rm -f "${TMP}"
    echo "" >&2
    echo "Set STREAMS to a comma-separated list of NET_STA:CHAN?, e.g.:" >&2
    echo "  -e STREAMS=\"MN_AQU:HH?,IV_INTR:HH?\"" >&2
}

# Build a "NET_STA:???,..." selector for every station, when STREAMS is empty.
discover_streams() {
    local TMP NETSTA COUNT
    echo "STREAMS not set: discovering streams from ${SEEDLINK_HOST} ..." >&2
    TMP="$(mktemp)"
    fetch_info "${TMP}"
    NETSTA="$(parse_netsta "${TMP}")"
    rm -f "${TMP}"

    COUNT="$(printf '%s\n' "${NETSTA}" | grep -c . || true)"
    if [[ "${COUNT}" -eq 0 ]]; then
        echo "ERROR: no streams discovered on ${SEEDLINK_HOST}. Set STREAMS explicitly." >&2
        exit 1
    fi
    if [[ "${COUNT}" -gt "${MAX_AUTO_STATIONS}" ]]; then
        echo "ERROR: discovered ${COUNT} stations on ${SEEDLINK_HOST} (limit MAX_AUTO_STATIONS=${MAX_AUTO_STATIONS})." >&2
        echo "Loading them all would overwhelm the viewer. Pick from the stations below and" >&2
        echo "set STREAMS explicitly (e.g. -e STREAMS=\"NET_STA:HH?\"), or raise MAX_AUTO_STATIONS." >&2
        echo "" >&2
        echo "Available stations (showing up to 50; use -e LIST_STREAMS=1 for stations+channels):" >&2
        printf '%s\n' "${NETSTA}" | head -50 | sed -E 's/^/  /' >&2
        if [[ "${COUNT}" -gt 50 ]]; then
            echo "  ... and $((COUNT - 50)) more" >&2
        fi
        exit 1
    fi
    STREAMS="$(printf '%s\n' "${NETSTA}" | sed -E "s/\$/:${AUTO_CHANNELS}/" | paste -sd, -)"
    echo "Discovered ${COUNT} station(s): ${STREAMS}" >&2
}

if [[ -n "${LIST_STREAMS}" ]]; then
    list_streams
    exit 0
fi

if [[ -z "${STREAMS}" ]]; then
    discover_streams
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
