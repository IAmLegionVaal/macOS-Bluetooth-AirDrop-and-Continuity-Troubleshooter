# macOS Bluetooth, AirDrop and Continuity Troubleshooter

A read-only Bash toolkit for collecting Bluetooth hardware, paired-device, AirDrop, Handoff, Continuity, Wi-Fi dependency, service, and recent event evidence.

## Usage

```bash
chmod +x src/bluetooth_continuity_troubleshooter.sh
./src/bluetooth_continuity_troubleshooter.sh --hours 24
```

## Checks performed

- Bluetooth controller and device inventory
- Bluetooth, sharing, AirDrop, and Continuity processes
- Wi-Fi interface and peer-to-peer interface state
- Handoff and AirDrop preference indicators
- Recent Bluetooth, sharingd, AirDrop, and Continuity events
- Text, CSV, and JSON reports

## Safety

The script does not pair or unpair devices, reset Bluetooth, change AirDrop visibility, toggle Wi-Fi, or alter Handoff settings.

## Author

Dewald Pretorius — L2 IT Support Engineer
