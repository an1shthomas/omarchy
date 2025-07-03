#!/bin/bash

# Create browser config directory
mkdir -p ~/.config/browser-flags

# Copy base browser flags configuration
cp ~/.local/share/omarchy/config/browser-flags-base.conf ~/.config/browser-flags/

# Detect NVIDIA GPU
if lspci | grep -i nvidia > /dev/null || [ -f /proc/driver/nvidia/version ]; then
    echo "NVIDIA GPU detected, applying NVIDIA-specific optimizations..."
    # Copy NVIDIA-specific configuration
    cp ~/.local/share/omarchy/config/browser-flags-nvidia.conf ~/.config/browser-flags/
    
    # Create the combined configuration
    cat ~/.config/browser-flags/browser-flags-base.conf > ~/.config/browser-flags/browser-flags.conf
    echo "" >> ~/.config/browser-flags/browser-flags.conf
    echo "# NVIDIA-specific settings" >> ~/.config/browser-flags/browser-flags.conf
    cat ~/.config/browser-flags/browser-flags-nvidia.conf >> ~/.config/browser-flags/browser-flags.conf
else
    echo "No NVIDIA GPU detected, using base configuration..."
    cp ~/.config/browser-flags/browser-flags-base.conf ~/.config/browser-flags/browser-flags.conf
fi

# Add to .zshrc to apply flags for all Chromium-based browsers
echo '# Browser configuration' >> ~/.zshrc
echo 'source ~/.config/browser-flags/browser-flags.conf' >> ~/.zshrc
echo 'export BROWSER=brave-browser' >> ~/.zshrc

# Create wrapper scripts for each browser to apply flags
mkdir -p ~/.local/bin

# Brave wrapper
echo '#!/bin/bash
source ~/.config/browser-flags/browser-flags.conf
exec /usr/bin/brave $CHROME_FLAGS "$@"' > ~/.local/bin/brave-wayland
chmod +x ~/.local/bin/brave-wayland

# Chrome wrapper
echo '#!/bin/bash
source ~/.config/browser-flags/browser-flags.conf
exec /usr/bin/google-chrome-stable $CHROME_FLAGS "$@"' > ~/.local/bin/chrome-wayland
chmod +x ~/.local/bin/chrome-wayland

# Update desktop entries to use the wrapper scripts (copy from system and modify)
# Check for Brave browser
if [ -f /usr/share/applications/brave-browser.desktop ]; then
    cp /usr/share/applications/brave-browser.desktop ~/.local/share/applications/
    sed -i 's|^Exec=brave |Exec=brave-wayland |' ~/.local/share/applications/brave-browser.desktop
    echo "Updated Brave desktop entry to use Wayland wrapper"
else
    echo "Brave browser not installed, skipping..."
fi

# Check for Google Chrome
if [ -f /usr/share/applications/google-chrome.desktop ]; then
    cp /usr/share/applications/google-chrome.desktop ~/.local/share/applications/
    sed -i 's|^Exec=/usr/bin/google-chrome-stable |Exec=chrome-wayland |' ~/.local/share/applications/google-chrome.desktop
    echo "Updated Chrome desktop entry to use Wayland wrapper"
else
    echo "Google Chrome not installed, skipping..."
fi
