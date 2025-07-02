#!/bin/bash

# Check if AMD GPU is present
if ! lspci | grep -i "amd\|ati" | grep -i "vga\|3d\|display" > /dev/null; then
    echo "No AMD GPU detected, skipping AMD setup..."
    exit 0
fi

echo "AMD GPU detected, setting up AMD configuration..."

# Install AMD-specific packages
yay -S --noconfirm --needed \
    mesa \
    lib32-mesa \
    vulkan-radeon \
    lib32-vulkan-radeon \
    vulkan-icd-loader \
    lib32-vulkan-icd-loader \
    libva-mesa-driver \
    lib32-libva-mesa-driver \
    mesa-vdpau \
    lib32-mesa-vdpau \
    xf86-video-amdgpu

# Create Hyprland AMD config
mkdir -p ~/.config/hypr
cat << 'EOF' > ~/.config/hypr/amd.conf
# AMD-specific Hyprland settings
env = WLR_DRM_NO_ATOMIC,1
env = LIBVA_DRIVER_NAME,radeonsi
env = VDPAU_DRIVER,radeonsi
env = XDG_SESSION_TYPE,wayland
env = GBM_BACKEND,gbm
env = __GLX_VENDOR_LIBRARY_NAME,mesa

# Hardware acceleration
env = __GL_GSYNC_ALLOWED,0
env = __GL_VRR_ALLOWED,0
env = XCURSOR_SIZE,24

# For better performance
misc {
    vfr = true
    vrr = 2  # AMD FreeSync
    mouse_move_enables_dpms = true
    key_press_enables_dpms = true
}

# Animation settings optimized for AMD
animations {
    enabled = true
    animation = windows,1,2,default
    animation = border,1,2,default
    animation = fade,1,2,default
    animation = workspaces,1,2,default
}

# AMD-specific performance tweaks
general {
    allow_tearing = true # For potential FreeSync support
}
EOF

# Source AMD config in Hyprland config
if [ -f ~/.config/hypr/hyprland.conf ]; then
    if ! grep -q "source = ~/.config/hypr/amd.conf" ~/.config/hypr/hyprland.conf; then
        echo "source = ~/.config/hypr/amd.conf" >> ~/.config/hypr/hyprland.conf
    fi
fi

# Create browser configuration for AMD
mkdir -p ~/.config/browser-flags
cat << 'EOF' > ~/.config/browser-flags/browser-flags-amd.conf
# AMD-specific environment variables
export LIBVA_DRIVER_NAME=radeonsi
export VDPAU_DRIVER=radeonsi
export MOZ_ENABLE_WAYLAND=1
export MOZ_DRM_DEVICE=/dev/dri/renderD128

# Additional Chrome flags for AMD
export CHROME_FLAGS="$CHROME_FLAGS
  --enable-features=VaapiVideoDecoder
  --enable-accelerated-video-decode
  --enable-zero-copy
  --enable-gpu-rasterization
  --enable-oop-rasterization"
EOF

echo "AMD setup complete. Please reboot your system for changes to take effect."
