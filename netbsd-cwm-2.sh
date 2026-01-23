#!/bin/sh
#
# evergreenbsd_netbsd.sh - NetBSD CWM Setup with Everforest Hard Theme
# Ultra minimalista, sin bordes, directo y profesional
#
# Uso: sudo sh evergreenbsd_netbsd.sh
#

set -e  # Exit on error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Everforest Hard Palette
EF_BG0="#2b3339"
EF_BG1="#323c41"
EF_BG2="#3a464c"
EF_FG="#d3c6aa"
EF_RED="#e67e80"
EF_ORANGE="#e69875"
EF_YELLOW="#dbbc7f"
EF_GREEN="#a7c080"
EF_CYAN="#83c092"
EF_BLUE="#7fbbb3"
EF_PURPLE="#d699b6"
EF_GREY="#7a8478"

print_step() {
    echo "${GREEN}==>${NC} $1"
}

print_error() {
    echo "${RED}ERROR:${NC} $1"
    exit 1
}

print_warning() {
    echo "${YELLOW}WARNING:${NC} $1"
}

# Verificar que estamos en NetBSD
if [ "$(uname -s)" != "NetBSD" ]; then
    print_error "Este script es solo para NetBSD"
fi

# Verificar permisos de root
if [ "$(id -u)" -ne 0 ]; then
    print_error "Ejecuta con sudo: sudo sh evergreenbsd_netbsd.sh"
fi

# Guardar usuario real
REAL_USER="${SUDO_USER:-$USER}"
if [ "$REAL_USER" = "root" ]; then
    print_error "No ejecutes como root directo, usa: sudo sh evergreenbsd_netbsd.sh"
fi

USER_HOME=$(eval echo ~"$REAL_USER")

# Detectar el grupo primario del usuario automáticamente
REAL_GROUP=$(id -gn "$REAL_USER" 2>/dev/null || echo "users")

print_step "Iniciando instalación para usuario: $REAL_USER"
print_step "Grupo del usuario: $REAL_GROUP"
print_step "Home directory: $USER_HOME"

# ============================================================================
# FASE 1: VERIFICACIÓN Y ACTUALIZACIÓN DEL SISTEMA
# ============================================================================

print_step "FASE 1: Verificando sistema NetBSD..."

# Verificar que pkgin está instalado
if ! command -v pkgin >/dev/null 2>&1; then
    print_error "pkgin no está instalado. Instala pkgin primero con: pkg_add pkgin"
fi

print_step "Actualizando repositorios de pkgin..."
pkgin -y update || print_warning "No se pudo actualizar pkgin (puede ser normal)"

# Actualizar pkgin mismo
print_step "Actualizando pkgin..."
pkgin -y upgrade pkgin || true

# ============================================================================
# FASE 2: INSTALACIÓN DE PAQUETES
# ============================================================================

print_step "FASE 2: Instalando paquetes necesarios..."

# Lista de paquetes REALES en NetBSD pkgsrc
PACKAGES="
    cwm
    lemonbar
    dmenu
    feh
    scrot
    sxhkd
    xclip
    xterm
    firefox
    vim
    git
    htop
    ranger
    picom
    dunst
    maim
    xdotool
    xautolock
    ImageMagick
    bash
"

for pkg in $PACKAGES; do
    print_step "Instalando: $pkg"
    if ! pkgin -y install "$pkg" 2>/dev/null; then
        print_warning "No se pudo instalar $pkg (puede que no exista o ya esté instalado)"
    fi
done

# ============================================================================
# FASE 3: CONFIGURACIÓN DE SERVICIOS DEL SISTEMA
# ============================================================================

print_step "FASE 3: Configurando servicios del sistema..."

# En NetBSD, configurar rc.conf para servicios
RC_CONF="/etc/rc.conf"

# Deshabilitar xdm si está habilitado (usaremos startx)
if grep -q "^xdm=YES" "$RC_CONF" 2>/dev/null; then
    print_step "Deshabilitando xdm..."
    sed -i.bak 's/^xdm=YES/xdm=NO/' "$RC_CONF"
fi

# Habilitar dbus (messagebus)
if ! grep -q "^dbus=YES" "$RC_CONF" 2>/dev/null; then
    print_step "Habilitando dbus..."
    echo "dbus=YES" >> "$RC_CONF"
fi

# Iniciar dbus si no está corriendo
if ! pgrep -x dbus-daemon >/dev/null; then
    print_step "Iniciando dbus..."
    /etc/rc.d/dbus start || true
fi

# ============================================================================
# FASE 4: CONFIGURACIÓN DE AUDIO
# ============================================================================

print_step "FASE 4: Configurando audio NetBSD..."

# NetBSD usa audio(4) y audioctl/mixerctl
# Verificar que el driver de audio está cargado
if ! audioctl 2>/dev/null | grep -q "name"; then
    print_warning "Driver de audio no detectado. Puede necesitar configuración manual."
fi

# Crear script helper para control de volumen
mkdir -p "$USER_HOME/.local/bin"

cat > "$USER_HOME/.local/bin/vol-up" <<'EOF'
#!/bin/sh
# Aumentar volumen en NetBSD
current=$(mixerctl -n outputs.master | cut -d, -f1)
new=$((current + 10))
[ $new -gt 255 ] && new=255
mixerctl -w outputs.master=$new,$new
EOF

cat > "$USER_HOME/.local/bin/vol-down" <<'EOF'
#!/bin/sh
# Disminuir volumen en NetBSD
current=$(mixerctl -n outputs.master | cut -d, -f1)
new=$((current - 10))
[ $new -lt 0 ] && new=0
mixerctl -w outputs.master=$new,$new
EOF

cat > "$USER_HOME/.local/bin/vol-mute" <<'EOF'
#!/bin/sh
# Toggle mute en NetBSD
mixerctl -w outputs.master.mute=toggle
EOF

chmod +x "$USER_HOME/.local/bin/vol-up"
chmod +x "$USER_HOME/.local/bin/vol-down"
chmod +x "$USER_HOME/.local/bin/vol-mute"

# ============================================================================
# FASE 5: CONFIGURACIÓN DE CWM
# ============================================================================

print_step "FASE 5: Configurando CWM (Calm Window Manager)..."

# Crear directorio de configuración
mkdir -p "$USER_HOME/.config"

# Configuración de CWM - Ultra minimalista, sin bordes ni títulos
cat > "$USER_HOME/.cwmrc" <<EOF
# CWM Configuration - Everforest Hard Theme
# Ultra minimalista - Sin bordes, sin títulos, directo

# TEMA EVERFOREST HARD
color activeborder   "$EF_GREEN"
color inactiveborder "$EF_BG2"
color urgencyborder  "$EF_RED"
color groupborder    "$EF_BLUE"
color ungroupborder  "$EF_GREY"
color menubg         "$EF_BG0"
color menufg         "$EF_FG"
color font           "$EF_FG"

# SIN BORDES - Ventanas ocupan TODO el espacio
borderwidth 0
gap 0 0 25 0

# Fuente
fontname "monospace:size=10"

# IGNORE - No mostrar en menú (minimalista)
ignore lemonbar
ignore dunst
ignore picom

# AUTOGROUP - Organizar ventanas automáticamente
autogroup 1 "Firefox"
autogroup 2 "firefox"
autogroup 2 "XTerm"
autogroup 3 "Vim"

# STICKY - Ventanas que aparecen en todos los workspaces
sticky lemonbar

# KEYBINDINGS - Atajos de teclado

# Workspaces (grupos)
bind-key 4-1 group-only-1
bind-key 4-2 group-only-2
bind-key 4-3 group-only-3
bind-key 4-4 group-only-4
bind-key 4-5 group-only-5
bind-key 4-6 group-only-6
bind-key 4-7 group-only-7
bind-key 4-8 group-only-8
bind-key 4-9 group-only-9

# Mover ventana a workspace
bind-key 4S-1 window-movetogroup-1
bind-key 4S-2 window-movetogroup-2
bind-key 4S-3 window-movetogroup-3
bind-key 4S-4 window-movetogroup-4
bind-key 4S-5 window-movetogroup-5
bind-key 4S-6 window-movetogroup-6
bind-key 4S-7 window-movetogroup-7
bind-key 4S-8 window-movetogroup-8
bind-key 4S-9 window-movetogroup-9

# Cerrar ventana
bind-key 4-q window-close

# Fullscreen
bind-key 4-f window-fullscreen

# Maximizar
bind-key 4-m window-maximize

# Ocultar ventana
bind-key 4-h window-hide

# Ciclar ventanas
bind-key 4-Tab window-cycle
bind-key 4S-Tab window-rcycle

# Launcher (dmenu)
bind-key 4-d "dmenu_run -fn 'monospace:size=10' -nb '$EF_BG0' -nf '$EF_FG' -sb '$EF_GREEN' -sf '$EF_BG0'"

# Terminal
bind-key 4-Return "xterm -fa 'monospace' -fs 10 -bg '$EF_BG0' -fg '$EF_FG'"

# Browser
bind-key 4-w firefox

# Screenshot completo
bind-key 4-Print "scrot ~/Pictures/screenshot_%Y%m%d_%H%M%S.png"

# Screenshot selección
bind-key 4S-Print "scrot -s ~/Pictures/screenshot_%Y%m%d_%H%M%S.png"

# Control de volumen
bind-key XF86AudioRaiseVolume "vol-up"
bind-key XF86AudioLowerVolume "vol-down"
bind-key XF86AudioMute "vol-mute"

# Control de brillo
bind-key XF86MonBrightnessUp "brightness-up"
bind-key XF86MonBrightnessDown "brightness-down"

# Reload CWM
bind-key 4S-r restart

# Lock screen
bind-key 4-l "xlock -mode blank"

# UNBIND teclas que no usamos
unbind-key all
EOF

chown "$REAL_USER:$REAL_GROUP" "$USER_HOME/.cwmrc"

# ============================================================================
# FASE 6: CONFIGURACIÓN DE LEMONBAR
# ============================================================================

print_step "FASE 6: Configurando Lemonbar..."

mkdir -p "$USER_HOME/.config/lemonbar"

# Script de lemonbar con tema Everforest Hard
cat > "$USER_HOME/.config/lemonbar/lemonbar.sh" <<'LEMONEOF'
#!/usr/bin/env bash
# Lemonbar para CWM - Everforest Hard Theme - NetBSD

# Colores Everforest Hard
BG="#2b3339"
FG="#d3c6aa"
GREEN="#a7c080"
BLUE="#7fbbb3"
YELLOW="#dbbc7f"
RED="#e67e80"
GREY="#7a8478"

# Función para workspaces
workspaces() {
    # En CWM los grupos van del 1-9
    # NetBSD puede no tener xprop con _NET_CURRENT_DESKTOP
    # Usamos un enfoque más simple
    ws=""
    for i in 1 2 3 4 5 6 7 8 9; do
        ws="$ws %{F$GREY}$i%{F-} "
    done
    echo "$ws"
}

# Función para fecha/hora
datetime() {
    date '+%a %d %b %H:%M'
}

# Función para batería (si existe)
battery() {
    if command -v envstat >/dev/null 2>&1; then
        # NetBSD usa envstat para batería
        bat_info=$(envstat -d acpibat0 2>/dev/null | grep "charge:" | head -1)
        if [ -n "$bat_info" ]; then
            bat_percent=$(echo "$bat_info" | awk '{print $2}' | tr -d '%')
            
            if [ "$bat_percent" -gt 80 ]; then
                icon="BAT"
                color="$GREEN"
            elif [ "$bat_percent" -gt 20 ]; then
                icon="BAT"
                color="$YELLOW"
            else
                icon="BAT"
                color="$RED"
            fi
            
            echo "%{F$color}$icon $bat_percent%%%{F-}"
        else
            echo ""
        fi
    else
        echo ""
    fi
}

# Función para volumen
volume() {
    if command -v mixerctl >/dev/null 2>&1; then
        vol=$(mixerctl -n outputs.master 2>/dev/null | cut -d, -f1)
        if [ -n "$vol" ]; then
            vol_percent=$(echo "scale=0; $vol * 100 / 255" | bc 2>/dev/null || echo "50")
            echo "%{F$BLUE}VOL $vol_percent%%%{F-}"
        else
            echo ""
        fi
    else
        echo ""
    fi
}

# Función para CPU
cpu_usage() {
    # NetBSD top tiene formato diferente
    cpu=$(top -b -n 1 2>/dev/null | grep "CPU states" | awk '{print $3}' | tr -d '%' | cut -d. -f1)
    if [ -z "$cpu" ]; then
        cpu="0"
    fi
    echo "%{F$YELLOW}CPU ${cpu}%%%{F-}"
}

# Función para RAM
mem_usage() {
    # Usar vmstat para memoria en NetBSD
    mem=$(vmstat 2>/dev/null | tail -1 | awk '{print $4}')
    if [ -n "$mem" ]; then
        mem_mb=$((mem / 1024))
        echo "%{F$BLUE}MEM ${mem_mb}M%{F-}"
    else
        echo "%{F$BLUE}MEM --%{F-}"
    fi
}

# Loop principal
while true; do
    # Lado izquierdo - Workspaces
    left="$(workspaces)"
    
    # Lado derecho - Info del sistema
    right="$(cpu_usage) | $(mem_usage) | $(volume) | $(battery) | $(datetime)"
    
    # Output formateado
    echo "%{l}  $left%{r}$right  "
    
    sleep 2
done
LEMONEOF

chmod +x "$USER_HOME/.config/lemonbar/lemonbar.sh"
chown "$REAL_USER:$REAL_GROUP" "$USER_HOME/.config/lemonbar/lemonbar.sh"

# ============================================================================
# FASE 7: CONFIGURACIÓN DE XTERM
# ============================================================================

print_step "FASE 7: Configurando XTerm con tema Everforest..."

cat > "$USER_HOME/.Xresources" <<EOF
! XTerm - Everforest Hard Theme

! Fuente
XTerm*faceName: monospace
XTerm*faceSize: 10

! Colores Everforest Hard
XTerm*background: #2b3339
XTerm*foreground: #d3c6aa
XTerm*cursorColor: #d3c6aa

! Negro
XTerm*color0: #374247
XTerm*color8: #4a555b

! Rojo
XTerm*color1: #e67e80
XTerm*color9: #e67e80

! Verde
XTerm*color2: #a7c080
XTerm*color10: #a7c080

! Amarillo
XTerm*color3: #dbbc7f
XTerm*color11: #dbbc7f

! Azul
XTerm*color4: #7fbbb3
XTerm*color12: #7fbbb3

! Magenta
XTerm*color5: #d699b6
XTerm*color13: #d699b6

! Cyan
XTerm*color6: #83c092
XTerm*color14: #83c092

! Blanco
XTerm*color7: #d3c6aa
XTerm*color15: #e5dfc5

! Configuración
XTerm*saveLines: 10000
XTerm*scrollBar: false
XTerm*loginShell: true
XTerm*termName: xterm-256color

! Copiar/Pegar mejorado
XTerm*selectToClipboard: true
XTerm*VT100.translations: #override \\
    Ctrl Shift <Key>C: copy-selection(CLIPBOARD) \\n\\
    Ctrl Shift <Key>V: insert-selection(CLIPBOARD)
EOF

chown "$REAL_USER:$REAL_GROUP" "$USER_HOME/.Xresources"

# ============================================================================
# FASE 8: CONFIGURACIÓN DE DUNST (Notificaciones)
# ============================================================================

print_step "FASE 8: Configurando Dunst (notificaciones)..."

mkdir -p "$USER_HOME/.config/dunst"

cat > "$USER_HOME/.config/dunst/dunstrc" <<EOF
[global]
    font = monospace 10
    markup = yes
    format = "<b>%s</b>\\n%b"
    sort = yes
    indicate_hidden = yes
    alignment = left
    show_age_threshold = 60
    word_wrap = yes
    ignore_newline = no
    width = 300
    height = 200
    offset = 10x30
    transparency = 10
    separator_height = 2
    padding = 8
    horizontal_padding = 8
    separator_color = frame
    frame_width = 2
    
[urgency_low]
    background = "$EF_BG0"
    foreground = "$EF_FG"
    frame_color = "$EF_GREEN"
    timeout = 5

[urgency_normal]
    background = "$EF_BG0"
    foreground = "$EF_FG"
    frame_color = "$EF_BLUE"
    timeout = 10

[urgency_critical]
    background = "$EF_BG0"
    foreground = "$EF_FG"
    frame_color = "$EF_RED"
    timeout = 0
EOF

chown -R "$REAL_USER:$REAL_GROUP" "$USER_HOME/.config/dunst"

# ============================================================================
# FASE 9: CONFIGURACIÓN DE .xinitrc
# ============================================================================

print_step "FASE 9: Configurando .xinitrc para inicio automático..."

cat > "$USER_HOME/.xinitrc" <<'EOF'
#!/bin/sh
# .xinitrc - Everforest Hard Setup - NetBSD

# Cargar recursos de X
xrdb -merge ~/.Xresources

# Configurar teclado (ajusta según tu layout)
setxkbmap -layout us

# Deshabilitar beep
xset b off

# Configuración de pantalla
xset s off
xset -dpms
xset s noblank

# PATH para scripts locales
export PATH="$HOME/.local/bin:$PATH"

# Wallpaper (crear directorio si no existe)
mkdir -p ~/Pictures/wallpapers
# Si tienes feh y una imagen, usa:
# feh --bg-fill ~/Pictures/wallpapers/everforest.png &

# Compositor (transparencias y sombras ligeras) - opcional
# picom -b &

# Notificaciones
dunst &

# Lemonbar
bash ~/.config/lemonbar/lemonbar.sh | lemonbar -g x25 -f "monospace:size=10" -B "#2b3339" -F "#d3c6aa" &

# Screenshots directory
mkdir -p ~/Pictures

# Iniciar CWM
exec cwm
EOF

chmod +x "$USER_HOME/.xinitrc"
chown "$REAL_USER:$REAL_GROUP" "$USER_HOME/.xinitrc"

# ============================================================================
# FASE 10: CONFIGURACIÓN DE BRIGHTNESS (Brillo de pantalla)
# ============================================================================

print_step "FASE 10: Configurando control de brillo..."

# En NetBSD, el brillo también se controla via wsconsctl
# Crear scripts helper para el usuario

# Script para aumentar brillo
cat > "$USER_HOME/.local/bin/brightness-up" <<'EOF'
#!/bin/sh
current=$(wsconsctl -n display.brightness 2>/dev/null || echo 50)
new=$((current + 10))
[ $new -gt 100 ] && new=100
sudo wsconsctl -w display.brightness=$new 2>/dev/null || echo "Brightness control not available"
EOF

# Script para disminuir brillo
cat > "$USER_HOME/.local/bin/brightness-down" <<'EOF'
#!/bin/sh
current=$(wsconsctl -n display.brightness 2>/dev/null || echo 50)
new=$((current - 10))
[ $new -lt 0 ] && new=0
sudo wsconsctl -w display.brightness=$new 2>/dev/null || echo "Brightness control not available"
EOF

chmod +x "$USER_HOME/.local/bin/brightness-up"
chmod +x "$USER_HOME/.local/bin/brightness-down"
chown -R "$REAL_USER:$REAL_GROUP" "$USER_HOME/.local"

# Agregar al PATH en shell config
if [ ! -f "$USER_HOME/.profile" ]; then
    touch "$USER_HOME/.profile"
    chown "$REAL_USER:$REAL_GROUP" "$USER_HOME/.profile"
fi

if ! grep -q ".local/bin" "$USER_HOME/.profile" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$USER_HOME/.profile"
fi

# Si usa bash
if [ -f "$USER_HOME/.bashrc" ]; then
    if ! grep -q ".local/bin" "$USER_HOME/.bashrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$USER_HOME/.bashrc"
    fi
fi

# ============================================================================
# FASE 11: CONFIGURACIÓN DE SUDOERS PARA BRIGHTNESS
# ============================================================================

print_step "FASE 11: Configurando sudoers para control de brillo sin password..."

# Crear archivo en sudoers.d para NetBSD
SUDOERS_FILE="/usr/pkg/etc/sudoers.d/brightness"

# Verificar si el directorio sudoers.d existe
if [ -d "/usr/pkg/etc/sudoers.d" ] || [ -d "/etc/sudoers.d" ]; then
    if [ -d "/usr/pkg/etc/sudoers.d" ]; then
        SUDOERS_FILE="/usr/pkg/etc/sudoers.d/brightness"
    else
        SUDOERS_FILE="/etc/sudoers.d/brightness"
    fi
    
    cat > "$SUDOERS_FILE" <<SUDOEOF
# Allow brightness control without password
$REAL_USER ALL=(ALL) NOPASSWD: /sbin/wsconsctl
SUDOEOF
    
    chmod 0440 "$SUDOERS_FILE"
    print_step "Configurado sudoers para control de brillo"
else
    print_warning "No se encontró directorio sudoers.d, configurar manualmente si es necesario"
fi

# ============================================================================
# FASE 12: CONFIGURACIÓN DE VIM
# ============================================================================

print_step "FASE 12: Configurando Vim con tema Everforest..."

cat > "$USER_HOME/.vimrc" <<EOF
" Vim Configuration - Everforest Hard

syntax on
set number
set relativenumber
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent
set background=dark
colorscheme default

" Colores básicos Everforest-like
hi Normal ctermbg=234 ctermfg=223
hi LineNr ctermbg=235 ctermfg=243
hi CursorLine ctermbg=236
hi Comment ctermfg=243
hi String ctermfg=108
hi Function ctermfg=142
EOF

chown "$REAL_USER:$REAL_GROUP" "$USER_HOME/.vimrc"

# ============================================================================
# FASE 13: CONFIGURACIÓN DE BASH (Shell mejorado)
# ============================================================================

print_step "FASE 13: Configurando Bash..."

# Crear .bashrc si no existe
if [ ! -f "$USER_HOME/.bashrc" ]; then
    cat > "$USER_HOME/.bashrc" <<'EOF'
# .bashrc - Everforest Hard Theme

# Alias útiles
alias ls='ls -G'
alias ll='ls -lah'
alias ..='cd ..'
alias ...='cd ../..'

# Prompt con colores Everforest
PS1='\[\033[38;5;108m\]\u\[\033[0m\]@\[\033[38;5;142m\]\h\[\033[0m\]:\[\033[38;5;109m\]\w\[\033[0m\]\$ '

# PATH
export PATH="$HOME/.local/bin:$PATH"

# Editor
export EDITOR=vim
export VISUAL=vim
EOF
    chown "$REAL_USER:$REAL_GROUP" "$USER_HOME/.bashrc"
fi

# ============================================================================
# FASE 14: INFORMACIÓN FINAL Y VERIFICACIÓN
# ============================================================================

print_step "FASE 14: Finalizando instalación..."

# Crear archivo de información
cat > "$USER_HOME/EVERFOREST_INFO.txt" <<EOF
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║      EVERFOREST HARD - NetBSD CWM Setup Completo 🌲          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

INSTALACIÓN COMPLETADA EXITOSAMENTE EN NetBSD!

PRÓXIMOS PASOS:
===============

1. REBOOT del sistema:
   $ sudo reboot

2. Después del reboot, inicia sesión y ejecuta:
   $ startx

3. ATAJOS DE TECLADO (Super/Windows Key = Mod4):
   
   WORKSPACES:
   -----------
   Super + 1-9           : Cambiar a workspace 1-9
   Super + Shift + 1-9   : Mover ventana a workspace 1-9
   
   VENTANAS:
   ---------
   Super + Q             : Cerrar ventana
   Super + F             : Fullscreen
   Super + M             : Maximizar
   Super + H             : Ocultar ventana
   Super + Tab           : Ciclar ventanas
   
   APLICACIONES:
   -------------
   Super + Enter         : Terminal (xterm)
   Super + D             : Launcher (dmenu)
   Super + W             : Firefox
   Super + L             : Lock screen
   
   SCREENSHOTS:
   ------------
   Super + PrintScreen       : Screenshot completo
   Super + Shift + PrintScreen : Screenshot selección
   
   MULTIMEDIA (si tu teclado tiene teclas multimedia):
   ---------------------------------------------------
   XF86AudioRaiseVolume  : Subir volumen
   XF86AudioLowerVolume  : Bajar volumen
   XF86AudioMute         : Mute
   XF86MonBrightnessUp   : Subir brillo
   XF86MonBrightnessDown : Bajar brillo
   
   SISTEMA:
   --------
   Super + Shift + R     : Recargar CWM

4. CONTROL DE BRILLO (ThinkPad):
   $ brightness-up       : Aumentar brillo
   $ brightness-down     : Disminuir brillo

5. CONTROL DE VOLUMEN:
   $ vol-up              : Subir volumen
   $ vol-down            : Bajar volumen
   $ vol-mute            : Toggle mute
   
   O directamente con mixerctl:
   $ mixerctl -w outputs.master=200,200    : Volumen alto
   $ mixerctl -w outputs.master=100,100    : Volumen medio
   $ mixerctl -w outputs.master=0,0        : Mute

ARCHIVOS DE CONFIGURACIÓN:
==========================
- CWM:        ~/.cwmrc
- Lemonbar:   ~/.config/lemonbar/lemonbar.sh
- XTerm:      ~/.Xresources
- Dunst:      ~/.config/dunst/dunstrc
- Vim:        ~/.vimrc
- Xinitrc:    ~/.xinitrc
- Bash:       ~/.bashrc

TEMA:
=====
Everforest Hard - Paleta de colores oscuros con tonos verdes forestales

DIFERENCIAS NetBSD vs OpenBSD:
===============================
- Package manager: pkgin (en lugar de pkg_add)
- Permisos: sudo (en lugar de doas)
- CWM: Instalado desde pkgsrc (no viene en base)
- Audio: mixerctl (similar a OpenBSD)
- Servicios: rc.conf (similar a OpenBSD)

SERVICIOS CONFIGURADOS:
=======================
- dbus (messagebus)
- Audio NetBSD nativo

WALLPAPERS:
===========
Coloca tus wallpapers en: ~/Pictures/wallpapers/
Edita ~/.xinitrc para configurar feh

TROUBLESHOOTING:
================
- Si lemonbar no aparece: verifica que bash esté instalado
- Si no hay audio: ejecuta 'audioctl' para ver dispositivos
- Si CWM no inicia: verifica que X esté configurado correctamente
- Para logs de X: cat ~/.xsession-errors

HARDWARE (ThinkPad T480s):
==========================
NetBSD tiene excelente soporte para ThinkPads:
- Intel graphics: funciona out-of-box
- WiFi Intel: puede requerir firmware adicional
- Trackpad: funciona con synaptics o libinput
- Brillo: wsconsctl (igual que OpenBSD)

Para instalar firmware WiFi si es necesario:
$ pkgin install iwn-firmware

COMANDOS ÚTILES NetBSD:
=======================
- Actualizar paquetes: pkgin upgrade
- Buscar paquetes: pkgin search <nombre>
- Info del sistema: sysctl hw
- Estado batería: envstat -d acpibat0
- Audio devices: audioctl

¡DISFRUTA TU SETUP MINIMALISTA EN NetBSD! 🌲

EOF

chown "$REAL_USER:$REAL_GROUP" "$USER_HOME/EVERFOREST_INFO.txt"

# Mostrar resumen
echo ""
echo "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo "${GREEN}    INSTALACIÓN COMPLETADA EN NetBSD! 🌲${NC}"
echo "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo "📄 Lee el archivo: ${BLUE}~/EVERFOREST_INFO.txt${NC} para más información"
echo ""
echo "🔄 PRÓXIMOS PASOS:"
echo "   1. ${YELLOW}sudo reboot${NC}"
echo "   2. Después del reboot: ${YELLOW}startx${NC}"
echo ""
echo "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""

# Verificación final
print_step "Verificando instalación..."
ERRORS=0

# Verificar que los archivos de config se crearon
for file in ".cwmrc" ".xinitrc" ".Xresources" ".vimrc"; do
    if [ ! -f "$USER_HOME/$file" ]; then
        print_warning "Archivo $file no se creó correctamente"
        ERRORS=$((ERRORS + 1))
    fi
done

# Verificar que CWM está instalado
if ! command -v cwm >/dev/null 2>&1; then
    print_warning "CWM no se detecta en PATH. Puede necesitar relogin."
else
    print_step "✓ CWM instalado correctamente"
fi

# Verificar lemonbar
if ! command -v lemonbar >/dev/null 2>&1; then
    print_warning "lemonbar no se detecta en PATH"
else
    print_step "✓ lemonbar instalado correctamente"
fi

if [ $ERRORS -eq 0 ]; then
    print_step "✓ Todos los archivos de configuración creados correctamente"
else
    print_warning "Algunos archivos no se crearon. Revisa los warnings arriba."
fi

print_step "Script completado. Sistema NetBSD listo para reboot."

echo ""
echo "${BLUE}NOTA IMPORTANTE:${NC} NetBSD puede requerir configuración adicional de X11."
echo "Si X no inicia, ejecuta: ${YELLOW}X -configure${NC} como root para generar xorg.conf"
echo ""

exit 0
