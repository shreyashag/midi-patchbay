# 🎛️ MIDI Patchbay (All-to-All, Multi-Port) for Raspberry Pi

This project turns a Raspberry Pi into a **USB MIDI host patchbay**.  
It automatically connects **all MIDI outputs to all MIDI inputs across all available ports**, skipping self-connections to avoid feedback loops.  

Connections are applied at **boot** and re-applied automatically on **USB hotplug events** (when you plug/unplug MIDI devices).

---

## 📂 Repository Contents

- `midi-patchbay.sh` → Main script to manage ALSA MIDI connections (all outputs → all inputs, multi-port, safe mode)  
- `midi-patchbay.service` → Systemd unit to run the script at boot  

---

## ⚡ Features

- Cleans up all existing ALSA MIDI connections before applying new ones  
- Connects **every available MIDI OUT port to every available MIDI IN port**  
- Skips **self-connections** to prevent MIDI feedback loops  
- Handles devices with **multiple ports per client** (e.g. Helix, Launchpad, drum machines)  
- Automatically reconnects on USB hotplug (via `udev`)  
- Logs activity to:
  - `/var/log/midi-patchbay.log`
  - systemd journal (`journalctl`)  

---

## 🛠️ Installation

### 1. Clone repo
```bash
git clone https://github.com/YOUR_USERNAME/midi-patchbay.git
cd midi-patchbay
```

### 2. Install script
```bash
sudo cp midi-patchbay.sh /usr/local/bin/midi-patchbay.sh
sudo chmod +x /usr/local/bin/midi-patchbay.sh
```

### 3. Install systemd service
```bash
sudo cp midi-patchbay.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable midi-patchbay.service
```

### 4. Setup udev rule for hotplug
```bash
sudo tee /etc/udev/rules.d/99-midi-patchbay.rules <<'EOF'
ACTION=="add|remove", SUBSYSTEM=="sound", KERNEL=="card*", RUN+="/usr/local/bin/midi-patchbay.sh"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger
```

---

## 🎚️ How It Works

1. At boot (via `systemd`) or when USB MIDI devices are hotplugged (via `udev`), the script runs.  
2. It **removes all existing ALSA MIDI connections**.  
3. It finds all MIDI **output ports** and all MIDI **input ports**.  
4. It connects every output port to every input port (`aconnect OUT:PORT IN:PORT`).  
5. It **skips self-connections** (same client ID) to prevent feedback loops.  

---

## 🧪 Usage

Manually trigger:
```bash
sudo /usr/local/bin/midi-patchbay.sh
```

Reboot to auto-start:
```bash
sudo reboot
```

---

## 📜 Logs

- File log:
  ```bash
  tail -f /var/log/midi-patchbay.log
  ```
- Systemd journal:
  ```bash
  journalctl -fu midi-patchbay.service
  ```

---

## ❓ Troubleshooting

- **No connections happening?**  
  Check what devices are detected:
  ```bash
  aconnect -l
  ```
- **Device not ready at boot?**  
  Try re-plugging the device — the `udev` rule will re-trigger connections.  
- **Still stuck?**  
  Check logs:
  ```bash
  tail -n 50 /var/log/midi-patchbay.log
  ```

---

## 📄 License

MIT License – free to use, modify, and share.
