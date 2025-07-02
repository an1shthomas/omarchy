# Install base fonts
yay -Sy --noconfirm --needed ttf-font-awesome noto-fonts noto-fonts-emoji noto-fonts-cjk noto-fonts-extra

# Install all Nerd Fonts from AUR
yay -S --noconfirm --needed \
  ttf-0xproto-nerd ttf-3270-nerd ttf-agave-nerd ttf-anonymouspro-nerd \
  ttf-arimo-nerd ttf-bigblueterminal-nerd ttf-bitstream-vera-mono-nerd \
  ttf-cascadia-code-nerd ttf-cousine-nerd ttf-daddytime-mono-nerd \
  ttf-dejavu-nerd ttf-droid-nerd ttf-fantasque-nerd ttf-fira-code-nerd \
  ttf-fira-mono-nerd ttf-go-nerd ttf-hack-nerd ttf-heavydata-nerd \
  ttf-iawriter-nerd ttf-ibmplex-mono-nerd ttf-inconsolata-go-nerd \
  ttf-inconsolata-lgc-nerd ttf-inconsolata-nerd ttf-iosevka-nerd \
  ttf-jetbrains-mono-nerd ttf-lekton-nerd ttf-liberation-mono-nerd \
  ttf-lilex-nerd ttf-meslo-nerd ttf-monofur-nerd ttf-monoid-nerd \
  ttf-mononoki-nerd ttf-noto-nerd ttf-opendyslexic-nerd ttf-overpass-nerd \
  ttf-profont-nerd ttf-proggyclean-nerd ttf-roboto-mono-nerd \
  ttf-sharetech-mono-nerd ttf-sourcecodepro-nerd ttf-space-mono-nerd \
  ttf-terminus-nerd ttf-tinos-nerd ttf-ubuntu-mono-nerd ttf-ubuntu-nerd \
  ttf-victor-mono-nerd

# Create fonts directory
mkdir -p ~/.local/share/fonts

# Update font cache
fc-cache -f

if ! fc-list | grep -qi "iA Writer Mono S"; then
  cd /tmp
  wget -O iafonts.zip https://github.com/iaolo/iA-Fonts/archive/refs/heads/master.zip
  unzip iafonts.zip -d iaFonts
  cp iaFonts/iA-Fonts-master/iA\ Writer\ Mono/Static/iAWriterMonoS-*.ttf ~/.local/share/fonts
  rm -rf iafonts.zip iaFonts
  fc-cache
  cd -
fi
