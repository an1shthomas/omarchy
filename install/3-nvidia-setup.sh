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

# Install NVIDIA packages
yay -S --noconfirm --needed \
    $NVIDIA_DRIVER \
    nvidia-utils \
    nvidia-settings \
    vulkan-icd-loader \
    libva \
    libva-nvidia-driver \
    qt5-wayland \
    qt6-wayland

# Install 32-bit packages if multilib is available
if pacman -Sl multilib &>/dev/null; then
    echo "Installing 32-bit NVIDIA libraries..."
    yay -S --noconfirm --needed \
        lib32-nvidia-utils \
        lib32-vulkan-icd-loader
else
    echo "Multilib repository not available, skipping 32-bit libraries..."
fi

# Create Pacman hook for nvidia modules
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

# Add kernel parameters for NVIDIA
if [ -f /etc/default/grub ]; then
    # GRUB bootloader
    if ! grep -q "nvidia_drm.modeset=1" /etc/default/grub; then
        echo "Adding NVIDIA kernel parameters to GRUB..."
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia_drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"/' /etc/default/grub
        sudo grub-mkconfig -o /boot/grub/grub.cfg
    fi
elif [ -d /boot/loader/entries ]; then
    # systemd-boot
    echo "Adding NVIDIA kernel parameters to systemd-boot..."
    for entry in /boot/loader/entries/*.conf; do
        if [ -f "$entry" ] && ! grep -q "nvidia_drm.modeset=1" "$entry"; then
            sudo sed -i '/^options/ s/$/ nvidia_drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1/' "$entry"
        fi
    done
elif [ -f /boot/refind_linux.conf ]; then
    # rEFInd
    echo "Adding NVIDIA kernel parameters to rEFInd..."
    if ! grep -q "nvidia_drm.modeset=1" /boot/refind_linux.conf; then
        sudo sed -i 's/"$/ nvidia_drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"/' /boot/refind_linux.conf
    fi
else
    echo "Warning: Unknown bootloader detected. Please manually add these kernel parameters:"
    echo "nvidia_drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"
fi

# Create modprobe config
echo "options nvidia-drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf

# Force DKMS to build NVIDIA modules
echo "Building NVIDIA DKMS modules..."
KERNEL_VERSION=$(uname -r)

# Get the installed NVIDIA driver version
if pacman -Q nvidia-open-dkms >/dev/null 2>&1; then
    NVIDIA_VERSION=$(pacman -Q nvidia-open-dkms | awk '{print $2}' | cut -d'-' -f1)
    DRIVER_NAME="nvidia-open"
    PACKAGE_NAME="nvidia-open-dkms"
elif pacman -Q nvidia-dkms >/dev/null 2>&1; then
    NVIDIA_VERSION=$(pacman -Q nvidia-dkms | awk '{print $2}' | cut -d'-' -f1)
    DRIVER_NAME="nvidia"
    PACKAGE_NAME="nvidia-dkms"
else
    echo "Error: No NVIDIA DKMS driver found!"
    exit 1
fi

echo "Found $DRIVER_NAME version $NVIDIA_VERSION for kernel $KERNEL_VERSION"

# Check if source directory exists
SOURCE_DIR="/usr/src/$DRIVER_NAME-$NVIDIA_VERSION"
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Source directory $SOURCE_DIR not found. Reinstalling NVIDIA DKMS package..."
    yay -S --noconfirm $PACKAGE_NAME
    
    # Wait a moment for files to be installed
    sleep 2
    
    if [ ! -d "$SOURCE_DIR" ]; then
        echo "Error: Source directory still not found after reinstall."
        echo "Available source directories:"
        ls -la /usr/src/ | grep nvidia || echo "No nvidia directories found"
        
        # Try to find any nvidia source directory
        FOUND_DIR=$(find /usr/src -maxdepth 1 -name "nvidia*" -type d | head -1)
        if [ -n "$FOUND_DIR" ]; then
            ACTUAL_VERSION=$(basename "$FOUND_DIR" | sed "s/$DRIVER_NAME-//")
            echo "Found alternative directory: $FOUND_DIR"
            echo "Using version: $ACTUAL_VERSION"
            NVIDIA_VERSION="$ACTUAL_VERSION"
            SOURCE_DIR="$FOUND_DIR"
        else
            echo "No NVIDIA source directories found. Skipping DKMS build."
            echo "You may need to manually install the NVIDIA drivers after reboot."
            exit 0
        fi
    fi
fi

echo "Using source directory: $SOURCE_DIR"

# Remove any existing DKMS modules first
sudo dkms remove -m $DRIVER_NAME -v $NVIDIA_VERSION -k $KERNEL_VERSION 2>/dev/null || true

# Add and build the DKMS module
echo "Adding DKMS module..."
if ! sudo dkms add -m $DRIVER_NAME -v $NVIDIA_VERSION; then
    echo "Failed to add DKMS module. Trying to continue anyway..."
fi

echo "Building DKMS module (this may take a few minutes)..."
if ! sudo dkms build -m $DRIVER_NAME -v $NVIDIA_VERSION -k $KERNEL_VERSION; then
    echo "DKMS build failed. Trying autoinstall as fallback..."
    sudo dkms autoinstall
fi

echo "Installing DKMS module..."
if ! sudo dkms install -m $DRIVER_NAME -v $NVIDIA_VERSION -k $KERNEL_VERSION; then
    echo "DKMS install failed. Checking if modules were built anyway..."
fi

# Wait a moment for modules to be available
sleep 3

# Verify modules exist in multiple possible locations
NVIDIA_MODULE_FOUND=false
for MODULE_PATH in "/lib/modules/$KERNEL_VERSION/updates/dkms" "/lib/modules/$KERNEL_VERSION/kernel/drivers/gpu/drm" "/lib/modules/$KERNEL_VERSION/extra"; do
    if [ -d "$MODULE_PATH" ] && ls "$MODULE_PATH"/nvidia*.ko* >/dev/null 2>&1; then
        echo "NVIDIA modules found in $MODULE_PATH"
        NVIDIA_MODULE_FOUND=true
        break
    fi
done

if [ "$NVIDIA_MODULE_FOUND" = true ]; then
    echo "NVIDIA modules successfully built and installed, adding to initramfs..."
    if ! grep -q "^MODULES=(.*nvidia.*)" /etc/mkinitcpio.conf; then
        sudo sed -i 's/^MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf
        sudo mkinitcpio -P
    fi
else
    echo "Warning: NVIDIA modules still not found after DKMS build."
    echo "Please check DKMS status with: sudo dkms status"
    echo "You may need to reboot and run the following manually:"
    echo "  sudo dkms autoinstall"
    echo "  sudo mkinitcpio -P"
fi

# Create Hyprland NVIDIA config
mkdir -p ~/.config/hypr
cat << 'EOF' > ~/.config/hypr/nvidia.conf
# NVIDIA-specific Hyprland settings
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = WLR_NO_HARDWARE_CURSORS,1
env = __GL_GSYNC_ALLOWED,0
env = __GL_VRR_ALLOWED,0
env = XCURSOR_SIZE,24

# Hardware acceleration
env = LIBVA_DRIVER_NAME,nvidia
env = __NV_PRIME_RENDER_OFFLOAD,1
env = __VK_LAYER_NV_optimus,NVIDIA_only
env = WLR_DRM_DEVICES,/dev/dri/card0

# Startup
exec-once = nvidia-settings --load-config-only

# For better performance
misc {
    vfr = true
    vrr = 0
    mouse_move_enables_dpms = true
    key_press_enables_dpms = true
}

# Animation settings for better performance
animations {
    enabled = true
    animation = windows,1,2,default
    animation = border,1,2,default
    animation = fade,1,2,default
    animation = workspaces,1,2,default
}
EOF

# Source NVIDIA config in Hyprland config
if [ -f ~/.config/hypr/hyprland.conf ]; then
    if ! grep -q "source = ~/.config/hypr/nvidia.conf" ~/.config/hypr/hyprland.conf; then
        echo "source = ~/.config/hypr/nvidia.conf" >> ~/.config/hypr/hyprland.conf
    fi
fi

echo "NVIDIA setup complete. Please reboot your system for changes to take effect."
