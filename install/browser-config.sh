#!/bin/bash

# Create browser config directory
mkdir -p ~/.config/browser-flags

# Copy browser flags configuration
cp ~/.local/share/omarchy/config/browser-flags.conf ~/.config/browser-flags/

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

# Update desktop entries to use the wrapper scripts
sed -i 's|^Exec=brave |Exec=brave-wayland |' ~/.local/share/applications/brave-browser.desktop
sed -i 's|^Exec=/usr/bin/google-chrome-stable |Exec=chrome-wayland |' ~/.local/share/applications/google-chrome.desktop
