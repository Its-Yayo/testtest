#!/bin/bash

#############################################################################
# FreeBSD 15.0 + i3wm + Everforest - Script de Instalación Automática
# 
# INSTRUCCIONES:
# 1. Ejecutar como usuario NORMAL (no root)
# 2. Asegúrate de tener sudo configurado
# 3. Tener conexión a internet activa
#
# USO:
#   chmod +x freebsd-i3-setup.sh
#   ./freebsd-i3-setup.sh
#
# Tiempo estimado: 10-20 minutos
#############################################################################

set -e  # Salir si hay algún error

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
print_step "Detectando entorno de virtualización..."
if dmesg | grep -qi "vmware"; then
    print_step "Detectado VMware, instalando drivers..."
    sudo pkg install -y xf86-video-vmware
elif dmesg | grep -qi "virtualbox"; then
    print_step "Detectado VirtualBox, instalando Guest Additions..."
    sudo pkg install -y virtualbox-ose-additions
    sudo sysrc vboxguest_enable="YES"
    sudo sysrc vboxservice_enable="YES"
elif dmesg | grep -qi "qemu\|virtio"; then
    print_step "Detectado QEMU/KVM, instalando drivers..."
    sudo pkg install -y xf86-video-qxl
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

print_step "FASE 5/10: Instalando Kitty, Rofi, Polybar y Picom..."
sudo pkg install -y \
    kitty \
    rofi \
    polybar \
    picom

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
sudo pkg install -y \
    firefox \
    thunar \
    thunar-volman \
    ranger \
    feh \
    sxiv \
    zathura \
    zathura-pdf-mupdf \
    flameshot \
    neofetch \
    lxappearance

#############################################################################
# FASE 8: CONFIGURAR SERVICIOS DEL SISTEMA
#############################################################################

print_step "FASE 8/10: Configurando servicios del sistema..."

# Configurar dbus y polkit
sudo sysrc dbus_enable="YES"
sudo sysrc polkitd_enable="YES"

# Iniciar servicios
sudo service dbus start 2>/dev/null || true
sudo service polkitd start 2>/dev/null || true

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

print_step "FASE 9/10: Creando configuraciones de i3, Kitty, Rofi, Polybar, Picom..."

# Crear directorios necesarios
mkdir -p ~/.config/{i3,kitty,rofi,polybar,picom,dunst,gtk-3.0}
mkdir -p ~/Pictures/wallpapers

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
exec_always --no-startup-id ~/.config/polybar/launch.sh
exec_always --no-startup-id picom --config ~/.config/picom/picom.conf -b
exec_always --no-startup-id feh --bg-fill ~/Pictures/wallpapers/everforest.png
exec_always --no-startup-id dunst

# xss-lock para bloquear pantalla
exec --no-startup-id xss-lock --transfer-sleep-lock -- i3lock -c 2d353b --nofork

# Usar Mouse+$mod para arrastrar ventanas flotantes
floating_modifier $mod
tiling_drag modifier titlebar

# Atajos de teclado básicos
bindsym $mod+Return exec kitty
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

# Gaps (opcional, descomentar si quieres espacios entre ventanas)
# gaps inner 8
# gaps outer 4
EOF

#############################################################################
# 9.2 - CONFIGURACIÓN DE KITTY
#############################################################################

print_step "Configurando Kitty..."
cat > ~/.config/kitty/kitty.conf << 'EOF'
# Kitty Terminal - Everforest Dark Hard

# Fuentes
font_family      JetBrainsMono Nerd Font
bold_font        JetBrainsMono Nerd Font Bold
italic_font      JetBrainsMono Nerd Font Italic
bold_italic_font JetBrainsMono Nerd Font Bold Italic
font_size 11.0

# Cursor
cursor_shape block
cursor_blink_interval 0

# Scrollback
scrollback_lines 10000

# Mouse
mouse_hide_wait 3.0
url_color #a7c080
url_style curly

# Performance
repaint_delay 10
input_delay 3
sync_to_monitor yes

# Bell
enable_audio_bell no

# Window
remember_window_size  yes
initial_window_width  1200
initial_window_height 700
window_padding_width 8

# Tab bar
tab_bar_edge top
tab_bar_style powerline
tab_powerline_style slanted

# Shell
shell zsh
editor nvim

# Everforest Dark Hard Colors
foreground #d3c6aa
background #2b3339
selection_foreground #2b3339
selection_background #a7c080

cursor #d3c6aa
cursor_text_color #2b3339

# Normal colors
color0 #4b565c
color1 #e67e80
color2 #a7c080
color3 #dbbc7f
color4 #7fbbb3
color5 #d699b6
color6 #83c092
color7 #d3c6aa

# Bright colors
color8  #4b565c
color9  #e67e80
color10 #a7c080
color11 #dbbc7f
color12 #7fbbb3
color13 #d699b6
color14 #83c092
color15 #d3c6aa

# Tab colors
active_tab_foreground   #2b3339
active_tab_background   #a7c080
inactive_tab_foreground #d3c6aa
inactive_tab_background #3d484d

# Keybindings
map ctrl+shift+c copy_to_clipboard
map ctrl+shift+v paste_from_clipboard
map ctrl+shift+equal change_font_size all +1.0
map ctrl+shift+minus change_font_size all -1.0
map ctrl+shift+backspace change_font_size all 0
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
# 9.4 - CONFIGURACIÓN DE POLYBAR
#############################################################################

print_step "Configurando Polybar..."
cat > ~/.config/polybar/config.ini << 'EOF'
[colors]
background = #2b3339
background-alt = #3d484d
foreground = #d3c6aa
foreground-alt = #859289
primary = #a7c080
secondary = #7fbbb3
alert = #e67e80
green = #a7c080
yellow = #dbbc7f
orange = #e69875
red = #e67e80
purple = #d699b6
cyan = #83c092

[bar/main]
width = 100%
height = 28
radius = 0
fixed-center = true

background = ${colors.background}
foreground = ${colors.foreground}

line-size = 3
line-color = ${colors.primary}

padding-left = 1
padding-right = 1

module-margin-left = 1
module-margin-right = 1

font-0 = JetBrainsMono Nerd Font:size=10;2
font-1 = JetBrainsMono Nerd Font:size=12;3

modules-left = i3
modules-center = date
modules-right = filesystem memory cpu temperature

tray-position = right
tray-padding = 2
tray-background = ${colors.background-alt}

cursor-click = pointer

[module/i3]
type = internal/i3
format = <label-state> <label-mode>
index-sort = true
wrapping-scroll = false
pin-workspaces = true

label-mode-padding = 2
label-mode-foreground = ${colors.background}
label-mode-background = ${colors.primary}

label-focused = %index%
label-focused-background = ${colors.background-alt}
label-focused-underline= ${colors.primary}
label-focused-padding = 2

label-unfocused = %index%
label-unfocused-padding = 2

label-visible = %index%
label-visible-background = ${self.label-focused-background}
label-visible-underline = ${self.label-focused-underline}
label-visible-padding = ${self.label-focused-padding}

label-urgent = %index%
label-urgent-background = ${colors.alert}
label-urgent-padding = 2

[module/cpu]
type = internal/cpu
interval = 2
format-prefix = "󰻠 "
format-prefix-foreground = ${colors.cyan}
label = %percentage:2%%

[module/memory]
type = internal/memory
interval = 2
format-prefix = "󰍛 "
format-prefix-foreground = ${colors.green}
label = %percentage_used%%

[module/date]
type = internal/date
interval = 5
date = "%Y-%m-%d"
time = %H:%M
format-prefix = "󰃰 "
format-prefix-foreground = ${colors.yellow}
label = %date% %time%

[module/temperature]
type = internal/temperature
thermal-zone = 0
warn-temperature = 70
format = <label>
format-prefix = "󰔏 "
format-prefix-foreground = ${colors.orange}
format-warn = <label-warn>
format-warn-prefix = "󰔏 "
format-warn-prefix-foreground = ${colors.red}
label = %temperature-c%
label-warn = %temperature-c%
label-warn-foreground = ${colors.alert}

[module/filesystem]
type = internal/fs
interval = 25
mount-0 = /
format-mounted-prefix = "󰋊 "
format-mounted-prefix-foreground = ${colors.cyan}
label-mounted = %percentage_used%%

[settings]
screenchange-reload = true

[global/wm]
margin-top = 0
margin-bottom = 0
EOF

# Crear script de lanzamiento de Polybar
cat > ~/.config/polybar/launch.sh << 'EOF'
#!/usr/bin/env bash
killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done
polybar main 2>&1 | tee -a /tmp/polybar_main.log & disown
EOF
chmod +x ~/.config/polybar/launch.sh

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
REQUIRED_BINS=("i3" "kitty" "rofi" "polybar" "picom" "dunst" "feh")
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
    "$HOME/.config/kitty"
    "$HOME/.config/rofi"
    "$HOME/.config/polybar"
    "$HOME/.config/picom"
    "$HOME/.config/dunst"
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
echo "Tu sistema FreeBSD con i3wm + Everforest está listo."
echo ""
echo "${GREEN}PRÓXIMOS PASOS:${NC}"
echo "  1. Cierra sesión o sal al TTY (Ctrl+Alt+F1)"
echo "  2. Ejecuta: ${YELLOW}startx${NC}"
echo "  3. ¡Disfruta tu nuevo entorno!"
echo ""
echo "${BLUE}ATAJOS IMPORTANTES:${NC}"
echo "  Mod+Enter        → Abrir terminal (Kitty)"
echo "  Mod+d            → Abrir launcher (Rofi)"
echo "  Mod+Shift+q      → Cerrar ventana"
echo "  Mod+Shift+e      → Salir de i3"
echo "  Mod+Shift+r      → Reiniciar i3"
echo "  Mod+1..9         → Cambiar workspace"
echo ""
echo "${YELLOW}NOTA:${NC} Mod = Tecla Windows/Super"
echo ""
echo "Configuraciones guardadas en: ~/.config/"
echo "Para respaldo, considera crear un repo de dotfiles."
echo ""
echo "¡Todo listo! 🚀"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
