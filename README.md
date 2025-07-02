# Omarchy

Turn a fresh Arch installation into a fully-configured, beautiful, and modern web development system based on Hyprland by running a single command. That's the one-line pitch for Omarchy (like it was for Omakub). No need to write bespoke configs for every essential tool just to get started or to be up on all the latest command-line tools. Omarchy is an opinionated take on what Linux can be at its best.

## Prerequisites

### Connect to WiFi (if needed)

If you need to connect to WiFi before installation, use `iwctl`:

```bash
# Start iwctl
iwctl

# List wireless devices (note the device name, usually wlan0)
device list

# Scan for networks
station wlan0 scan

# List available networks
station wlan0 get-networks

# Connect to your network
station wlan0 connect "Your-WiFi-Name"

# Exit iwctl
exit

# Verify connection
ping -c 3 google.com
```

## Installation

Run this single command on a fresh Arch Linux installation:

```bash
bash <(curl -s https://raw.githubusercontent.com/an1shthomas/omarchy/my-customization-rev1/boot.sh)
```

This customized version includes:
- **Smart GPU Driver Selection**: Automatically uses `nvidia-open-dkms` for modern RTX cards (20xx, 30xx, 40xx, 50xx+) and `nvidia-dkms` for legacy GTX cards
- **Optimized Installation Order**: GPU drivers are installed early to prevent graphics issues
- **Future-Proof**: Supports upcoming GPU generations and follows NVIDIA's official recommendations

Read more at [omarchy.org](https://omarchy.org).

## License

Omarchy is released under the [MIT License](https://opensource.org/licenses/MIT).
