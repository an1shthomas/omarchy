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
if ! grep -q "# Browser configuration" ~/.zshrc 2>/dev/null; then
    echo '# Browser configuration' >> ~/.zshrc
    echo 'source ~/.config/browser-flags/browser-flags.conf' >> ~/.zshrc
    echo 'export BROWSER=brave' >> ~/.zshrc
fi

# Create wrapper scripts for each browser to apply flags
mkdir -p ~/.local/bin

# Brave wrapper
cat > ~/.local/bin/brave-wayland << 'EOF'
#!/bin/bash
source ~/.config/browser-flags/browser-flags.conf
exec /usr/bin/brave $CHROME_FLAGS "$@"
EOF
chmod +x ~/.local/bin/brave-wayland

# Chrome wrapper
cat > ~/.local/bin/chrome-wayland << 'EOF'
#!/bin/bash
source ~/.config/browser-flags/browser-flags.conf
exec /usr/bin/google-chrome-stable $CHROME_FLAGS "$@"
EOF
chmod +x ~/.local/bin/chrome-wayland

# Update desktop entries to use optimized Wayland configurations
mkdir -p ~/.local/share/applications

# Check for Brave browser
if [ -f /usr/share/applications/brave-browser.desktop ]; then
    echo "Creating optimized Brave desktop entry..."
    cat > ~/.local/share/applications/brave-browser.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Name=Brave
GenericName=Web Browser
Comment=Access the Internet
StartupNotify=true
StartupWMClass=brave-browser
TryExec=brave
Exec=brave --ozone-platform=wayland --enable-features=UseOzonePlatform --force-device-scale-factor=1 %U
Terminal=false
Icon=brave-desktop
Type=Application
Categories=Network;WebBrowser;
MimeType=application/pdf;application/rdf+xml;application/rss+xml;application/xhtml+xml;application/xhtml_xml;application/xml;image/gif;image/jpeg;image/png;image/webp;text/html;text/xml;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ipfs;x-scheme-handler/ipns;
Actions=new-window;new-private-window;

[Desktop Action new-window]
Name=New Window
Exec=brave --ozone-platform=wayland --enable-features=UseOzonePlatform --force-device-scale-factor=1

[Desktop Action new-private-window]
Name=New Incognito Window
Exec=brave --ozone-platform=wayland --enable-features=UseOzonePlatform --force-device-scale-factor=1 --incognito
EOF
    echo "Updated Brave desktop entry with Wayland scaling optimizations"
else
    echo "Brave browser not installed, skipping..."
fi

# Check for Google Chrome
if [ -f /usr/share/applications/google-chrome.desktop ]; then
    echo "Creating optimized Chrome desktop entry..."
    cp /usr/share/applications/google-chrome.desktop ~/.local/share/applications/
    # Replace all Exec lines with optimized flags
    sed -i 's|^Exec=/usr/bin/google-chrome-stable|Exec=/usr/bin/google-chrome-stable --ozone-platform=wayland --enable-features=UseOzonePlatform --force-device-scale-factor=1|g' ~/.local/share/applications/google-chrome.desktop
    sed -i 's|^Exec=google-chrome-stable|Exec=google-chrome-stable --ozone-platform=wayland --enable-features=UseOzonePlatform --force-device-scale-factor=1|g' ~/.local/share/applications/google-chrome.desktop
    echo "Updated Chrome desktop entry with Wayland scaling optimizations"
else
    echo "Google Chrome not installed, skipping..."
fi

# Update desktop database so applications appear in wofi
echo "Updating desktop database..."
update-desktop-database ~/.local/share/applications 2>/dev/null || true
echo "Browser configuration complete!"
