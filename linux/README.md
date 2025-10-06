# Jam Git-Ops — Linux

This folder contains everything used to configure and maintain the **Jam Debian machines**.  
Each device pulls these files automatically on **boot**, applies updates if the version has changed, and runs cleanup or maintenance tasks every startup.

---

## ⚙️ How it Works

- On every boot, the systemd service **`jam-gitops.service`** runs.
- It checks this folder on GitHub (`nirj-infra/linux/`):
  - If `version.txt` changed → downloads new files, swaps them into `/opt/jam-gitops/`, then runs `main.sh`.
  - Regardless of version → always runs `boot.sh`.
- All output goes to the system journal:
  ```bash
  journalctl -u jam-gitops.service -f

## Folder Structure

linux/
│
├── main.sh               # Runs only when version.txt changes
├── boot.sh               # Always runs on boot (calls scripts in boot/)
├── version.txt           # Bump this to trigger a full update
│
├── boot/                 # Per-boot helper scripts
│   ├── 00-env.sh         # Shared variables & helper functions
│   ├── 10-clean-home.sh  # Wipes user files each boot
│   ├── 20-desktop-whitelist.sh # Keeps only approved desktop icons
│   └── allowed_shortcuts.txt   # List of allowed Desktop filenames
│
└── scripts/              # Extra shell scripts referenced by main.sh or boot helpers

## What Runs When

| Stage            | Script                       | When it Runs                      | Purpose                                       |
| ---------------- | ---------------------------- | --------------------------------- | --------------------------------------------- |
| Versioned update | `main.sh`                    | Only when `version.txt` changes   | Install packages, add features, large updates |
| Per-boot tasks   | `boot.sh`                    | Every boot                        | Reset environment, enforce rules, cleanup     |
| Boot helpers     | `boot/*.sh`                  | In numeric order (00-, 10-, 20-…) | Modular per-boot logic                        |
| Whitelist        | `boot/allowed_shortcuts.txt` | Every boot                        | Controls which desktop icons remain           |


## Script Numbering

| Prefix | Purpose                   | Example                   |
| ------ | ------------------------- | ------------------------- |
| `00-`  | Core setup or environment | `00-env.sh`               |
| `10-`  | Early cleanup/prep        | `10-clean-home.sh`        |
| `20-`  | Main logic                | `20-desktop-whitelist.sh` |


## Desktop Whitelist
boot/allowed_shortcuts.txt lists the only files allowed to remain on the desktop.
Anything else is deleted on boot.
It is one file per line. Example:

```
code.desktop
net.sonic_pi.SonicPi.desktop
```

## What the Device Does Each Boot
1. Waits for the network.
2. Cleans /home/jam — removes user-added files and caches.
3. Removes non-whitelisted Desktop shortcuts.
4. Seeds curated shortcuts from files/desktop/ (optional).
5. Ensures correct folder structure and permissions.
6. Logs everything to the system journal.

## Notes
When making a change. You need to bump the version.txt file in order for the devices to apply the changes.
To make the devices apply the changes, either reboot, or run: `sudo systemctl start jam-gitops.service`