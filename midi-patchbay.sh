#!/bin/bash
# MIDI Patchbay: Connect all outputs to all inputs (all ports, no self-connections)

LOG_FILE="$HOME/midi-patchbay.log"
LOGGER_TAG="midi-patchbay"

timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

log() {
    local msg="$(timestamp) $1"
    echo "$msg" >> "$LOG_FILE"
    logger -t "$LOGGER_TAG" "$1"
}

cleanup_connections() {
    log "Cleaning up existing MIDI connections..."
    for src in $(aconnect -l | grep client | awk '{print $2}' | tr -d ':'); do
        for dst in $(aconnect -l | grep client | awk '{print $2}' | tr -d ':'); do
            aconnect -d $src $dst 2>/dev/null
        done
    done
}

apply_all_connections() {
    log "Connecting ALL outputs -> ALL inputs (excluding self-connections and system clients)..."

    # Get all output ports (client:port) excluding system clients
    # Note: Some virtual output ports appear in aconnect -i instead of -o due to ALSA quirks
    src_ports_from_o=$(aconnect -o | grep -v -E "(System|Midi Through|PipeWire-System|PipeWire-RT-Event)" | awk '/client/ {client=$2; sub(":","",client)} /^[[:space:]]*[0-9]+/ && client != "" {print client":"$1}')
    src_ports_from_i=$(aconnect -i | grep -E "(RtMidiOut|PythonMIDIClock)" | awk '/client/ {client=$2; sub(":","",client)} /^[[:space:]]*[0-9]+/ && client != "" {print client":"$1}')
    src_ports="$src_ports_from_o $src_ports_from_i"
    
    # Get all input ports (client:port) excluding system clients  
    dst_ports=$(aconnect -i | grep -v -E "(System|Midi Through|PipeWire-System|PipeWire-RT-Event)" | awk '/client/ {client=$2; sub(":","",client)} /^[[:space:]]*[0-9]+/ && client != "" {print client":"$1}')
    

    for src in $src_ports; do
        src_client=${src%%:*}
        for dst in $dst_ports; do
            dst_client=${dst%%:*}
            # Skip connecting device to itself
            if [ "$src_client" != "$dst_client" ]; then
                if aconnect "$src" "$dst" 2>>"$LOG_FILE"; then
                    log "Connected $src -> $dst"
                fi
            fi
        done
    done
}

log "=== MIDI Patchbay Triggered ==="
cleanup_connections
apply_all_connections
log "=== Done ==="
