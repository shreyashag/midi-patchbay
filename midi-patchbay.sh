#!/bin/bash
# MIDI Patchbay: Connect all outputs to all inputs (all ports, no self-connections)
# Supports daemon mode for automatic detection of new MIDI ports

LOG_FILE="$HOME/midi-patchbay.log"
LOGGER_TAG="midi-patchbay"
DAEMON_MODE=false
POLL_INTERVAL=2
CLIENTS_FILE="/proc/asound/seq/clients"

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

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -d, --daemon    Run in daemon mode (monitor for new MIDI ports)"
    echo "  -i, --interval  Poll interval in seconds for daemon mode (default: 2)"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Run once and exit"
    echo "  $0 --daemon     # Run as daemon, monitoring for new ports"
    echo "  $0 -d -i 5      # Run as daemon with 5-second poll interval"
}

get_client_list() {
    if [ -f "$CLIENTS_FILE" ]; then
        cat "$CLIENTS_FILE" | grep -E "Client|Port" | sort
    else
        aconnect -l | head -20 | sort
    fi
}

monitor_and_connect() {
    local last_clients=""
    local current_clients=""
    
    log "=== MIDI Patchbay Daemon Started ==="
    
    # Initial connection
    cleanup_connections
    apply_all_connections
    last_clients=$(get_client_list)
    
    while true; do
        sleep "$POLL_INTERVAL"
        current_clients=$(get_client_list)
        
        # Check if clients have changed
        if [ "$current_clients" != "$last_clients" ]; then
            log "=== MIDI Clients Changed - Reconnecting ==="
            cleanup_connections
            apply_all_connections
            last_clients="$current_clients"
        fi
    done
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--daemon)
            DAEMON_MODE=true
            shift
            ;;
        -i|--interval)
            POLL_INTERVAL="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
if [ "$DAEMON_MODE" = true ]; then
    monitor_and_connect
else
    log "=== MIDI Patchbay Triggered ==="
    cleanup_connections
    apply_all_connections
    log "=== Done ==="
fi
