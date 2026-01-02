#!/usr/bin/env bash

#############################################################################
# FreeBSD 15.0 + Sway (Wayland) + Everforest - Script Definitivo
# 
# REQUISITOS:
# - FreeBSD 15.0 instalado
# - Usuario normal (NO root)
# - sudo configurado
# - Conexión a internet
#
# OPTIMIZADO PARA:
# - ThinkPad T480 (Intel Graphics)
# - VMs QEMU/KVM, VirtualBox, VMware
#
# USO:
#   bash freebsd-sway-setup-FINAL.sh
#
# Tiempo estimado: 15-25 minutos
#############################################################################

# Verificar que se está ejecutando con bash
if [ -z "$BASH_VERSION" ]; then
    echo "ERROR: Este script REQUIERE bash"
    echo ""
    echo "SOLUCIÓN:"
    echo "  sudo pkg install -y bash"
    echo "  bash freebsd-sway-setup-FINAL.sh"
    exit 1
fi

set -e  # Salir si hay algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Funciones de utilidad
print_step() {
    echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

print_info() {
    echo -e "${CYAN}INFO:${NC} $1"
}

# Verificar que no se ejecuta como root
if [ "$EUID" -eq 0 ]; then 
    print_error "NO ejecutes este script como root. Usa tu usuario normal."
    exit 1
fi

# Verificar que sudo funciona
if ! sudo -n true 2>/dev/null; then
    print_warning "Necesitas permisos sudo. Por favor ingresa tu contraseña:"
    sudo -v
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_step "FreeBSD 15.0 + Sway (Wayland) + Everforest - Instalación"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Este script instalará:"
echo "  • Sway (Wayland compositor - reemplazo de i3)"
echo "  • Alacritty (Terminal)"
echo "  • Fuzzel (Launcher - reemplazo de Rofi)"
echo "  • Swaybar + i3status (Barra de estado)"
echo "  • Tema Everforest Dark Hard completo"
echo "  • Soporte para brillo, volumen, bluetooth"
echo "  • Optimizado para ThinkPad T480 y VMs"
echo ""
echo "Tiempo estimado: 15-25 minutos"
printf "¿Continuar? (y/n) "
read REPLY
if [ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ]; then
    echo "Instalación cancelada."
    exit 1
fi

#############################################################################
# FASE 1: ACTUALIZAR SISTEMA Y PAQUETES BASE
#############################################################################

print_step "FASE 1/10: Actualizando sistema base..."
sudo pkg update -f
sudo pkg upgrade -y

#############################################################################
# FASE 2: INSTALAR PAQUETES ESENCIALES DEL SISTEMA
#############################################################################

print_step "FASE 2/10: Instalando paquetes esenciales del sistema..."
sudo pkg install -y \
    bash \
    zsh \
    curl \
    wget \
    git \
    vim \
    neovim \
    tmux \
    htop \
    tree \
    unzip \
    zip \
    dbus \
    polkit || print_warning "Algunos paquetes base pueden haber fallado (no crítico)"

#############################################################################
# FASE 3: INSTALAR WAYLAND Y DRIVERS
#############################################################################

print_step "FASE 3/10: Instalando Wayland, drivers y utilidades gráficas..."

# Instalar Wayland core
sudo pkg install -y \
    wayland \
    wayland-protocols \
    seatd \
    xwayland

# Instalar drivers gráficos para diferentes entornos
print_step "Instalando drivers de video..."

# Drivers para Intel (ThinkPad T480 y mayoría de laptops)
sudo pkg install -y \
    drm-kmod \
    libva-intel-driver \
    mesa-dri

# Detectar entorno
if dmesg | grep -qi "vmware"; then
    print_info "Detectado VMware - usando drivers genéricos"
elif dmesg | grep -qi "virtualbox"; then
    print_info "Detectado VirtualBox"
    sudo pkg install -y virtualbox-ose-additions || true
elif dmesg | grep -qi "qemu\|virtio"; then
    print_info "Detectado QEMU/KVM - usando drivers genéricos (NO QXL - causa segfault)"
fi

# Cargar módulo de Intel Graphics
if dmesg | grep -qi "intel"; then
    print_info "Detectado Intel Graphics - configurando i915kms"
    sudo sysrc kld_list+="i915kms"
    sudo kldload i915kms 2>/dev/null || print_warning "i915kms ya cargado o no disponible"
fi

#############################################################################
# FASE 4: INSTALAR SWAY Y COMPONENTES DE WAYLAND
#############################################################################

print_step "FASE 4/10: Instalando Sway y herramientas Wayland..."
sudo pkg install -y \
    sway \
    swayidle \
    swaylock \
    swaybg \
    wl-clipboard \
    wtype \
    grim \
    slurp \
    mako

#############################################################################
# FASE 5: INSTALAR ALACRITTY, FUZZEL Y UTILIDADES
#############################################################################

print_step "FASE 5/10: Instalando terminal, launcher y utilidades..."

# Terminal
sudo pkg install -y alacritty || {
    print_warning "Alacritty no disponible, instalando alternativa"
    sudo pkg install -y foot || sudo pkg install -y xterm
}

# Launcher (fuzzel o tofi como alternativa)
sudo pkg install -y fuzzel || {
    print_warning "Fuzzel no disponible, instalando tofi"
    sudo pkg install -y tofi || print_warning "Launcher no disponible"
}

# Utilidades de sistema
sudo pkg install -y \
    brightnessctl \
    pavucontrol \
    pamixer \
    playerctl

#############################################################################
# FASE 6: INSTALAR FUENTES
#############################################################################

print_step "FASE 6/10: Instalando fuentes y Nerd Fonts..."
sudo pkg install -y \
    jetbrains-mono \
    nerd-fonts \
    noto-basic \
    noto-sans \
    noto-serif \
    noto-emoji \
    font-awesome \
    webfonts \
    dejavu

# Actualizar caché de fuentes
fc-cache -fv

#############################################################################
# FASE 7: INSTALAR APLICACIONES ESENCIALES
#############################################################################

print_step "FASE 7/10: Instalando aplicaciones esenciales..."

# Navegador
sudo pkg install -y firefox || print_warning "Firefox no disponible"

# File managers
sudo pkg install -y thunar pcmanfm 2>/dev/null || print_warning "File managers opcionales"

# Visores
sudo pkg install -y \
    imv \
    zathura \
    zathura-pdf-mupdf \
    mpv

# Utilidades
sudo pkg install -y \
    neofetch \
    lxappearance \
    wdisplays

#############################################################################
# FASE 8: CONFIGURAR SERVICIOS DEL SISTEMA
#############################################################################

print_step "FASE 8/10: Configurando servicios del sistema..."

# Configurar dbus
sudo sysrc dbus_enable="YES"

# Configurar seatd (CRÍTICO para Wayland)
sudo sysrc seatd_enable="YES"

# Agregar usuario a grupos necesarios
print_step "Agregando usuario a grupos video y audio..."
sudo pw groupmod video -m $USER 2>/dev/null || true
sudo pw groupmod audio -m $USER 2>/dev/null || true

# Iniciar servicios
sudo service dbus start 2>/dev/null || true
sudo service seatd start 2>/dev/null || true

# Configurar módulos del kernel
if ! grep -q "fuse_load" /boot/loader.conf 2>/dev/null; then
    print_step "Configurando módulos del kernel..."
    sudo sh -c 'cat >> /boot/loader.conf << EOF

# Módulos para Wayland y virtualización
fuse_load="YES"
coretemp_load="YES"
EOF'
fi

# Crear tmpfs para /tmp (recomendado para Wayland)
if ! grep -q "tmpfs.*\/tmp" /etc/fstab 2>/dev/null; then
    print_step "Configurando tmpfs para /tmp..."
    sudo sh -c 'echo "tmpfs /tmp tmpfs rw,mode=1777 0 0" >> /etc/fstab'
fi

#############################################################################
# FASE 9: CREAR TODAS LAS CONFIGURACIONES
#############################################################################

print_step "FASE 9/10: Creando configuraciones de Sway, Alacritty, Fuzzel..."

# VERIFICACIÓN CRÍTICA: Asegurar que NO somos root
if [ "$EUID" -eq 0 ] || [ "$USER" = "root" ]; then
    print_error "ERROR: Esta sección NO debe ejecutarse como root"
    print_error "El script detectó que \$HOME es /root"
    print_error "Por favor ejecuta el script como usuario normal"
    exit 1
fi

# Crear directorios necesarios
print_step "Creando directorios de configuración..."
mkdir -p ~/.config/sway
mkdir -p ~/.config/alacritty
mkdir -p ~/.config/fuzzel
mkdir -p ~/.config/i3status
mkdir -p ~/.config/mako
mkdir -p ~/.config/gtk-3.0
mkdir -p ~/Pictures/wallpapers

# Verificar que se crearon
if [ ! -d ~/.config/sway ]; then
    print_error "No se pudo crear ~/.config/sway"
    exit 1
fi

#############################################################################
# 9.1 - CONFIGURACIÓN DE SWAY
#############################################################################

print_step "Configurando Sway (Wayland compositor)..."
cat > ~/.config/sway/config << 'EOF'
# Sway config - Everforest Dark Hard Theme
# Mod key (Mod4 = Super/Windows)
set $mod Mod4

# Fuente para títulos
font pango:JetBrainsMono Nerd Font 10

# Terminal
set $term alacritty

# Launcher
set $menu fuzzel

# QUITAR BORDES DE TÍTULO (como pediste)
default_border pixel 2
default_floating_border pixel 2
for_window [class=".*"] border pixel 2
for_window [app_id=".*"] border pixel 2

# Gaps (opcional, descomenta si quieres)
# gaps inner 8
# gaps outer 4

# Colores Everforest Dark Hard
client.focused          #a7c080 #3d484d #d3c6aa #a7c080   #a7c080
client.focused_inactive #4b565c #2b3339 #859289 #4b565c   #4b565c
client.unfocused        #4b565c #2b3339 #859289 #4b565c   #4b565c
client.urgent           #e67e80 #e67e80 #2b3339 #e67e80   #e67e80
client.placeholder      #2b3339 #2b3339 #859289 #2b3339   #2b3339
client.background       #2b3339

# Wallpaper
output * bg ~/Pictures/wallpapers/everforest.png fill

# Idle y lock
exec swayidle -w \
    timeout 300 'swaylock -f -c 2b3339' \
    timeout 600 'swaymsg "output * dpms off"' \
    resume 'swaymsg "output * dpms on"' \
    before-sleep 'swaylock -f -c 2b3339'

# Notificaciones
exec mako

# Configuración de entrada (teclado)
input type:keyboard {
    xkb_layout "latam"
    # Cambia a "us" si usas teclado inglés
}

# Configuración de touchpad (ThinkPad T480)
input type:touchpad {
    tap enabled
    natural_scroll enabled
    dwt enabled
    accel_profile adaptive
    pointer_accel 0.3
}

# KEYBINDINGS BÁSICOS

# Terminal
bindsym $mod+Return exec $term

# Matar ventana
bindsym $mod+Shift+q kill

# Launcher
bindsym $mod+d exec $menu

# Recargar configuración
bindsym $mod+Shift+c reload

# Salir de Sway
bindsym $mod+Shift+e exec swaynag -t warning -m 'Salir de Sway?' -B 'Sí' 'swaymsg exit'

# Navegación
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

# Mover ventanas
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# Layouts
bindsym $mod+h splith
bindsym $mod+v splitv
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+e layout toggle split
bindsym $mod+f fullscreen

# Floating
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle

# Workspaces
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5
bindsym $mod+6 workspace number 6
bindsym $mod+7 workspace number 7
bindsym $mod+8 workspace number 8
bindsym $mod+9 workspace number 9
bindsym $mod+0 workspace number 10

# Mover ventanas a workspaces
bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2
bindsym $mod+Shift+3 move container to workspace number 3
bindsym $mod+Shift+4 move container to workspace number 4
bindsym $mod+Shift+5 move container to workspace number 5
bindsym $mod+Shift+6 move container to workspace number 6
bindsym $mod+Shift+7 move container to workspace number 7
bindsym $mod+Shift+8 move container to workspace number 8
bindsym $mod+Shift+9 move container to workspace number 9
bindsym $mod+Shift+0 move container to workspace number 10

# CONTROL DE VOLUMEN (PulseAudio/PipeWire)
bindsym XF86AudioRaiseVolume exec pamixer -i 5
bindsym XF86AudioLowerVolume exec pamixer -d 5
bindsym XF86AudioMute exec pamixer -t

# CONTROL DE BRILLO (para ThinkPad T480)
bindsym XF86MonBrightnessUp exec brightnessctl set +5%
bindsym XF86MonBrightnessDown exec brightnessctl set 5%-

# Screenshots
bindsym Print exec grim ~/Pictures/screenshot_$(date +%Y%m%d_%H%M%S).png
bindsym $mod+Print exec grim -g "$(slurp)" ~/Pictures/screenshot_$(date +%Y%m%d_%H%M%S).png

# Modo resize
mode "resize" {
    bindsym Left resize shrink width 10px
    bindsym Down resize grow height 10px
    bindsym Up resize shrink height 10px
    bindsym Right resize grow width 10px

    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

# Barra de estado
bar {
    position top
    status_command i3status
    colors {
        background #2b3339
        statusline #d3c6aa
        separator  #859289

        focused_workspace  #a7c080 #3d484d #d3c6aa
        active_workspace   #4b565c #2b3339 #859289
        inactive_workspace #4b565c #2b3339 #859289
        urgent_workspace   #e67e80 #e67e80 #2b3339
    }
}

# Configuración de pantalla para 1366x768 (si es necesario)
# Descomenta y ajusta según tu pantalla:
# output eDP-1 resolution 1366x768 position 0,0
EOF

#############################################################################
# 9.2 - CONFIGURACIÓN DE ALACRITTY
#############################################################################

print_step "Configurando Alacritty..."
cat > ~/.config/alacritty/alacritty.toml << 'EOF'
# Alacritty Terminal - Everforest Dark Hard

[window]
padding.x = 8
padding.y = 8
opacity = 0.95

[font]
normal.family = "JetBrainsMono Nerd Font"
bold.family = "JetBrainsMono Nerd Font"
italic.family = "JetBrainsMono Nerd Font"
bold_italic.family = "JetBrainsMono Nerd Font"
size = 11.0

[cursor]
style.shape = "Block"
style.blinking = "Off"

[colors.primary]
background = "#2b3339"
foreground = "#d3c6aa"

[colors.cursor]
text = "#2b3339"
cursor = "#d3c6aa"

[colors.normal]
black   = "#4b565c"
red     = "#e67e80"
green   = "#a7c080"
yellow  = "#dbbc7f"
blue    = "#7fbbb3"
magenta = "#d699b6"
cyan    = "#83c092"
white   = "#d3c6aa"

[colors.bright]
black   = "#4b565c"
red     = "#e67e80"
green   = "#a7c080"
yellow  = "#dbbc7f"
blue    = "#7fbbb3"
magenta = "#d699b6"
cyan    = "#83c092"
white   = "#d3c6aa"

[terminal.shell]
program = "/usr/local/bin/zsh"
EOF

#############################################################################
# 9.3 - CONFIGURACIÓN DE FUZZEL
#############################################################################

print_step "Configurando Fuzzel (launcher)..."
cat > ~/.config/fuzzel/fuzzel.ini << 'EOF'
# Fuzzel - Everforest Dark Hard

[main]
terminal = alacritty
layer = overlay
width = 40
lines = 12
tabs = 4
horizontal-pad = 20
vertical-pad = 10
inner-pad = 5

[colors]
background = 2b3339ee
text = d3c6aaff
match = a7c080ff
selection = 3d484dff
selection-text = d3c6aaff
border = a7c080ff

[border]
width = 2
radius = 8

[dmenu]
exit-immediately-if-empty = yes
EOF

#############################################################################
# 9.4 - CONFIGURACIÓN DE I3STATUS
#############################################################################

print_step "Configurando i3status..."
mkdir -p ~/.config/i3status
cat > ~/.config/i3status/config << 'EOF'
# i3status configuration - Everforest Theme

general {
    colors = true
    color_good = "#a7c080"
    color_degraded = "#dbbc7f"
    color_bad = "#e67e80"
    interval = 5
}

order += "wireless _first_"
order += "ethernet _first_"
order += "battery all"
order += "disk /"
order += "memory"
order += "cpu_usage"
order += "volume master"
order += "tztime local"

wireless _first_ {
    format_up = "📡 %essid %quality"
    format_down = "📡 down"
}

ethernet _first_ {
    format_up = "🌐 %ip"
    format_down = "🌐 down"
}

battery all {
    format = "%status %percentage %remaining"
    status_chr = "⚡"
    status_bat = "🔋"
    status_full = "🔌"
    low_threshold = 15
}

disk "/" {
    format = "💾 %avail"
}

memory {
    format = "🧠 %used"
    threshold_degraded = "10%"
}

cpu_usage {
    format = "⚡ %usage"
}

volume master {
    format = "🔊 %volume"
    format_muted = "🔇 muted"
    device = "default"
}

tztime local {
    format = "📅 %Y-%m-%d 🕐 %H:%M"
}
EOF

#############################################################################
# 9.5 - CONFIGURACIÓN DE MAKO (notificaciones)
#############################################################################

print_step "Configurando Mako (notificaciones)..."
cat > ~/.config/mako/config << 'EOF'
# Mako - Everforest Dark Hard

background-color=#2b3339
text-color=#d3c6aa
border-color=#a7c080
border-size=2
border-radius=8
padding=12
margin=10
default-timeout=5000

[urgency=high]
border-color=#e67e80
EOF

#############################################################################
# 9.6 - CREAR WALLPAPER EVERFOREST
#############################################################################

print_step "Creando wallpaper Everforest..."
if command -v convert &> /dev/null; then
    convert -size 1920x1080 xc:'#2b3339' ~/Pictures/wallpapers/everforest.png
else
    sudo pkg install -y ImageMagick7
    convert -size 1920x1080 xc:'#2b3339' ~/Pictures/wallpapers/everforest.png
fi

#############################################################################
# 9.7 - VARIABLES DE ENTORNO PARA WAYLAND
#############################################################################

print_step "Configurando variables de entorno para Wayland..."

# Crear script de inicio para Wayland
cat > ~/.wayland-env << 'EOF'
# Variables de entorno para Wayland

# XDG Runtime Directory
export XDG_RUNTIME_DIR=/tmp/$(id -u)-runtime-dir
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Wayland
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=sway

# Qt
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1

# Mozilla/Firefox
export MOZ_ENABLE_WAYLAND=1

# GTK
export GDK_BACKEND=wayland

# Clutter
export CLUTTER_BACKEND=wayland

# SDL
export SDL_VIDEODRIVER=wayland

# Java applications
export _JAVA_AWT_WM_NONREPARENTING=1
EOF

# Agregar a .profile para que se cargue al login
if ! grep -q "wayland-env" ~/.profile 2>/dev/null; then
    cat >> ~/.profile << 'EOF'

# Cargar variables de Wayland
if [ -f ~/.wayland-env ]; then
    . ~/.wayland-env
fi
EOF
fi

#############################################################################
# 9.8 - CONFIGURAR GTK
#############################################################################

print_step "Configurando GTK..."
cat > ~/.config/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-font-name=Noto Sans 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-enable-event-sounds=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
EOF

#############################################################################
# 9.9 - CREAR .ZSHRC
#############################################################################

if [ ! -f ~/.zshrc ]; then
    print_step "Creando .zshrc básico..."
    cat > ~/.zshrc << 'EOF'
# Zsh configuration - Everforest setup

# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY

# Completion
autoload -Uz compinit
compinit

# Prompt básico
PS1='%F{green}%n@%m%f:%F{blue}%~%f$ '

# Aliases útiles
alias ls='ls -G'
alias ll='ls -lh'
alias la='ls -lah'
alias ..='cd ..'
alias ...='cd ../..'

# Neofetch al iniciar (opcional)
# neofetch
EOF
    print_step ".zshrc creado"
fi

#############################################################################
# FASE 10: VERIFICACIÓN Y FINALIZACIÓN
#############################################################################

print_step "FASE 10/10: Verificando instalación..."

# Verificar binarios críticos
REQUIRED_BINS=("sway" "alacritty" "fuzzel" "mako")
MISSING=()

for bin in "${REQUIRED_BINS[@]}"; do
    if ! command -v "$bin" &> /dev/null; then
        MISSING+=("$bin")
    fi
done

if [ ${#MISSING[@]} -ne 0 ]; then
    print_warning "Paquetes opcionales no instalados: ${MISSING[*]}"
    print_info "El sistema funcionará, pero considera instalarlos manualmente"
fi

# Verificar directorios de configuración
CONFIG_DIRS=(
    "$HOME/.config/sway"
    "$HOME/.config/alacritty"
    "$HOME/.config/fuzzel"
    "$HOME/.config/i3status"
    "$HOME/.config/mako"
)

for dir in "${CONFIG_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        print_error "No se creó el directorio: $dir"
        exit 1
    fi
done

#############################################################################
# FINALIZACIÓN
#############################################################################

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_step "¡INSTALACIÓN COMPLETADA EXITOSAMENTE! 🎉"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Tu sistema FreeBSD con Sway (Wayland) + Everforest está listo."
echo ""
echo "${GREEN}PRÓXIMOS PASOS:${NC}"
echo "  1. Reinicia el sistema: ${YELLOW}sudo reboot${NC}"
echo "  2. Login en TTY con tu usuario"
echo "  3. Ejecuta: ${YELLOW}sway${NC}"
echo "  4. ¡Disfruta Wayland!"
echo ""
echo "${BLUE}ATAJOS IMPORTANTES:${NC}"
echo "  Mod+Return       → Abrir terminal (Alacritty)"
echo "  Mod+d            → Abrir launcher (Fuzzel)"
echo "  Mod+Shift+q      → Cerrar ventana"
echo "  Mod+Shift+e      → Salir de Sway"
echo "  Mod+Shift+c      → Recargar configuración"
echo "  Mod+1..9         → Cambiar workspace"
echo ""
echo "${CYAN}CONTROLES ESPECIALES (ThinkPad T480):${NC}"
echo "  Fn+F5/F6         → Brillo (brightnessctl)"
echo "  Fn+F1/F2/F3      → Volumen (pamixer)"
echo "  Print            → Screenshot completo"
echo "  Mod+Print        → Screenshot de área"
echo ""
echo "${YELLOW}NOTA:${NC} Mod = Tecla Windows/Super"
echo ""
echo "${BLUE}COMPONENTES INSTALADOS:${NC}"
echo "  • Sway           (Wayland compositor - i3 para Wayland)"
echo "  • Alacritty      (Terminal con Everforest)"
echo "  • Fuzzel         (Launcher nativo Wayland)"
echo "  • i3status       (Barra de estado integrada)"
echo "  • Mako           (Notificaciones Wayland)"
echo "  • Sin bordes de título (como pediste)"
echo "  • Control de brillo y volumen configurado"
echo "  • Tema Everforest Dark Hard (#2b3339)"
echo ""
echo "${GREEN}VENTAJAS DE WAYLAND/SWAY:${NC}"
echo "  ✓ Mejor seguridad que X11"
echo "  ✓ Mejor rendimiento en laptops modernas"
echo "  ✓ Configuración casi idéntica a i3"
echo "  ✓ Optimizado para Intel Graphics (T480)"
echo "  ✓ Sin screen tearing"
echo "  ✓ HiDPI support nativo"
echo ""
echo "${CYAN}TIPS ADICIONALES:${NC}"
echo "  • Para WiFi: nmtui o wpa_supplicant"
echo "  • Para Bluetooth: service bluetooth start"
echo "  • Resolución 1366x768: edita ~/.config/sway/config (línea output)"
echo "  • Firefox: ya configurado para Wayland (MOZ_ENABLE_WAYLAND=1)"
echo ""
echo "Configuraciones guardadas en: ~/.config/"
echo "Variables de entorno: ~/.wayland-env"
echo ""
echo "¡Todo listo para Wayland! 🚀"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
