# Install Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install zsh plugins
yay -S --noconfirm --needed zsh-autosuggestions zsh-syntax-highlighting

# Create .zshrc if it doesn't exist
touch ~/.zshrc

# Add plugins to .zshrc
sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc

# Add source commands for plugins
echo "source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ~/.zshrc
echo "source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" >> ~/.zshrc

# Source bash aliases and functions in zsh
echo "" >> ~/.zshrc
echo "# Source bash configuration for compatibility" >> ~/.zshrc
echo "source ~/.local/share/omarchy/default/bash/aliases" >> ~/.zshrc
echo "source ~/.local/share/omarchy/default/bash/functions" >> ~/.zshrc

# Set zsh as default shell
chsh -s $(which zsh)

echo "Zsh setup complete. Please log out and log back in for the shell change to take effect."
