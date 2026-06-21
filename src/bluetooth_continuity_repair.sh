#!/bin/bash
set -u

DO_REPAIR=false
DRY_RUN=false
ASSUME_YES=false
CYCLE_WIFI=false
OUTPUT_DIR=""
FAILURES=0
ACTIONS=0

usage() {
  cat <<'EOF'
Usage: bluetooth_continuity_repair.sh [options]

  --repair       Restart Bluetooth, AirDrop and Continuity services.
  --cycle-wifi   Also turn Wi-Fi off and on. This disconnects active Wi-Fi sessions.
  --dry-run      Show actions without changing the Mac.
  --yes          Skip confirmation prompts.
  --output DIR   Save logs and verification output in DIR.
  -h, --help     Show help.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repair) DO_REPAIR=true; shift ;;
    --cycle-wifi) CYCLE_WIFI=true; DO_REPAIR=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --yes) ASSUME_YES=true; shift ;;
    --output) OUTPUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[ "$(uname -s)" = "Darwin" ] || { echo "This tool must run on macOS." >&2; exit 1; }

STAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT_DIR="${OUTPUT_DIR:-./bluetooth-continuity-repair-$STAMP}"
mkdir -p "$OUTPUT_DIR"
LOG="$OUTPUT_DIR/repair.log"
VERIFY="$OUTPUT_DIR/verification.txt"
: > "$LOG"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"; }
confirm() {
  $ASSUME_YES && return 0
  printf '%s [y/N]: ' "$1"
  read -r answer
  case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}
run_action() {
  description="$1"; shift
  ACTIONS=$((ACTIONS + 1)); log "$description"
  if $DRY_RUN; then
    printf 'DRY-RUN:' >> "$LOG"; for arg in "$@"; do printf ' %q' "$arg" >> "$LOG"; done; printf '\n' >> "$LOG"; return 0
  fi
  if "$@" >> "$LOG" 2>&1; then log "SUCCESS: $description"; return 0; fi
  FAILURES=$((FAILURES + 1)); log "WARNING: $description failed"; return 1
}
run_admin() {
  description="$1"; shift
  if [ "$(id -u)" -eq 0 ]; then run_action "$description" "$@"; else run_action "$description" /usr/bin/sudo "$@"; fi
}
get_wifi_device() {
  /usr/sbin/networksetup -listallhardwareports 2>/dev/null | awk '/Hardware Port: (Wi-Fi|AirPort)/ {getline; print $2; exit}'
}
verify() {
  wifi_device=$(get_wifi_device)
  {
    echo "Collected: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Host: $(hostname)"
    echo
    echo "Bluetooth inventory:"
    /usr/sbin/system_profiler SPBluetoothDataType 2>/dev/null | head -n 350
    echo
    echo "Relevant processes:"
    ps -Ao pid,user,etime,comm,args | grep -Ei 'bluetoothd|sharingd|rapportd|AirPlay|nearbyd|p2p' | grep -v grep || true
    echo
    echo "AWDL interface:"
    /sbin/ifconfig awdl0 2>/dev/null || echo "awdl0 is not currently present"
    echo
    echo "Wi-Fi state:"
    if [ -n "$wifi_device" ]; then /usr/sbin/networksetup -getairportpower "$wifi_device" 2>/dev/null; else echo "Wi-Fi interface not found"; fi
  } > "$VERIFY" 2>&1
}

verify
if ! $DO_REPAIR; then log "Verification-only mode completed. Use --repair to apply repairs."; exit 0; fi
if ! confirm "Restart Bluetooth, AirDrop and Continuity services? Active transfers may be interrupted."; then log "Repair cancelled by user."; exit 0; fi

run_admin "Restarting Bluetooth service" /bin/launchctl kickstart -k system/com.apple.bluetoothd || \
  run_admin "Requesting Bluetooth process restart" /usr/bin/killall bluetoothd || true

for process_name in sharingd rapportd nearbyd; do
  if pgrep -x "$process_name" >/dev/null 2>&1; then run_action "Restarting $process_name" /usr/bin/killall "$process_name" || true; fi
done

if $CYCLE_WIFI; then
  wifi_device=$(get_wifi_device)
  if [ -z "$wifi_device" ]; then
    FAILURES=$((FAILURES + 1)); log "WARNING: Wi-Fi interface was not found."
  elif confirm "Cycle Wi-Fi on $wifi_device now? This will disconnect the network temporarily."; then
    run_admin "Turning Wi-Fi off on $wifi_device" /usr/sbin/networksetup -setairportpower "$wifi_device" off || true
    if ! $DRY_RUN; then sleep 3; fi
    run_admin "Turning Wi-Fi on on $wifi_device" /usr/sbin/networksetup -setairportpower "$wifi_device" on || true
  fi
fi

if ! $DRY_RUN; then sleep 6; fi
verify

BT_OK=false
pgrep -x bluetoothd >/dev/null 2>&1 && BT_OK=true
if ! $BT_OK; then FAILURES=$((FAILURES + 1)); log "WARNING: bluetoothd is not running after repair."; fi

if [ "$FAILURES" -gt 0 ]; then log "Repair completed with $FAILURES warning(s)."; exit 1; fi
log "Repair completed successfully. Actions performed: $ACTIONS"
exit 0
