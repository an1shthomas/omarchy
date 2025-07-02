#!/bin/bash

# Check if NVIDIA GPU is present
if ! lspci | grep -i nvidia > /dev/null && [ ! -f /proc/driver/nvidia/version ]; then
    echo "No NVIDIA GPU detected, skipping NVIDIA setup..."
    exit 0
fi

echo "NVIDIA GPU detected, setting up NVIDIA configuration..."

# Install NVIDIA packages
yay -S --noconfirm --needed \
    nvidia-dkms \
    nvidia-utils \
    lib32-nvidia-utils \
    nvidia-settings \
    vulkan-icd-loader \
    lib32-vulkan-icd-loader \
    libva \
    libva-nvidia-driver \
    qt5-wayland \
    qt6-wayland

# Create Pacman hook for nvidia modules
sudo mkdir -p /etc/pacman.d/hooks/
cat << 'EOF' | sudo tee /etc/pacman.d/hooks/nvidia.hook
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia-dkms
Target=linux

[Action]
Description=Update NVIDIA module in initcpio
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/bin/sh -c 'while read -r trg; do case $trg in linux) exit 0; esac; done; /usr/bin/mkinitcpio -P'
EOF

# Add kernel parameters for NVIDIA
if ! grep -q "nvidia_drm.modeset=1" /etc/default/grub; then
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia_drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"/' /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg
fi

# Create modprobe config
echo "options nvidia-drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf

# Add NVIDIA modules to initramfs
if ! grep -q "^MODULES=(.*nvidia.*)" /etc/mkinitcpio.conf; then
    sudo sed -i 's/^MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf
    sudo mkinitcpio -P
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
