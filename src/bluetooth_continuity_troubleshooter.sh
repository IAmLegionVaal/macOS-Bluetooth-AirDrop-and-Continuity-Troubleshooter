#!/bin/bash
set -u

HOURS=24
OUTPUT_DIR=""

usage() { echo "Usage: bluetooth_continuity_troubleshooter.sh [--hours N] [--output DIR]"; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --hours) HOURS="${2:-24}"; shift 2 ;;
    --output) OUTPUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

case "$HOURS" in ''|*[!0-9]*) echo "--hours must be numeric" >&2; exit 2 ;; esac
[ "$(uname -s)" = "Darwin" ] || { echo "This tool must run on macOS." >&2; exit 1; }

STAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT_DIR="${OUTPUT_DIR:-./bluetooth-continuity-$STAMP}"
mkdir -p "$OUTPUT_DIR"
REPORT="$OUTPUT_DIR/bluetooth-continuity-report.txt"
CSV="$OUTPUT_DIR/components.csv"
JSON="$OUTPUT_DIR/summary.json"
ERRORS="$OUTPUT_DIR/command-errors.log"
: > "$REPORT"
: > "$ERRORS"
echo 'component,state,detail' > "$CSV"

section() {
  title="$1"
  shift
  { printf '\n===== %s =====\n' "$title"; "$@"; } >> "$REPORT" 2>> "$ERRORS" || true
}

record() {
  detail=$(printf '%s' "$3" | sed 's/"/""/g')
  printf '"%s","%s","%s"\n' "$1" "$2" "$detail" >> "$CSV"
}

section "Collection metadata" /bin/bash -c 'date -u +%Y-%m-%dT%H:%M:%SZ; hostname; sw_vers; id'
section "Bluetooth inventory" /usr/sbin/system_profiler SPBluetoothDataType
section "Wi-Fi and peer-to-peer interfaces" /bin/bash -c 'ifconfig -a | grep -E "^[a-z0-9]+:|status:|ether "; echo; networksetup -getairportpower en0 2>/dev/null || true'
section "Continuity-related processes" /bin/bash -c 'ps -Ao pid,user,etime,comm,args | grep -Ei "bluetoothd|sharingd|rapportd|AirDrop|handoff|identityservicesd" | grep -v grep || true'
section "AirDrop and Handoff preferences" /bin/bash -c 'defaults read com.apple.NetworkBrowser DisableAirDrop 2>/dev/null || true; defaults read com.apple.coreservices.useractivityd ActivityAdvertisingAllowed 2>/dev/null || true; defaults read com.apple.coreservices.useractivityd ActivityReceivingAllowed 2>/dev/null || true'
section "Recent Bluetooth and Continuity events" /bin/bash -c "/usr/bin/log show --last ${HOURS}h --style compact --predicate '(process == \"bluetoothd\") OR (process == \"sharingd\") OR (process == \"rapportd\") OR (eventMessage CONTAINS[c] \"AirDrop\") OR (eventMessage CONTAINS[c] \"Handoff\") OR (eventMessage CONTAINS[c] \"Continuity\")' 2>/dev/null | tail -n 4000"

BLUETOOTH_RUNNING=false
pgrep -x bluetoothd >/dev/null 2>&1 && BLUETOOTH_RUNNING=true
SHARINGD_RUNNING=false
pgrep -x sharingd >/dev/null 2>&1 && SHARINGD_RUNNING=true
RAPPORTD_RUNNING=false
pgrep -x rapportd >/dev/null 2>&1 && RAPPORTD_RUNNING=true
CONTROLLER_PRESENT=false
system_profiler SPBluetoothDataType 2>/dev/null | grep -q 'Bluetooth Controller' && CONTROLLER_PRESENT=true
P2P_PRESENT=false
ifconfig awdl0 >/dev/null 2>&1 && P2P_PRESENT=true

record "Bluetooth controller" "$CONTROLLER_PRESENT" "system_profiler"
record "bluetoothd" "$BLUETOOTH_RUNNING" "Bluetooth service"
record "sharingd" "$SHARINGD_RUNNING" "AirDrop service"
record "rapportd" "$RAPPORTD_RUNNING" "Continuity service"
record "awdl0" "$P2P_PRESENT" "Apple Wireless Direct Link"

OVERALL="Healthy"
if ! $CONTROLLER_PRESENT || ! $BLUETOOTH_RUNNING; then OVERALL="Attention required"; fi

cat > "$JSON" <<EOF
{
  "collected_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "hostname": "$(hostname)",
  "bluetooth_controller_present": $CONTROLLER_PRESENT,
  "bluetoothd_running": $BLUETOOTH_RUNNING,
  "sharingd_running": $SHARINGD_RUNNING,
  "rapportd_running": $RAPPORTD_RUNNING,
  "awdl_interface_present": $P2P_PRESENT,
  "overall_status": "$OVERALL"
}
EOF

printf '\nBluetooth, AirDrop and Continuity diagnostics completed: %s\n' "$OUTPUT_DIR" | tee -a "$REPORT"
