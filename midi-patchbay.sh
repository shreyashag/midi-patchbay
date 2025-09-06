#!/bin/bash
# MIDI Patchbay: Connect all outputs to all inputs (all ports, no self-connections)

LOG_FILE="/var/log/midi-patchbay.log"
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
    src_ports=$(aconnect -o | awk '
        /client/ {
            client=$2; 
            sub(":","",client);
            # Extract client name from single quotes
            match($0, /'\''([^'\'']*)'\''/, name_match);
            client_name = name_match[1];
            # Skip system clients
            if (client_name == "System" || client_name == "Midi Through" || 
                client_name == "PipeWire-System" || client_name == "PipeWire-RT-Event") {
                skip_client = 1;
            } else {
                skip_client = 0;
            }
        } 
        /^[[:space:]]*[0-9]+/ && !skip_client {
            print client":"$1
        }')
    
    # Get all input ports (client:port) excluding system clients
    dst_ports=$(aconnect -i | awk '
        /client/ {
            client=$2; 
            sub(":","",client);
            # Extract client name from single quotes
            match($0, /'\''([^'\'']*)'\''/, name_match);
            client_name = name_match[1];
            # Skip system clients
            if (client_name == "System" || client_name == "Midi Through" || 
                client_name == "PipeWire-System" || client_name == "PipeWire-RT-Event") {
                skip_client = 1;
            } else {
                skip_client = 0;
            }
        } 
        /^[[:space:]]*[0-9]+/ && !skip_client {
            print client":"$1
        }')

    for src in $src_ports; do
        src_client=${src%%:*}
        for dst in $dst_ports; do
            dst_client=${dst%%:*}
            # Skip connecting device to itself
            if [[ "$src_client" != "$dst_client" ]]; then
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
