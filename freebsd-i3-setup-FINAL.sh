#!/usr/bin/env bash

#############################################################################
# FreeBSD 15.0 + i3wm + Everforest - Script de Instalación Automática
# 
# INSTRUCCIONES:
# 1. Ejecutar como usuario NORMAL (no root)
# 2. Asegúrate de tener sudo configurado
# 3. Tener conexión a internet activa
#
# USO:
#   bash freebsd-i3-setup.sh
#   O:
#   chmod +x freebsd-i3-setup.sh
#   ./freebsd-i3-setup.sh
#
# Tiempo estimado: 10-20 minutos
#############################################################################

set -e  # Salir si hay algún error

# Verificar que se está ejecutando con bash
if [ -z "$BASH_VERSION" ]; then
    echo "ERROR: Este script REQUIERE bash, pero estás usando sh"
    echo ""
    echo "SOLUCIÓN:"
    echo "  sudo pkg install -y bash"
    echo "  bash freebsd-i3-setup.sh"
    exit 1
fi

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_step "Iniciando instalación de FreeBSD i3 Setup con Everforest..."
echo "Este proceso tomará entre 10-20 minutos."
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
# FASE 2: INSTALAR PAQUETES ESENCIALES
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
    polkit

#############################################################################
# FASE 3: INSTALAR XORG Y DRIVERS
#############################################################################

print_step "FASE 3/10: Instalando Xorg y drivers gráficos..."
sudo pkg install -y \
    xorg-server \
    xorg-apps \
    xf86-input-keyboard \
    xf86-input-mouse \
    xf86-input-libinput \
    xrandr \
    xdpyinfo \
    xset \
    xprop \
    xinit \
    xf86-video-vesa \
    xf86-video-scfb

# Detectar entorno de VM y instalar drivers apropiados
print_step "Detectando entorno de hardware..."

# Primero verificar si es VM o hardware real
IS_VM=false
if dmesg | grep -qi "vmware\|virtualbox\|qemu\|virtio\|hyperv\|xen"; then
    IS_VM=true
fi

if [ "$IS_VM" = true ]; then
    print_step "Detectado entorno virtualizado"
    
    if dmesg | grep -qi "vmware"; then
        print_step "VM: VMware - instalando drivers..."
        sudo pkg install -y xf86-video-vmware
        
    elif dmesg | grep -qi "virtualbox"; then
        print_step "VM: VirtualBox - instalando Guest Additions..."
        sudo pkg install -y virtualbox-ose-additions
        sudo sysrc vboxguest_enable="YES"
        sudo sysrc vboxservice_enable="YES"
        
    elif dmesg | grep -qi "qemu\|virtio"; then
        print_step "VM: QEMU/KVM - usando drivers genéricos..."
        print_warning "Usando drivers SCFB/VESA (más estables que QXL en FreeBSD 15)"
        # NO instalar xf86-video-qxl por problemas de segfault
        # SCFB y VESA ya están instalados arriba
    fi
else
    print_step "Detectado hardware real (laptop/desktop)"
    
    # Detectar GPU
    if dmesg | grep -qi "intel.*graphics\|hd graphics\|intel.*video"; then
        print_step "GPU Intel detectada - instalando drivers Intel..."
        sudo pkg install -y drm-kmod
        sudo pkg install -y xf86-video-intel || print_warning "xf86-video-intel no disponible, usando modesetting"
        
        # Agregar a rc.conf para cargar KMS al boot
        sudo sysrc kld_list+="i915kms"
        
    elif dmesg | grep -qi "amd.*radeon\|amd.*graphics"; then
        print_step "GPU AMD detectada - instalando drivers AMD..."
        sudo pkg install -y drm-kmod
        sudo sysrc kld_list+="amdgpu"
        
    elif dmesg | grep -qi "nvidia"; then
        print_step "GPU NVIDIA detectada..."
        print_warning "Drivers NVIDIA privativos no incluidos en este script"
        print_warning "Usando driver genérico. Consulta documentación de FreeBSD para drivers NVIDIA."
    else
        print_step "GPU no identificada - usando drivers genéricos"
    fi
fi

# Crear configuración de Xorg
print_step "Configurando Xorg..."
sudo mkdir -p /usr/local/etc/X11/xorg.conf.d

# Configurar según el tipo de hardware
if [ "$IS_VM" = true ]; then
    # Si es QEMU/KVM, configurar explícitamente SCFB
    if dmesg | grep -qi "qemu\|virtio"; then
        sudo tee /usr/local/etc/X11/xorg.conf.d/10-video.conf > /dev/null << 'EOF'
Section "Device"
    Identifier "Card0"
    Driver "scfb"
EndSection
EOF
        print_step "Configurado driver SCFB para QEMU/KVM"
    fi
else
    # Para hardware real, dejar que autodetecte o usar modesetting
    if dmesg | grep -qi "intel.*graphics\|hd graphics"; then
        print_step "Usando driver modesetting para Intel (recomendado en FreeBSD 15)"
        # El driver intel puede causar problemas, modesetting es más estable
        sudo tee /usr/local/etc/X11/xorg.conf.d/10-video.conf > /dev/null << 'EOF'
Section "Device"
    Identifier "Intel Graphics"
    Driver "modesetting"
    Option "AccelMethod" "glamor"
EndSection
EOF
    fi
fi

#############################################################################
# FASE 4: INSTALAR I3WM Y COMPONENTES
#############################################################################

print_step "FASE 4/10: Instalando i3wm y herramientas asociadas..."
sudo pkg install -y \
    i3 \
    i3status \
    i3lock \
    dmenu \
    dunst \
    feh \
    scrot \
    maim \
    xss-lock \
    nitrogen

#############################################################################
# FASE 5: INSTALAR KITTY, ROFI, POLYBAR, PICOM
#############################################################################

print_step "FASE 5/10: Instalando terminal, Rofi, barra de estado y Picom..."

# Instalar alacritty (alternativa a kitty, más estable en FreeBSD)
print_step "Instalando Alacritty (terminal)..."
sudo pkg install -y alacritty || {
    print_warning "Alacritty no disponible, usando xterm como fallback"
    sudo pkg install -y xterm
}

# Instalar rofi
print_step "Instalando Rofi (launcher)..."
sudo pkg install -y rofi

# Instalar i3status-rust (alternativa moderna a polybar)
print_step "Instalando i3status-rust (barra de estado)..."
sudo pkg install -y i3status-rust || {
    print_warning "i3status-rust no disponible, usando i3status estándar"
}

# Instalar picom
print_step "Instalando Picom (compositor)..."
sudo pkg install -y picom

#############################################################################
# FASE 6: INSTALAR FUENTES
#############################################################################

print_step "FASE 6/10: Instalando fuentes y Nerd Fonts..."
sudo pkg install -y \
    jetbrains-mono \
    nerd-fonts \
    noto-sans \
    noto-serif \
    font-awesome \
    hack-font \
    liberation-fonts-ttf \
    dejavu

# Actualizar caché de fuentes
fc-cache -fv

#############################################################################
# FASE 7: INSTALAR APLICACIONES ESENCIALES
#############################################################################

print_step "FASE 7/10: Instalando aplicaciones esenciales..."

# Firefox
sudo pkg install -y firefox

# File managers
print_step "Instalando file managers..."
sudo pkg install -y thunar || print_warning "Thunar no disponible"
# thunar-volman no siempre está disponible en FreeBSD 15
sudo pkg install -y thunar-volman 2>/dev/null || print_warning "thunar-volman no disponible (opcional)"
sudo pkg install -y pcmanfm || print_warning "PCManFM fallback no disponible"

# Terminal file manager
sudo pkg install -y ranger 2>/dev/null || {
    print_warning "ranger no disponible, instalando alternativa..."
    sudo pkg install -y mc
}

# Image viewers
print_step "Instalando visores de imágenes..."
sudo pkg install -y feh
sudo pkg install -y sxiv 2>/dev/null || {
    print_warning "sxiv no disponible, usando feh como visor principal"
}

# PDF viewer
sudo pkg install -y zathura zathura-pdf-mupdf

# Screenshot tools
sudo pkg install -y scrot maim
sudo pkg install -y flameshot 2>/dev/null || print_warning "flameshot no disponible (scrot/maim disponibles)"

# System info
sudo pkg install -y neofetch

# GTK theme manager
sudo pkg install -y lxappearance

#############################################################################
# FASE 8: CONFIGURAR SERVICIOS DEL SISTEMA
#############################################################################

print_step "FASE 8/10: Configurando servicios del sistema..."

# Configurar dbus
sudo sysrc dbus_enable="YES"

# Polkit puede tener diferentes nombres en FreeBSD
if pkg info polkit >/dev/null 2>&1; then
    sudo sysrc polkitd_enable="YES" 2>/dev/null || true
    sudo service polkitd start 2>/dev/null || print_warning "polkitd no se pudo iniciar (no crítico)"
else
    print_warning "polkit no instalado (no crítico para i3)"
fi

# Iniciar dbus
sudo service dbus start 2>/dev/null || true

# Configurar módulos del kernel
if ! grep -q "vmm_load" /boot/loader.conf 2>/dev/null; then
    print_step "Configurando módulos del kernel..."
    sudo sh -c 'cat >> /boot/loader.conf << EOF

# Módulos para mejor experiencia gráfica y virtualización
vmm_load="YES"
fuse_load="YES"
coretemp_load="YES"
EOF'
fi

#############################################################################
# FASE 9: CREAR TODAS LAS CONFIGURACIONES
#############################################################################

print_step "FASE 9/10: Creando configuraciones de i3, Alacritty, Rofi, i3status, Picom..."

# VERIFICACIÓN CRÍTICA: Asegurar que NO somos root
if [ "$EUID" -eq 0 ] || [ "$USER" = "root" ]; then
    print_error "ERROR: Esta sección NO debe ejecutarse como root"
    print_error "El script detectó que $HOME es /root"
    print_error "Por favor ejecuta el script como usuario normal"
    exit 1
fi

# Crear directorios necesarios
print_step "Creando directorios de configuración..."
mkdir -p ~/.config/i3
mkdir -p ~/.config/alacritty
mkdir -p ~/.config/rofi
mkdir -p ~/.config/i3status
mkdir -p ~/.config/picom
mkdir -p ~/.config/dunst
mkdir -p ~/.config/gtk-3.0
mkdir -p ~/Pictures/wallpapers

# Verificar que se crearon
if [ ! -d ~/.config/i3 ]; then
    print_error "No se pudo crear ~/.config/i3"
    exit 1
fi

#############################################################################
# 9.1 - CONFIGURACIÓN DE I3WM
#############################################################################

print_step "Configurando i3wm..."
cat > ~/.config/i3/config << 'EOF'
# i3 config file (v4) - Everforest Theme
# Mod key (Mod4 = Super/Windows)
set $mod Mod4

# Fuente
font pango:JetBrainsMono Nerd Font 10

# Iniciar servicios al arranque
exec --no-startup-id dex --autostart --environment i3
exec_always --no-startup-id picom --config ~/.config/picom/picom.conf -b
exec_always --no-startup-id feh --bg-fill ~/Pictures/wallpapers/everforest.png
exec_always --no-startup-id dunst

# xss-lock para bloquear pantalla
exec --no-startup-id xss-lock --transfer-sleep-lock -- i3lock -c 2d353b --nofork

# Usar Mouse+$mod para arrastrar ventanas flotantes
floating_modifier $mod
tiling_drag modifier titlebar

# Atajos de teclado básicos
bindsym $mod+Return exec alacritty
bindsym $mod+Shift+q kill
bindsym $mod+d exec --no-startup-id rofi -show drun -theme ~/.config/rofi/everforest.rasi
bindsym $mod+Shift+d exec --no-startup-id rofi -show run -theme ~/.config/rofi/everforest.rasi
bindsym $mod+Tab exec --no-startup-id rofi -show window -theme ~/.config/rofi/everforest.rasi

# Cambiar foco
bindsym $mod+j focus left
bindsym $mod+k focus down
bindsym $mod+l focus up
bindsym $mod+semicolon focus right
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

# Mover ventana enfocada
bindsym $mod+Shift+j move left
bindsym $mod+Shift+k move down
bindsym $mod+Shift+l move up
bindsym $mod+Shift+semicolon move right
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# Dividir orientación
bindsym $mod+h split h
bindsym $mod+v split v

# Pantalla completa
bindsym $mod+f fullscreen toggle

# Cambiar layout
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+e layout toggle split

# Toggle tiling / floating
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle

# Enfocar contenedor padre
bindsym $mod+a focus parent

# Definir workspaces
set $ws1 "1"
set $ws2 "2"
set $ws3 "3"
set $ws4 "4"
set $ws5 "5"
set $ws6 "6"
set $ws7 "7"
set $ws8 "8"
set $ws9 "9"
set $ws10 "10"

# Cambiar a workspace
bindsym $mod+1 workspace number $ws1
bindsym $mod+2 workspace number $ws2
bindsym $mod+3 workspace number $ws3
bindsym $mod+4 workspace number $ws4
bindsym $mod+5 workspace number $ws5
bindsym $mod+6 workspace number $ws6
bindsym $mod+7 workspace number $ws7
bindsym $mod+8 workspace number $ws8
bindsym $mod+9 workspace number $ws9
bindsym $mod+0 workspace number $ws10

# Mover contenedor a workspace
bindsym $mod+Shift+1 move container to workspace number $ws1
bindsym $mod+Shift+2 move container to workspace number $ws2
bindsym $mod+Shift+3 move container to workspace number $ws3
bindsym $mod+Shift+4 move container to workspace number $ws4
bindsym $mod+Shift+5 move container to workspace number $ws5
bindsym $mod+Shift+6 move container to workspace number $ws6
bindsym $mod+Shift+7 move container to workspace number $ws7
bindsym $mod+Shift+8 move container to workspace number $ws8
bindsym $mod+Shift+9 move container to workspace number $ws9
bindsym $mod+Shift+0 move container to workspace number $ws10

# Recargar configuración
bindsym $mod+Shift+c reload
bindsym $mod+Shift+r restart
bindsym $mod+Shift+e exec "i3-nagbar -t warning -m 'Salir de i3?' -B 'Sí' 'i3-msg exit'"

# Modo resize
mode "resize" {
        bindsym j resize shrink width 10 px or 10 ppt
        bindsym k resize grow height 10 px or 10 ppt
        bindsym l resize shrink height 10 px or 10 ppt
        bindsym semicolon resize grow width 10 px or 10 ppt
        bindsym Left resize shrink width 10 px or 10 ppt
        bindsym Down resize grow height 10 px or 10 ppt
        bindsym Up resize shrink height 10 px or 10 ppt
        bindsym Right resize grow width 10 px or 10 ppt
        bindsym Return mode "default"
        bindsym Escape mode "default"
        bindsym $mod+r mode "default"
}
bindsym $mod+r mode "resize"

# Screenshots
bindsym Print exec --no-startup-id maim ~/Pictures/screenshot_$(date +%Y%m%d_%H%M%S).png
bindsym $mod+Print exec --no-startup-id maim -s ~/Pictures/screenshot_$(date +%Y%m%d_%H%M%S).png

# Everforest Dark Hard Color Scheme
client.focused          #a7c080 #3d484d #d3c6aa #a7c080   #a7c080
client.focused_inactive #4b565c #2b3339 #859289 #4b565c   #4b565c
client.unfocused        #4b565c #2b3339 #859289 #4b565c   #4b565c
client.urgent           #e67e80 #e67e80 #2b3339 #e67e80   #e67e80
client.placeholder      #2b3339 #2b3339 #859289 #2b3339   #2b3339
client.background       #2b3339

# Barra de estado con i3status
bar {
    status_command i3status
    position top
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

# Gaps (opcional, descomentar si quieres espacios entre ventanas)
# gaps inner 8
# gaps outer 4
EOF

#############################################################################
# 9.2 - CONFIGURACIÓN DE ALACRITTY
#############################################################################

print_step "Configurando Alacritty..."
mkdir -p ~/.config/alacritty
cat > ~/.config/alacritty/alacritty.toml << 'EOF'
# Alacritty Terminal - Everforest Dark Hard

[window]
padding.x = 8
padding.y = 8

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

[shell]
program = "/usr/local/bin/zsh"
EOF

#############################################################################
# 9.3 - CONFIGURACIÓN DE ROFI
#############################################################################

print_step "Configurando Rofi..."
cat > ~/.config/rofi/everforest.rasi << 'EOF'
* {
    bg0:    #2b3339F2;
    bg1:    #323d43;
    bg2:    #3d484d;
    bg3:    #475258;
    
    fg0:    #d3c6aa;
    fg1:    #859289;
    
    red:    #e67e80;
    orange: #e69875;
    yellow: #dbbc7f;
    green:  #a7c080;
    cyan:   #83c092;
    blue:   #7fbbb3;
    purple: #d699b6;
    
    background-color: transparent;
    text-color: @fg0;
    
    margin: 0;
    padding: 0;
    spacing: 0;
}

window {
    location: center;
    width: 600;
    background-color: @bg0;
    border: 2px;
    border-color: @green;
    border-radius: 8;
}

inputbar {
    spacing: 8px;
    padding: 12px;
    background-color: @bg1;
    border-radius: 8 8 0 0;
}

prompt, entry, element-icon, element-text {
    vertical-align: 0.5;
}

prompt {
    text-color: @green;
}

textbox {
    padding: 8px 12px;
    background-color: @bg2;
}

listview {
    lines: 8;
    columns: 1;
    fixed-height: false;
    border: 0;
    padding: 4px 0px;
    scrollbar: false;
}

element {
    padding: 8px 12px;
    spacing: 8px;
    border-radius: 4;
}

element normal normal {
    text-color: @fg0;
}

element normal urgent {
    text-color: @red;
}

element normal active {
    text-color: @blue;
}

element selected normal, element selected active {
    background-color: @bg2;
    text-color: @green;
}

element selected urgent {
    background-color: @bg2;
    text-color: @red;
}

element-icon {
    size: 1em;
}

element-text {
    text-color: inherit;
}
EOF

#############################################################################
# 9.4 - CONFIGURACIÓN DE I3STATUS
#############################################################################

print_step "Configurando i3status..."
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
order += "disk /"
order += "memory"
order += "cpu_usage"
order += "load"
order += "tztime local"

wireless _first_ {
    format_up = "W: (%quality at %essid) %ip"
    format_down = "W: down"
}

ethernet _first_ {
    format_up = "E: %ip (%speed)"
    format_down = "E: down"
}

disk "/" {
    format = "💾 %avail"
}

memory {
    format = "🧠 %used"
    threshold_degraded = "10%"
    format_degraded = "MEMORY LOW: %free"
}

cpu_usage {
    format = "⚡ %usage"
}

load {
    format = "📊 %1min"
}

tztime local {
    format = "📅 %Y-%m-%d 🕐 %H:%M:%S"
}
EOF

mkdir -p ~/.config/i3status

#############################################################################
# 9.5 - CONFIGURACIÓN DE PICOM
#############################################################################

print_step "Configurando Picom..."
cat > ~/.config/picom/picom.conf << 'EOF'
# Picom Configuration - Everforest

backend = "glx";
vsync = true;
glx-no-stencil = true;
glx-no-rebind-pixmap = true;

# Sombras
shadow = true;
shadow-radius = 12;
shadow-opacity = 0.4;
shadow-offset-x = -12;
shadow-offset-y = -12;

shadow-exclude = [
  "name = 'Notification'",
  "class_g = 'Conky'",
  "class_g ?= 'Notify-osd'",
  "_GTK_FRAME_EXTENTS@:c"
];

# Opacidad
inactive-opacity = 0.95;
frame-opacity = 1.0;
inactive-opacity-override = false;

# Fading
fading = true;
fade-in-step = 0.03;
fade-out-step = 0.03;

# Esquinas redondeadas
corner-radius = 8;
rounded-corners-exclude = [
  "window_type = 'dock'",
  "window_type = 'desktop'"
];

# General
mark-wmwin-focused = true;
mark-ovredir-focused = true;
detect-rounded-corners = true;
detect-client-opacity = true;
detect-transient = true;
use-damage = true;

wintypes:
{
  tooltip = { fade = true; shadow = true; opacity = 0.95; focus = true; };
  dock = { shadow = false; }
  dnd = { shadow = false; }
};
EOF

#############################################################################
# 9.6 - CONFIGURACIÓN DE DUNST
#############################################################################

print_step "Configurando Dunst (notificaciones)..."
cat > ~/.config/dunst/dunstrc << 'EOF'
[global]
    monitor = 0
    follow = mouse
    width = (0, 350)
    height = 300
    origin = top-right
    offset = 15x45
    notification_limit = 0
    progress_bar = true
    progress_bar_height = 10
    progress_bar_frame_width = 1
    indicate_hidden = yes
    separator_height = 2
    padding = 12
    horizontal_padding = 12
    frame_width = 2
    frame_color = "#a7c080"
    separator_color = frame
    font = JetBrainsMono Nerd Font 10
    markup = full
    format = "<b>%s</b>\n%b"
    alignment = left
    show_age_threshold = 60
    icon_position = left
    min_icon_size = 32
    max_icon_size = 64
    sticky_history = yes
    history_length = 20
    corner_radius = 8
    mouse_left_click = close_current
    mouse_middle_click = do_action, close_current
    mouse_right_click = close_all

[urgency_low]
    background = "#2b3339"
    foreground = "#d3c6aa"
    timeout = 5

[urgency_normal]
    background = "#2b3339"
    foreground = "#d3c6aa"
    frame_color = "#a7c080"
    timeout = 10

[urgency_critical]
    background = "#2b3339"
    foreground = "#d3c6aa"
    frame_color = "#e67e80"
    timeout = 0
EOF

#############################################################################
# 9.7 - CREAR WALLPAPER EVERFOREST
#############################################################################

print_step "Creando wallpaper Everforest..."
# Crear imagen sólida de fondo con ImageMagick si está disponible
if command -v convert &> /dev/null; then
    convert -size 1920x1080 xc:'#2b3339' ~/Pictures/wallpapers/everforest.png
else
    # Si no está ImageMagick, instalar y crear
    sudo pkg install -y ImageMagick7
    convert -size 1920x1080 xc:'#2b3339' ~/Pictures/wallpapers/everforest.png
fi

#############################################################################
# 9.8 - CONFIGURAR .XINITRC
#############################################################################

print_step "Configurando .xinitrc..."
cat > ~/.xinitrc << 'EOF'
#!/bin/sh

# Cargar recursos de X
[ -f ~/.Xresources ] && xrdb -merge ~/.Xresources

# Configurar teclado (ajusta según tu layout)
setxkbmap -layout latam

# Iniciar i3
exec i3
EOF
chmod +x ~/.xinitrc

#############################################################################
# 9.9 - CONFIGURAR GTK
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
# FASE 10: VERIFICACIÓN Y FINALIZACIÓN
#############################################################################

print_step "FASE 10/10: Verificando instalación..."

# Verificar que los binarios existen
REQUIRED_BINS=("i3" "alacritty" "rofi" "picom" "dunst" "feh")
MISSING=()

for bin in "${REQUIRED_BINS[@]}"; do
    if ! command -v "$bin" &> /dev/null; then
        MISSING+=("$bin")
    fi
done

if [ ${#MISSING[@]} -ne 0 ]; then
    print_error "Faltan los siguientes programas: ${MISSING[*]}"
    print_warning "Intenta instalarlos manualmente con: sudo pkg install ${MISSING[*]}"
    exit 1
fi

# Verificar que las configuraciones se crearon
CONFIG_DIRS=(
    "$HOME/.config/i3"
    "$HOME/.config/alacritty"
    "$HOME/.config/rofi"
    "$HOME/.config/i3status"
    "$HOME/.config/picom"
    "$HOME/.config/dunst"
)

for dir in "${CONFIG_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        print_error "No se creó el directorio: $dir"
        exit 1
    fi
done

# Crear .zshrc básico si no existe
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
# FINALIZACIÓN
#############################################################################

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_step "¡INSTALACIÓN COMPLETADA EXITOSAMENTE! 🎉"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Tu sistema FreeBSD con i3wm + Everforest está listo."
echo ""
echo "${GREEN}PRÓXIMOS PASOS:${NC}"
echo "  1. Cierra sesión o sal al TTY (Ctrl+Alt+F1)"
echo "  2. Ejecuta: ${YELLOW}startx${NC}"
echo "  3. ¡Disfruta tu nuevo entorno!"
echo ""
echo "${BLUE}ATAJOS IMPORTANTES:${NC}"
echo "  Mod+Enter        → Abrir terminal (Alacritty)"
echo "  Mod+d            → Abrir launcher (Rofi)"
echo "  Mod+Shift+q      → Cerrar ventana"
echo "  Mod+Shift+e      → Salir de i3"
echo "  Mod+Shift+r      → Reiniciar i3"
echo "  Mod+1..9         → Cambiar workspace"
echo ""
echo "${YELLOW}NOTA:${NC} Mod = Tecla Windows/Super"
echo ""
echo "${BLUE}COMPONENTES INSTALADOS:${NC}"
echo "  • i3wm           (Window Manager)"
echo "  • Alacritty      (Terminal con Everforest)"
echo "  • Rofi           (Launcher personalizado)"
echo "  • i3status       (Barra de estado integrada)"
echo "  • Picom          (Compositor con efectos)"
echo "  • Dunst          (Notificaciones)"
echo ""
echo "Configuraciones guardadas en: ~/.config/"
echo "Para respaldo, considera crear un repo de dotfiles."
echo ""
echo "¡Todo listo! 🚀"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
