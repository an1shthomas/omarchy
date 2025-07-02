#!/bin/bash

echo "WARNING: This script will remove all configurations and packages installed by Omarchy."
echo "Your system will be restored to a basic Arch Linux installation."
echo "Make sure to backup any personal configurations before proceeding."
read -p "Are you sure you want to continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Function to remove packages if they exist
remove_if_exists() {
    if pacman -Qi "$1" &>/dev/null; then
        echo "Removing package: $1"
        sudo pacman -Rns --noconfirm "$1"
    fi
}

echo "Removing installed packages..."
# Remove Hyprland and related packages
yay -Rns --noconfirm hyprland hyprshot hyprpicker hyprlock hypridle hyprpolkitagent hyprland-qtutils || true
yay -Rns --noconfirm wofi waybar mako swaybg || true

# Remove desktop applications
yay -Rns --noconfirm brave-bin google-chrome vlc evince imv || true
yay -Rns --noconfirm brightnessctl playerctl pamixer pavucontrol wireplumber || true
yay -Rns --noconfirm fcitx5 fcitx5-gtk fcitx5-qt fcitx5-configtool || true
yay -Rns --noconfirm wl-clip-persist clipse || true
yay -Rns --noconfirm nautilus sushi gnome-calculator || true
yay -Rns --noconfirm 1password-beta 1password-cli || true

# Remove terminal utilities
yay -Rns --noconfirm wget curl unzip inetutils || true
yay -Rns --noconfirm eza fzf ripgrep zoxide bat || true
yay -Rns --noconfirm wl-clipboard fastfetch btop || true
yay -Rns --noconfirm man tldr less whois plocate || true
yay -Rns --noconfirm alacritty || true

# Remove development tools
yay -Rns --noconfirm cargo clang llvm mise || true
yay -Rns --noconfirm imagemagick || true
yay -Rns --noconfirm mariadb-libs postgresql-libs || true
yay -Rns --noconfirm github-cli || true
yay -Rns --noconfirm lazygit lazydocker || true
yay -Rns --noconfirm docker docker-compose || true

# Remove zsh and related packages
if [ "$SHELL" = "/usr/bin/zsh" ]; then
    echo "Changing default shell back to bash..."
    chsh -s /bin/bash
fi
yay -Rns --noconfirm zsh zsh-autosuggestions zsh-syntax-highlighting || true

echo "Removing configuration files..."
# Remove config directories
rm -rf ~/.config/hypr
rm -rf ~/.config/browser-flags
rm -rf ~/.oh-my-zsh
rm -f ~/.zshrc

# Remove desktop entries
rm -f ~/.local/share/applications/brave-browser.desktop
rm -f ~/.local/share/applications/google-chrome.desktop

# Remove Nerd Fonts
echo "Removing Nerd Fonts..."
fc-list | grep -i "nerd" | cut -d: -f1 | while read font; do
    rm -f "$font"
done
fc-cache -f

# Cleanup NVIDIA configurations if they exist
if [ -f /etc/modprobe.d/nvidia.conf ]; then
    echo "Removing NVIDIA configurations..."
    sudo rm -f /etc/modprobe.d/nvidia.conf
    sudo rm -f /etc/pacman.d/hooks/nvidia.hook
    
    # Restore original GRUB configuration
    if grep -q "nvidia_drm.modeset=1" /etc/default/grub; then
        sudo sed -i 's/ nvidia_drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1//' /etc/default/grub
        sudo grub-mkconfig -o /boot/grub/grub.cfg
    fi
    
    # Restore original mkinitcpio configuration
    if grep -q "^MODULES=(.*nvidia.*)" /etc/mkinitcpio.conf; then
        sudo sed -i 's/^MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /MODULES=(/' /etc/mkinitcpio.conf
        sudo mkinitcpio -P
    fi
fi

# Remove yay if requested
read -p "Do you want to remove yay as well? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo pacman -Rns --noconfirm yay
fi

echo "Cleanup complete. Please reboot your system for all changes to take effect."
echo "Note: Some system packages may remain as they might be dependencies for other packages."
echo "You can use 'pacman -Qdt' to list orphaned packages and remove them if needed."
