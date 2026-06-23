# macOS Bluetooth, AirDrop and Continuity Troubleshooter

A macOS support toolkit for diagnosing and repairing common Bluetooth, AirDrop, Handoff and Continuity problems.

## Diagnostic script

```bash
chmod +x src/bluetooth_continuity_troubleshooter.sh
./src/bluetooth_continuity_troubleshooter.sh --hours 24
```

The diagnostic script collects Bluetooth hardware and device data, AirDrop and Continuity service state, Wi-Fi and AWDL information, preference indicators and recent events.

## Repair script

Preview the repair:

```bash
chmod +x src/bluetooth_continuity_repair.sh
./src/bluetooth_continuity_repair.sh --repair --dry-run
```

Apply the service repair:

```bash
./src/bluetooth_continuity_repair.sh --repair
```

Apply the repair and also cycle Wi-Fi:

```bash
./src/bluetooth_continuity_repair.sh --repair --cycle-wifi
```

## What the repair does

- Restarts the Bluetooth system service.
- Restarts `sharingd`, `rapportd` and `nearbyd` when they are running.
- Can optionally cycle the detected Wi-Fi interface to recover AirDrop and Continuity dependencies.
- Supports dry-run and confirmation controls.
- Writes a repair log and post-repair verification report.
- Returns clear success, warning and invalid-argument exit codes.

## Safety and limitations

The tool does not unpair devices, erase Bluetooth preferences or change AirDrop visibility. Cycling Wi-Fi temporarily disconnects active network sessions and therefore requires confirmation. Hardware faults, radio interference and unsupported devices may still need manual investigation.

## Maintainer

IAmLegionVaal
