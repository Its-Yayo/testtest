#!/bin/bash
# =============================================================================
# setup-sway-void.sh — v2
# Entorno Sway Nord completo para Void Linux — T480s
# Paquetes verificados contra void-packages oficial en GitHub
#
# Ejecutar como tu usuario:
#   bash setup-sway-void.sh
# =============================================================================

# SIN set -e — si un paquete falla el script continúa y te avisa al final
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }

FAILED_PKGS=()

install_pkg() {
    if doas xbps-install -y "$@"; then
        success "Instalado: $*"
    else
        warn "Falló: $* — continuando..."
        FAILED_PKGS+=("$@")
    fi
}

# =============================================================================
# PASO 1 — SINCRONIZAR REPOS
# =============================================================================

info "Sincronizando repositorios..."
doas xbps-install -Syu

# =============================================================================
# PASO 2 — SWAY
# sway incluye swaynag — NO es un paquete separado (verificado)
# swaylock, swayidle y swaybg SÍ son paquetes separados (verificado)
# =============================================================================

info "Instalando Sway y componentes Wayland..."
install_pkg sway
install_pkg swaylock
install_pkg swayidle
install_pkg swaybg

# =============================================================================
# PASO 3 — WAYBAR, ALACRITTY, FUZZEL
# Verificados: los tres existen con este nombre exacto en Void
# =============================================================================

info "Instalando Waybar, Alacritty y Fuzzel..."
install_pkg waybar
install_pkg alacritty
install_pkg fuzzel

# =============================================================================
# PASO 4 — SCREENSHOTS
# grim y slurp son nativos Wayland — verificados en Void
# =============================================================================

info "Instalando herramientas de screenshot..."
install_pkg grim
install_pkg slurp

# =============================================================================
# PASO 5 — AUDIO: PIPEWIRE + WIREPLUMBER
# Verificados en void-packages: pipewire, wireplumber, pipewire-pulse, alsa-pipewire
# =============================================================================

info "Instalando PipeWire..."
install_pkg pipewire
install_pkg wireplumber
install_pkg pipewire-pulse
install_pkg alsa-pipewire

# =============================================================================
# PASO 6 — BRILLO
# brightnessctl — verificado en Void. Reemplaza 'backlight' de FreeBSD
# =============================================================================

info "Instalando brightnessctl..."
install_pkg brightnessctl

# =============================================================================
# PASO 7 — FUENTES
# Verificados contra void-packages oficial:
#   font-iosevka           — paquete base Iosevka (confirmado en GitHub de Iosevka)
#   nerd-fonts-ttf         — contiene todos los Nerd Fonts TTF incluyendo Iosevka NF
#                            AVISO: es ~400MB, tarda un poco
#   font-cascadia-code-ttf — nombre exacto confirmado en void-packages PR #14604
# =============================================================================

info "Instalando fuentes (nerd-fonts-ttf puede tardar, es ~400MB)..."
install_pkg font-iosevka
install_pkg nerd-fonts-ttf
install_pkg font-cascadia-code-ttf

# =============================================================================
# PASO 8 — SOPORTE WAYLAND Y GESTIÓN DE SESIÓN
# polkit: acceso al hardware sin root
# elogind: gestión de sesión sin systemd — necesario para Sway desde TTY
# dbus: necesario para PipeWire, polkit y NetworkManager
# xwayland: para apps X11 dentro de Sway (opcional pero útil)
# =============================================================================

info "Instalando soporte Wayland y gestión de sesión..."
install_pkg polkit
install_pkg elogind
install_pkg dbus
install_pkg xwayland
install_pkg wl-clipboard
install_pkg xdg-user-dirs
install_pkg xdg-utils
install_pkg inotify-tools

# =============================================================================
# PASO 9 — HABILITAR SERVICIOS EN RUNIT
# =============================================================================

info "Habilitando servicios en runit..."

if [ ! -L /var/service/dbus ]; then
    doas ln -s /etc/sv/dbus /var/service/dbus
    success "dbus habilitado"
else
    warn "dbus ya estaba habilitado"
fi

if [ ! -L /var/service/elogind ]; then
    doas ln -s /etc/sv/elogind /var/service/elogind
    success "elogind habilitado"
else
    warn "elogind ya estaba habilitado"
fi

doas usermod -aG video "$USER"
success "Usuario añadido al grupo video (para brightnessctl)"

doas usermod -aG _seatd "$USER" 2>/dev/null || warn "Grupo _seatd no existe aún — no es crítico"

# =============================================================================
# PASO 10 — DIRECTORIOS
# =============================================================================

info "Creando directorios de configuración..."
mkdir -p "$HOME/.config/sway"
mkdir -p "$HOME/.config/waybar"
mkdir -p "$HOME/.config/alacritty"
mkdir -p "$HOME/.config/fuzzel"
mkdir -p "$HOME/Pictures/wallpapers"
xdg-user-dirs-update 2>/dev/null || true
success "Directorios creados."

# =============================================================================
# PASO 11 — CONFIG SWAY
# Colores Nord intactos. Keybindings idénticos a FreeBSD.
# Únicos cambios:
#   mixer vol=+5%                  → wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
#   backlight -f intel_backlight0  → brightnessctl set 2%+/-
# =============================================================================

info "Escribiendo configuración de Sway..."

cat > "$HOME/.config/sway/colors" << 'EOF'
client.focused          #88C0D0 #3B4252 #ECEFF4 #88C0D0   #88C0D0
client.focused_inactive #434C5E #2E3440 #4C566A #434C5E   #434C5E
client.unfocused        #434C5E #2E3440 #4C566A #434C5E   #434C5E
client.urgent           #BF616A #BF616A #ECEFF4 #BF616A   #BF616A
client.placeholder      #2E3440 #2E3440 #D8DEE9 #2E3440   #2E3440
client.background       #2E3440
EOF

cat > "$HOME/.config/sway/config" << 'EOF'
# Sway config — Nord Theme
# Void Linux — ThinkPad T480s

set $mod Mod4

output eDP-1 scale 1.60

font pango:Cascadia Code PL 10

set $term alacritty
set $menu fuzzel

default_border none
default_floating_border none
for_window [class=".*"] border pixel 4
for_window [app_id=".*"] border pixel 4

gaps inner 8
gaps outer 2

include ~/.config/sway/colors

output * bg ~/Pictures/wallpapers/nordic_trascendence.png fill

exec swayidle -w \
    timeout 1300 'swaylock -f -c 2b3339' \
    timeout 600 'swaymsg "output * dpms off"' \
    resume 'swaymsg "output * dpms on"' \
    before-sleep 'swaylock -f -c 2b3339'

# PipeWire arranca con la sesión Wayland
exec pipewire
exec pipewire-pulse
exec wireplumber

input type:keyboard {
    xkb_layout "us"
}

input type:touchpad {
    tap enabled
    natural_scroll enabled
    dwt enabled
    accel_profile adaptive
    pointer_accel 0.5
}

# =========================================================
# KEYBINDINGS — IDÉNTICOS A FREEBSD
# =========================================================

bindsym $mod+t exec $term
bindsym $mod+q kill
bindsym $mod+a exec $menu
bindsym $mod+Shift+c reload
bindsym $mod+Shift+e exec swaynag -t warning -m 'Goodbye from Sway?' -B 'S' 'swaymsg exit'

bindsym $mod+Left  focus left
bindsym $mod+Down  focus down
bindsym $mod+Up    focus up
bindsym $mod+Right focus right

bindsym $mod+Shift+Left  move left
bindsym $mod+Shift+Down  move down
bindsym $mod+Shift+Up    move up
bindsym $mod+Shift+Right move right

bindsym $mod+h splith
bindsym $mod+v splitv
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+e layout toggle split
bindsym $mod+f fullscreen

bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle

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

# VOLUMEN — wpctl reemplaza 'mixer' de FreeBSD
bindsym XF86AudioRaiseVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindsym XF86AudioLowerVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindsym XF86AudioMute        exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

# BRILLO — brightnessctl reemplaza 'backlight -f intel_backlight0' de FreeBSD
bindsym XF86MonBrightnessUp   exec brightnessctl set 2%+
bindsym XF86MonBrightnessDown exec brightnessctl set 2%-

# SCREENSHOTS — idéntico a FreeBSD
bindsym Print      exec grim ~/Pictures/screenshot_$(date +%Y%m%d_%H%M%S).png
bindsym $mod+Print exec grim -g "$(slurp)" ~/Pictures/screenshot_$(date +%Y%m%d_%H%M%S).png

mode "resize" {
    bindsym Left  resize shrink width 10px
    bindsym Down  resize grow height 10px
    bindsym Up    resize shrink height 10px
    bindsym Right resize grow width 10px
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

bar {
    swaybar_command waybar
}
EOF

success "Config de Sway escrita."

# =============================================================================
# PASO 12 — CONFIG WAYBAR
# Idéntica a FreeBSD — Nord intacto
# =============================================================================

info "Escribiendo configuración de Waybar..."

cat > "$HOME/.config/waybar/config.jsonc" << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 36,
    "spacing": 5,
    "modules-left": ["sway/workspaces", "sway/mode"],
    "modules-center": ["clock"],
    "modules-right": ["cpu", "memory", "battery", "tray"],

    "sway/workspaces": {
        "disable-scroll": true,
        "all-outputs": true,
        "format": "{name}",
        "on-click": "activate"
    },
    "clock": {
        "format": " {:%H:%M}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{unit_calendar}</small></tt>"
    },
    "cpu":    { "format": " {usage}%" },
    "memory": { "format": " {percentage}%" },
    "battery": {
        "states": { "warning": 30, "critical": 15 },
        "format": "{icon} {capacity}%",
        "format-icons": ["", "", "", "", ""]
    }
}
EOF

cat > "$HOME/.config/waybar/style.css" << 'EOF'
* {
    border: none;
    border-radius: 0;
    font-family: "Iosevka Nerd Font Mono";
    font-size: 15px;
    font-weight: bold;
    min-height: 0;
}

window#waybar {
    background-color: #2E3440;
    color: #D8DEE9;
    min-height: 24px;
}

#workspaces {
    margin: 2px 6px;
}

#workspaces button {
    background-color: #3B4252;
    color: transparent;
    padding: 3px 6px;
    margin: 2px 3px;
    border-radius: 14px 14px 8px 8px;
    min-width: 10px;
    opacity: 0.25;
    transition: opacity 0.2s ease;
}

#workspaces button:hover {
    opacity: 0.5;
}

#workspaces button.focused,
#workspaces button.active {
    background-color: #81A1C1;
    opacity: 1;
    padding: 3px 8px;
}

#workspaces button.urgent {
    background-color: #BF616A;
    opacity: 1;
}

#clock {
    color: #ECEFF4;
    background-color: #3B4252;
    padding: 0 16px;
    margin: 4px 0;
    border-radius: 10px;
}

#cpu, #memory, #battery {
    color: #D8DEE9;
    background-color: #3B4252;
    padding: 0 12px;
    margin: 5px 3px;
    border-radius: 10px;
}

#cpu     { border-bottom: 2px solid #81A1C1; }
#memory  { border-bottom: 2px solid #B48EAD; }
#battery { border-bottom: 2px solid #A3BE8C; }

#tray {
    margin: 5px 6px;
}
EOF

success "Config de Waybar escrita."

# =============================================================================
# PASO 13 — CONFIG ALACRITTY
# Idéntica a FreeBSD — Nord intacto
# =============================================================================

info "Escribiendo configuración de Alacritty..."

cat > "$HOME/.config/alacritty/alacritty.toml" << 'EOF'
[window]
padding.x = 7
padding.y = 7
opacity = 0.95

[font]
size = 12

[font.normal]
family = "Iosevka Nerd Font Mono"
style = "Regular"

[font.bold]
family = "Iosevka Nerd Font Mono"
style = "Bold"

[font.italic]
family = "Iosevka Nerd Font Mono"
style = "Italic"

[font.bold_italic]
family = "Iosevka Nerd Font Mono"
style = "Bold Italic"

[colors.primary]
background = "#2E3440"
foreground = "#D8DEE9"

[colors.cursor]
text   = "#2E3440"
cursor = "#88C0D0"

[colors.normal]
black   = "#3B4252"
red     = "#BF616A"
green   = "#A3BE8C"
yellow  = "#EBCB8B"
blue    = "#81A1C1"
magenta = "#B48EAD"
cyan    = "#88C0D0"
white   = "#E5E9F0"

[colors.bright]
black   = "#4C566A"
red     = "#BF616A"
green   = "#A3BE8C"
yellow  = "#EBCB8B"
blue    = "#81A1C1"
magenta = "#B48EAD"
cyan    = "#8FBCBB"
white   = "#ECEFF4"
EOF

success "Config de Alacritty escrita."

# =============================================================================
# PASO 14 — CONFIG FUZZEL
# Idéntica a FreeBSD — Nord intacto
# =============================================================================

info "Escribiendo configuración de Fuzzel..."

cat > "$HOME/.config/fuzzel/fuzzel.ini" << 'EOF'
[main]
terminal = alacritty
layer = overlay
width = 40
lines = 12
horizontal-pad = 20
vertical-pad = 10

[colors]
background     = 2E3440ee
text           = D8DEE9ff
match          = 88C0D0ff
selection      = 3B4252ff
selection-text = ECEFF4ff
border         = 88C0D0ff

[border]
width = 2
radius = 8
EOF

success "Config de Fuzzel escrita."

# =============================================================================
# PASO 15 — ~/.profile PARA ARRANQUE DESDE TTY
# =============================================================================

info "Configurando ~/.profile..."

cat > "$HOME/.profile" << 'EOF'
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=sway
export XDG_CURRENT_DESKTOP=sway
export QT_QPA_PLATFORM=wayland
export SDL_VIDEODRIVER=wayland
export _JAVA_AWT_WM_NONREPARENTING=1

# Arranca Sway automáticamente en TTY1
if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" = "1" ]; then
    exec sway
fi
EOF

success "~/.profile configurado."

# =============================================================================
# RESUMEN FINAL
# =============================================================================

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Listo. Filion está casi en casa.${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""

if [ ${#FAILED_PKGS[@]} -gt 0 ]; then
    echo -e "${RED}  Paquetes que fallaron — revisa manualmente:${NC}"
    for pkg in "${FAILED_PKGS[@]}"; do
        echo -e "${RED}    - $pkg${NC}"
    done
    echo ""
fi

echo "  Antes de arrancar Sway:"
echo "  1. Copia tu wallpaper a ~/Pictures/wallpapers/nordic_trascendence.png"
echo "  2. Cierra sesión y vuelve a entrar al TTY1"
echo "  3. Sway arrancará automáticamente, o escribe 'sway'"
echo ""
echo "  Cambios respecto a FreeBSD:"
echo "    Volumen:  wpctl en lugar de mixer"
echo "    Brillo:   brightnessctl en lugar de backlight"
echo "    Todo lo demás: idéntico."
echo ""
