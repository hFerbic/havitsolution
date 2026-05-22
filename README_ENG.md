# 🎧 Havit Fuxi-H3 — Volume Fix on Linux (PipeWire)

> 🌐 **Versão em Português**: [README.md](README.md).

Fix for the bug where lowering the volume on Linux immediately mutes one of the headset channels, leaving only one side working at any volume below 100%.

Tested on: **Nobara Linux** with **KDE Plasma** and **PipeWire**.

---

## The Problem

When trying to reduce the volume of the Fuxi-H3 (via USB dongle), one of the channels is immediately muted — whether via mouse scroll, keyboard shortcut, or the headset's physical buttons. The audio only works on both sides with the volume at 100%.

### Root Cause

The Fuxi-H3 exposes two separate PCM controls to ALSA with an extremely limited volume range (`min=0, max=100` with only `0.00dB` to `0.39dB`). In practice, the hardware interprets any value below 100% as mute on one of the channels. The actual volume control is handled by the dongle's firmware, not by the Linux mixer.

Additionally, WirePlumber by default enables `api.alsa.soft-mixer = true` and `api.alsa.ignore-dB = true` for this device, which aggravates the behavior.

```
# amixer output revealing the problem:
numid=9, name='PCM Playback Volume'   min=0, max=100   dBminmax: 0.00dB ~ 0.39dB
numid=10, name='PCM Playback Volume', index=1   min=0, max=100   dBminmax: 0.00dB ~ 0.39dB

```

---

## The Solution

The fix has two parts:

1. **WirePlumber**: Configure the device to use soft-mixer (volume controlled via software by PipeWire), locking the hardware at 100%.
2. **udev**: Create a rule that automatically locks the hardware volume at 100% whenever the dongle is connected.

---

## Manual Installation

### 1. WirePlumber Rule

Create the configuration file:

```bash
mkdir -p ~/.config/wireplumber/wireplumber.conf.d/
nano ~/.config/wireplumber/wireplumber.conf.d/fuxi-h3-fix.conf

```

Paste the content:

```lua
monitor.alsa.rules = [
  {
    matches = [
      {
        device.vendor.id = "0x040b"
        device.product.id = "0x0897"
      }
    ]
    actions = {
      update-props = {
        api.alsa.soft-mixer       = true
        api.alsa.ignore-dB        = true
        api.alsa.enable-hw-volume = false
        api.alsa.headroom          = 0
      }
    }
  }
]

```

Restart the audio services:

```bash
systemctl --user restart wireplumber pipewire pipewire-pulse

```

### 2. Hardware Volume Locking Script

Create the script:

```bash
sudo nano /usr/local/bin/fuxi-h3-volume-fix.sh

```

Paste the content:

```bash
#!/bin/bash
sleep 2
CARD=$(amixer -l | grep -i 'FuxiH3\|Fuxi-H3' | head -1 | grep -o 'card [0-9]*' | grep -o '[0-9]*')
amixer -c "$CARD" sset 'PCM',0 100%,100%
amixer -c "$CARD" sset 'PCM',1 100%

```

Grant execution permission:

```bash
sudo chmod +x /usr/local/bin/fuxi-h3-volume-fix.sh

```

### 3. udev Rule (automatically runs the script when connecting the dongle)

```bash
sudo nano /etc/udev/rules.d/99-fuxi-h3.rules

```

Paste:

```
ACTION=="add", SUBSYSTEM=="sound", ATTRS{idVendor}=="040b", ATTRS{idProduct}=="0897", RUN+="/usr/local/bin/fuxi-h3-volume-fix.sh"

```

Reload udev rules:

```bash
sudo udevadm control --reload-rules

```

---

## Automatic Installation

Use the installation script included in this repository:

```bash
git clone https://github.com/hFerbic/havitsolution
cd havitsolution
chmod +x install.sh
./install.sh

```

---

## Verifying If It Worked

After installation, verify if the properties were applied:

```bash
pactl list sinks | grep -A 3 "soft-mixer\|ignore-dB\|hw-volume"

```

The expected output is:

```
api.alsa.soft-mixer = "true"
api.alsa.ignore-dB = "true"
api.alsa.enable-hw-volume = "false"

```

---

## Compatibility with Other Connection Modes

| Connection Mode | Affected by this fix? |
| --- | --- |
| USB Dongle (2.4GHz) | ✅ Yes — that is exactly what it is for |
| USB Cable | ⚠️ Only if it uses the same `idVendor:idProduct` (verify with `lsusb`) |
| Analog P3 | ❌ No — goes directly to the motherboard jack |
| Bluetooth | ❌ No — appears as a completely different device |

To verify if the USB cable uses the same ID:

```bash
lsusb | grep -i "040b\|Weltrend\|Fuxi\|XiiSound"

```

---

## Device Information

| Field | Value |
| --- | --- |
| Product | Havit Fuxi-H3 |
| Vendor ID | `0x040b` (Weltrend Semiconductor) |
| Product ID | `0x0897` |
| Driver | `snd_usb_audio` |
| Interface | USB (2.4GHz dongle) |

---

## Uninstallation

```bash
rm -f ~/.config/wireplumber/wireplumber.conf.d/fuxi-h3-fix.conf
sudo rm -f /usr/local/bin/fuxi-h3-volume-fix.sh
sudo rm -f /etc/udev/rules.d/99-fuxi-h3.rules
sudo udevadm control --reload-rules
systemctl --user restart wireplumber pipewire pipewire-pulse

```

---

## Contributions

If you have a Fuxi-H3 and tested it on another distro or desktop environment, open an issue or PR with the results!
