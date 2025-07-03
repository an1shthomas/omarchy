#!/bin/bash

# Check if NVIDIA GPU is present
if ! lspci | grep -i nvidia > /dev/null && [ ! -f /proc/driver/nvidia/version ]; then
    echo "No NVIDIA GPU detected, skipping NVIDIA setup..."
    exit 0
fi

echo "NVIDIA GPU detected, setting up NVIDIA configuration..."

# Detect GPU architecture to choose appropriate driver
GPU_INFO=$(lspci -nn | grep -i nvidia | grep VGA)
echo "Detected GPU: $GPU_INFO"

# Determine driver based on GPU architecture
# RTX 20xx, 30xx, 40xx, 50xx+ (Turing, Ampere, Ada Lovelace, Blackwell+) -> nvidia-open-dkms (recommended)
# GTX 16xx, 10xx, 9xx and older -> nvidia-dkms (legacy support)
if echo "$GPU_INFO" | grep -E "(RTX [2-9][0-9]{3}|RTX [A-Z0-9]+)" > /dev/null; then
    NVIDIA_DRIVER="nvidia-open-dkms"
    echo "Modern GPU detected - using nvidia-open-dkms (recommended by NVIDIA)"
else
    NVIDIA_DRIVER="nvidia-dkms"
    echo "Legacy GPU detected - using nvidia-dkms"
fi

# Enable multilib repository if not already enabled
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    echo "Enabling multilib repository..."
    sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
    sudo pacman -Sy
fi

# Install kernel headers (required for DKMS)
echo "Installing kernel headers for DKMS..."
KERNEL_PACKAGES=$(pacman -Q | grep -E '^linux ' | awk '{print $1}')
for kernel in $KERNEL_PACKAGES; do
    if [ "$kernel" = "linux" ]; then
        yay -S --noconfirm --needed linux-headers
    elif [ "$kernel" = "linux-lts" ]; then
        yay -S --noconfirm --needed linux-lts-headers
    elif [ "$kernel" = "linux-zen" ]; then
        yay -S --noconfirm --needed linux-zen-headers
    elif [ "$kernel" = "linux-hardened" ]; then
        yay -S --noconfirm --needed linux-hardened-headers
    fi
done

# Install NVIDIA packages following Hyprland guide
echo "Installing NVIDIA packages..."
yay -S --noconfirm --needed \
    $NVIDIA_DRIVER \
    nvidia-utils \
    egl-wayland

# Install 32-bit packages if multilib is available
if pacman -Sl multilib &>/dev/null; then
    echo "Installing 32-bit NVIDIA libraries..."
    yay -S --noconfirm --needed lib32-nvidia-utils
else
    echo "Multilib repository not available, skipping 32-bit libraries..."
fi

# Create modprobe config for DRM modeset (following Hyprland guide)
echo "Configuring NVIDIA DRM modeset..."
echo "options nvidia_drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf

# Add NVIDIA modules to initramfs (following Hyprland guide)
echo "Adding NVIDIA modules to initramfs..."
if ! grep -q "^MODULES=(.*nvidia.*)" /etc/mkinitcpio.conf; then
    sudo sed -i 's/^MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf
    sudo mkinitcpio -P
fi

# Add kernel parameters for NVIDIA
echo "Adding NVIDIA kernel parameters..."
if [ -f /etc/default/grub ]; then
    # GRUB bootloader
    if ! grep -q "nvidia.NVreg_PreserveVideoMemoryAllocations=1" /etc/default/grub; then
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"/' /etc/default/grub
        sudo grub-mkconfig -o /boot/grub/grub.cfg
    fi
elif [ -d /boot/loader/entries ]; then
    # systemd-boot
    for entry in /boot/loader/entries/*.conf; do
        if [ -f "$entry" ] && ! grep -q "nvidia.NVreg_PreserveVideoMemoryAllocations=1" "$entry"; then
            sudo sed -i '/^options/ s/$/ nvidia.NVreg_PreserveVideoMemoryAllocations=1/' "$entry"
        fi
    done
elif [ -f /boot/refind_linux.conf ]; then
    # rEFInd
    if ! grep -q "nvidia.NVreg_PreserveVideoMemoryAllocations=1" /boot/refind_linux.conf; then
        sudo sed -i 's/"$/ nvidia.NVreg_PreserveVideoMemoryAllocations=1"/' /boot/refind_linux.conf
    fi
else
    echo "Warning: Unknown bootloader detected. Please manually add this kernel parameter:"
    echo "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
fi

# Create Pacman hook for nvidia modules
echo "Creating Pacman hook for NVIDIA modules..."
sudo mkdir -p /etc/pacman.d/hooks/
cat << EOF | sudo tee /etc/pacman.d/hooks/nvidia.hook
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia-dkms
Target=nvidia-open-dkms
Target=linux

[Action]
Description=Update NVIDIA module in initcpio
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/bin/sh -c 'while read -r trg; do case \$trg in linux) exit 0; esac; done; /usr/bin/mkinitcpio -P'
EOF

# Create Hyprland NVIDIA config (following Hyprland guide)
echo "Creating Hyprland NVIDIA configuration..."
mkdir -p ~/.config/hypr
cat << 'EOF' > ~/.config/hypr/nvidia.conf
# NVIDIA environment variables (from Hyprland wiki)
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia

# Fix Electron/CEF app flickering
env = ELECTRON_OZONE_PLATFORM_HINT,auto

# Hardware acceleration
env = NVD_BACKEND,direct

# Cursor fix
env = WLR_NO_HARDWARE_CURSORS,1

# For better performance
misc {
    vfr = true
    vrr = 0
}
EOF

# Source NVIDIA config in Hyprland config
if [ -f ~/.config/hypr/hyprland.conf ]; then
    if ! grep -q "source = ~/.config/hypr/nvidia.conf" ~/.config/hypr/hyprland.conf; then
        echo "source = ~/.config/hypr/nvidia.conf" >> ~/.config/hypr/hyprland.conf
    fi
fi

echo ""
echo "NVIDIA setup complete following Hyprland official guide!"
echo ""
echo "Next steps:"
echo "1. Reboot your system"
echo "2. After reboot, verify DRM is enabled: cat /sys/module/nvidia_drm/parameters/modeset"
echo "   (should return 'Y')"
echo "3. Launch Hyprland"
echo ""
echo "If you have issues, check the Hyprland NVIDIA guide: https://wiki.hypr.land/Nvidia/"
