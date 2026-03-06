#!/bin/bash
# =============================================================================
# setup-sway-void.sh
# Instalación completa del entorno Sway Nord para Void Linux
# T480s — UEFI — Wayland — PipeWire — Nord Theme
#
# Ejecutar como tu usuario (no como root):
#   bash setup-sway-void.sh
#
# Requisitos previos:
#   - Sistema base Void instalado y arrancado
#   - doas configurado con tu usuario en wheel
#   - Red funcionando (NetworkManager activo)
# =============================================================================

set -e  # Para el script si cualquier comando falla

# Colores para los mensajes del script (irónico que usemos Nord también aquí)
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# =============================================================================
# PASO 1 — SINCRONIZAR REPOSITORIOS E INSTALAR PAQUETES
# =============================================================================

info "Sincronizando repositorios de Void..."
doas xbps-install -Syu

info "Instalando Sway y compositor Wayland..."
doas xbps-install -y \
    sway \
    swaybg \
    swayidle \
    swaylock \
    swaynag

info "Instalando Waybar..."
doas xbps-install -y \
    waybar

info "Instalando terminal Alacritty..."
doas xbps-install -y \
    alacritty

info "Instalando lanzador Fuzzel..."
doas xbps-install -y \
    fuzzel

info "Instalando herramientas de screenshot (grim + slurp)..."
doas xbps-install -y \
    grim \
    slurp

info "Instalando audio — PipeWire + WirePlumber..."
# PipeWire es el stack de audio moderno de Linux equivalente a lo que usabas
# wpctl reemplaza tu 'mixer' de FreeBSD con la misma filosofía
doas xbps-install -y \
    pipewire \
    wireplumber \
    pipewire-pulse \
    alsa-pipewire

info "Instalando control de brillo — brightnessctl..."
# brightnessctl reemplaza tu 'backlight -f intel_backlight0' de FreeBSD
# El concepto es idéntico: incrementar/decrementar el brillo en porcentaje
doas xbps-install -y \
    brightnessctl

info "Instalando fuentes — Iosevka Nerd Font y Cascadia Code..."
# Iosevka Nerd Font es la que usan Alacritty, Waybar y Fuzzel
# Cascadia Code PL es la que usa Sway para los títulos de ventana
doas xbps-install -y \
    font-iosevka-nerd-fonts \
    font-cascadia-code

info "Instalando utilidades de Wayland y soporte XWayland..."
# xdg-user-dirs crea tus carpetas de usuario estándar (Pictures, Downloads, etc)
# xdg-utils es necesario para que apps abran URLs y archivos correctamente
# xwayland permite correr apps X11 antiguas dentro de Sway si lo necesitas
doas xbps-install -y \
    xdg-user-dirs \
    xdg-utils \
    xwayland \
    polkit \
    rtkit

info "Instalando utilidades visuales y de sistema..."
doas xbps-install -y \
    wl-clipboard \
    foot \
    imv

# =============================================================================
# PASO 2 — HABILITAR SERVICIOS DE AUDIO
# =============================================================================

info "Habilitando servicios de PipeWire en runit..."
# En Void con runit los servicios de audio del usuario se manejan
# diferente a systemd — usamos el mecanismo de servicios de usuario
# PipeWire se lanza desde la sesión Wayland, no como servicio del sistema

# Crea el directorio de servicios del usuario si no existe
mkdir -p "$HOME/.config/runit/sv"

# Configura PipeWire para que arranque con la sesión
doas xbps-install -y pipewire-session-manager 2>/dev/null || true

# Añade el usuario al grupo audio como respaldo
doas usermod -aG audio "$USER"

success "Servicios de audio configurados."

# =============================================================================
# PASO 3 — CREAR ESTRUCTURA DE DIRECTORIOS
# =============================================================================

info "Creando estructura de directorios de configuración..."

mkdir -p "$HOME/.config/sway"
mkdir -p "$HOME/.config/waybar"
mkdir -p "$HOME/.config/alacritty"
mkdir -p "$HOME/.config/fuzzel"
mkdir -p "$HOME/Pictures/wallpapers"
mkdir -p "$HOME/Pictures"

# Inicializa las carpetas de usuario estándar (crea ~/Pictures, ~/Downloads, etc.)
xdg-user-dirs-update

success "Directorios creados."

# =============================================================================
# PASO 4 — CONFIGURACIÓN DE SWAY
# =============================================================================

info "Escribiendo configuración de Sway..."

# El colors file va separado como lo tienes en FreeBSD
cat > "$HOME/.config/sway/colors" << 'EOF'
client.focused          #88C0D0 #3B4252 #ECEFF4 #88C0D0   #88C0D0
client.focused_inactive #434C5E #2E3440 #4C566A #434C5E   #434C5E
client.unfocused        #434C5E #2E3440 #4C566A #434C5E   #434C5E
client.urgent           #BF616A #BF616A #ECEFF4 #BF616A   #BF616A
client.placeholder      #2E3440 #2E3440 #D8DEE9 #2E3440   #2E3440
client.background       #2E3440
EOF

# Config principal de Sway
# CAMBIOS respecto a FreeBSD:
#   - mixer vol=+5%  →  wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
#   - backlight -f intel_backlight0  →  brightnessctl set 2%+/-
# TODO LO DEMÁS es idéntico: keybindings, gaps, colores, touchpad, idle, lock
cat > "$HOME/.config/sway/config" << 'EOF'
# Sway config — Nord Theme
# T480s — Void Linux

# Mod key (Mod4 = Super/Windows)
set $mod Mod4

# Resolución del T480s
output eDP-1 scale 1.60

# Fuente para títulos de ventana
font pango:Cascadia Code PL 10

# Terminal y lanzador
set $term alacritty
set $menu fuzzel

# Bordes
default_border none
default_floating_border none
for_window [class=".*"] border pixel 4
for_window [app_id=".*"] border pixel 4

# Gaps
gaps inner 8
gaps outer 2

# Colores Nord — incluido desde el archivo colors
include ~/.config/sway/colors

# Wallpaper — pon aquí tu imagen después de instalar
output * bg ~/Pictures/wallpapers/nordic_trascendence.png fill

# Idle y lock — idéntico a FreeBSD
exec swayidle -w \
    timeout 1300 'swaylock -f -c 2b3339' \
    timeout 600 'swaymsg "output * dpms off"' \
    resume 'swaymsg "output * dpms on"' \
    before-sleep 'swaylock -f -c 2b3339'

# Teclado — layout US como en FreeBSD
input type:keyboard {
    xkb_layout "us"
}

# Touchpad ThinkPad T480s — configuración completa
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

# Terminal
bindsym $mod+t exec $term

# Matar ventana
bindsym $mod+q kill

# Lanzador
bindsym $mod+a exec $menu

# Recargar configuración
bindsym $mod+Shift+c reload

# Salir de Sway
bindsym $mod+Shift+e exec swaynag -t warning -m 'Goodbye from Sway?' -B 'S' 'swaymsg exit'

# Navegación entre ventanas
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

# =========================================================
# CONTROL DE VOLUMEN
# Reemplaza 'mixer' de FreeBSD con wpctl (WirePlumber/PipeWire)
# La lógica es idéntica: subir, bajar, silenciar
# =========================================================
bindsym XF86AudioRaiseVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindsym XF86AudioLowerVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindsym XF86AudioMute        exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

# =========================================================
# CONTROL DE BRILLO
# Reemplaza 'backlight -f intel_backlight0' de FreeBSD con brightnessctl
# =========================================================
bindsym XF86MonBrightnessUp   exec brightnessctl set 2%+
bindsym XF86MonBrightnessDown exec brightnessctl set 2%-

# =========================================================
# SCREENSHOTS — idéntico a FreeBSD (grim + slurp son nativos Wayland)
# =========================================================
bindsym Print       exec grim ~/Pictures/screenshot_$(date +%Y%m%d_%H%M%S).png
bindsym $mod+Print  exec grim -g "$(slurp)" ~/Pictures/screenshot_$(date +%Y%m%d_%H%M%S).png

# Modo resize
mode "resize" {
    bindsym Left  resize shrink width 10px
    bindsym Down  resize grow height 10px
    bindsym Up    resize shrink height 10px
    bindsym Right resize grow width 10px

    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

# Waybar
bar {
    swaybar_command waybar
}
EOF

success "Configuración de Sway escrita."

# =============================================================================
# PASO 5 — CONFIGURACIÓN DE WAYBAR
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
    "cpu": { "format": " {usage}%" },
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

#cpu    { border-bottom: 2px solid #81A1C1; }
#memory { border-bottom: 2px solid #B48EAD; }
#battery { border-bottom: 2px solid #A3BE8C; }

#tray {
    margin: 5px 6px;
}
EOF

success "Configuración de Waybar escrita."

# =============================================================================
# PASO 6 — CONFIGURACIÓN DE ALACRITTY
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

success "Configuración de Alacritty escrita."

# =============================================================================
# PASO 7 — CONFIGURACIÓN DE FUZZEL
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
background    = 2E3440ee
text          = D8DEE9ff
match         = 88C0D0ff
selection     = 3B4252ff
selection-text = ECEFF4ff
border        = 88C0D0ff

[border]
width = 2
radius = 8
EOF

success "Configuración de Fuzzel escrita."

# =============================================================================
# PASO 8 — CONFIGURAR PIPEWIRE PARA ARRANCAR CON LA SESIÓN
# =============================================================================

info "Configurando PipeWire para arrancar con la sesión de Sway..."

# En Void Linux sin systemd, PipeWire se lanza mediante el entorno Wayland
# Añadimos los exec al perfil del usuario para que arranquen con Sway
# Esto va dentro del config de Sway directamente al final
cat >> "$HOME/.config/sway/config" << 'EOF'

# =========================================================
# AUDIO — PipeWire arranca con la sesión Wayland
# =========================================================
exec pipewire
exec pipewire-pulse
exec wireplumber
EOF

success "PipeWire configurado para arrancar con Sway."

# =============================================================================
# PASO 9 — VARIABLES DE ENTORNO WAYLAND
# =============================================================================

info "Configurando variables de entorno para Wayland..."

# Este archivo se sourcea al iniciar sesión desde TTY
# Garantiza que las apps usen el backend Wayland nativo
cat > "$HOME/.profile" << 'EOF'
# Variables de entorno para sesión Wayland/Sway
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=sway
export XDG_CURRENT_DESKTOP=sway

# Qt — usar backend Wayland nativo
export QT_QPA_PLATFORM=wayland

# SDL — usar Wayland
export SDL_VIDEODRIVER=wayland

# Java en Wayland
export _JAVA_AWT_WM_NONREPARENTING=1

# Iniciar Sway automáticamente si estamos en TTY1
# Comenta estas líneas si prefieres arrancar Sway manualmente con 'sway'
if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
    exec sway
fi
EOF

success "Variables de entorno escritas en ~/.profile"

# =============================================================================
# PASO 10 — PERMISOS DE BRIGHTNESSCTL
# =============================================================================

info "Configurando permisos de brightnessctl..."

# brightnessctl necesita pertenecer al grupo video para funcionar sin root
doas usermod -aG video "$USER"

success "Usuario añadido al grupo video para brightnessctl."

# =============================================================================
# RESUMEN FINAL
# =============================================================================

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Instalación completa. Tu setup Nord está listo.${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo "  Lo único que tienes que hacer antes de arrancar Sway:"
echo ""
echo "  1. Pon tu wallpaper en:"
echo "     ~/Pictures/wallpapers/nordic_trascendence.png"
echo ""
echo "  2. Cierra sesión y vuelve a entrar al TTY para que"
echo "     ~/.profile aplique las variables de entorno."
echo ""
echo "  3. Escribe 'sway' en el TTY (o se arranca automáticamente"
echo "     si estás en TTY1 gracias al ~/.profile)."
echo ""
echo "  Cambios respecto a FreeBSD:"
echo "  - Volumen:  wpctl en lugar de mixer"
echo "  - Brillo:   brightnessctl en lugar de backlight"
echo "  - Todo lo demás: idéntico."
echo ""
echo -e "${CYAN}  Filion está listo.${NC}"
echo ""
