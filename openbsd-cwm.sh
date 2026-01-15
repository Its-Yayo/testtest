#!/bin/sh
#
# evergreenbsd.sh - OpenBSD CWM Setup with Everforest Hard Theme
# Ultra minimalista, sin bordes, directo y profesional
#
# Uso: doas sh evergreenbsd.sh
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

# Verificar que estamos en OpenBSD
if [ "$(uname -s)" != "OpenBSD" ]; then
    print_error "Este script es solo para OpenBSD"
fi

# Verificar permisos de root
if [ "$(id -u)" -ne 0 ]; then
    print_error "Ejecuta con doas: doas sh evergreenbsd.sh"
fi

# Guardar usuario real
REAL_USER="${SUDO_USER:-$USER}"
if [ "$REAL_USER" = "root" ]; then
    print_error "No ejecutes como root directo, usa: doas sh evergreenbsd.sh"
fi

USER_HOME=$(eval echo ~"$REAL_USER")

print_step "Iniciando instalación para usuario: $REAL_USER"
print_step "Home directory: $USER_HOME"

# ============================================================================
# FASE 1: VERIFICACIÓN Y ACTUALIZACIÓN DEL SISTEMA
# ============================================================================

print_step "FASE 1: Verificando sistema y actualizando base de datos de paquetes..."

# Actualizar lista de paquetes
pkg_add -u || print_warning "No se pudo actualizar la lista de paquetes (puede ser normal)"

# ============================================================================
# FASE 2: INSTALACIÓN DE PAQUETES
# ============================================================================

print_step "FASE 2: Instalando paquetes necesarios..."

PACKAGES="
    lemonbar
    dmenu
    feh
    scrot
    sxhkd
    xclip
    xterm
    firefox
    vim--no_x11
    git
    htop
    ranger
    picom
    dunst
    maim
    xdotool
    xautolock
"

for pkg in $PACKAGES; do
    print_step "Instalando: $pkg"
    if ! pkg_add "$pkg" 2>/dev/null; then
        print_warning "No se pudo instalar $pkg (puede que no exista o ya esté instalado)"
    fi
done

# Instalar firmware (especialmente WiFi para ThinkPad)
print_step "Instalando firmware del sistema..."
fw_update || print_warning "fw_update falló (normal si ya está actualizado)"

# ============================================================================
# FASE 3: CONFIGURACIÓN DE SERVICIOS DEL SISTEMA
# ============================================================================

print_step "FASE 3: Configurando servicios del sistema..."

# Habilitar apmd para power management (crucial para laptop)
print_step "Habilitando apmd para gestión de energía..."
rcctl enable apmd
rcctl set apmd flags -A
rcctl start apmd || true

# Deshabilitar xenodm (usaremos startx manual)
print_step "Deshabilitando xenodm..."
rcctl disable xenodm || true
rcctl stop xenodm || true

# Configurar dbus (necesario para algunas apps)
print_step "Habilitando messagebus (dbus)..."
rcctl enable messagebus
rcctl start messagebus || true

# ============================================================================
# FASE 4: CONFIGURACIÓN DE AUDIO
# ============================================================================

print_step "FASE 4: Configurando audio..."

# Configurar sndiod (ya viene habilitado por defecto en OpenBSD)
rcctl enable sndiod || true
rcctl start sndiod || true

# Crear archivo de configuración de audio para usuario
cat > "$USER_HOME/.asoundrc" <<'EOF'
# OpenBSD usa sndiod, no ALSA, pero por compatibilidad
defaults.pcm.card 0
defaults.ctl.card 0
EOF

chown "$REAL_USER:$REAL_USER" "$USER_HOME/.asoundrc"

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
autogroup 2 "XTerm"

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

# Reload CWM
bind-key 4S-r restart

# Lock screen
bind-key 4-l "xlock -mode blank"

# UNBIND teclas que no usamos
unbind-key all
EOF

chown "$REAL_USER:$REAL_USER" "$USER_HOME/.cwmrc"

# ============================================================================
# FASE 6: CONFIGURACIÓN DE LEMONBAR
# ============================================================================

print_step "FASE 6: Configurando Lemonbar..."

mkdir -p "$USER_HOME/.config/lemonbar"

# Script de lemonbar con tema Everforest Hard
cat > "$USER_HOME/.config/lemonbar/lemonbar.sh" <<'LEMONEOF'
#!/bin/sh
# Lemonbar para CWM - Everforest Hard Theme

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
    current=$(xprop -root _NET_CURRENT_DESKTOP 2>/dev/null | awk '{print $3+1}')
    [ -z "$current" ] && current=1
    
    ws=""
    for i in 1 2 3 4 5 6 7 8 9; do
        if [ "$i" -eq "$current" ]; then
            ws="$ws %{F$GREEN}[$i]%{F-} "
        else
            ws="$ws %{F$GREY}$i%{F-} "
        fi
    done
    echo "$ws"
}

# Función para fecha/hora
datetime() {
    date '+%a %d %b %H:%M'
}

# Función para batería
battery() {
    if [ -f /usr/sbin/apm ]; then
        apm_output=$(apm -l)
        bat_percent="$apm_output"
        
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
}

# Función para volumen
volume() {
    # OpenBSD usa mixerctl
    vol=$(mixerctl -n outputs.master 2>/dev/null | cut -d, -f1)
    if [ -n "$vol" ]; then
        vol_percent=$(echo "$vol * 100 / 255" | bc)
        echo "%{F$BLUE}VOL $vol_percent%%%{F-}"
    else
        echo ""
    fi
}

# Función para CPU
cpu_usage() {
    cpu=$(top -b -n 1 | grep "CPU states" | awk '{print $3}' | tr -d '%' | cut -d. -f1)
    echo "%{F$YELLOW}CPU ${cpu}%%%{F-}"
}

# Función para RAM
mem_usage() {
    mem=$(top -b -n 1 | grep "Memory:" | awk '{print $2}')
    echo "%{F$BLUE}MEM $mem%{F-}"
}

# Loop principal
while true; do
    # Lado izquierdo - Workspaces
    left="$(workspaces)"
    
    # Lado derecho - Info del sistema
    right="$(cpu_usage) | $(mem_usage) | $(volume) | $(battery) | $(datetime)"
    
    # Output formateado
    echo "%{l}  $left%{r}$right  "
    
    sleep 1
done
LEMONEOF

chmod +x "$USER_HOME/.config/lemonbar/lemonbar.sh"
chown "$REAL_USER:$REAL_USER" "$USER_HOME/.config/lemonbar/lemonbar.sh"

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

chown "$REAL_USER:$REAL_USER" "$USER_HOME/.Xresources"

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

chown -R "$REAL_USER:$REAL_USER" "$USER_HOME/.config/dunst"

# ============================================================================
# FASE 9: CONFIGURACIÓN DE .xinitrc
# ============================================================================

print_step "FASE 9: Configurando .xinitrc para inicio automático..."

cat > "$USER_HOME/.xinitrc" <<'EOF'
#!/bin/sh
# .xinitrc - Everforest Hard Setup

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

# Wallpaper (crear directorio si no existe)
mkdir -p ~/Pictures/wallpapers
# Si tienes feh y una imagen, usa:
# feh --bg-fill ~/Pictures/wallpapers/everforest.png &

# Compositor (transparencias y sombras ligeras)
# picom -b --config ~/.config/picom/picom.conf &

# Notificaciones
dunst &

# Lemonbar
~/.config/lemonbar/lemonbar.sh | lemonbar -g x25 -f "monospace:size=10" -B "#2b3339" -F "#d3c6aa" &

# Screenshots directory
mkdir -p ~/Pictures

# Iniciar CWM
exec cwm
EOF

chmod +x "$USER_HOME/.xinitrc"
chown "$REAL_USER:$REAL_USER" "$USER_HOME/.xinitrc"

# ============================================================================
# FASE 10: CONFIGURACIÓN DE BRIGHTNESS (Brillo de pantalla)
# ============================================================================

print_step "FASE 10: Configurando control de brillo..."

# En OpenBSD, el brillo se controla via wsconsctl
# Crear scripts helper para el usuario

mkdir -p "$USER_HOME/.local/bin"

# Script para aumentar brillo
cat > "$USER_HOME/.local/bin/brightness-up" <<'EOF'
#!/bin/sh
current=$(wsconsctl display.brightness | cut -d= -f2)
new=$((current + 10))
[ $new -gt 100 ] && new=100
doas wsconsctl display.brightness=$new
EOF

# Script para disminuir brillo
cat > "$USER_HOME/.local/bin/brightness-down" <<'EOF'
#!/bin/sh
current=$(wsconsctl display.brightness | cut -d= -f2)
new=$((current - 10))
[ $new -lt 0 ] && new=0
doas wsconsctl display.brightness=$new
EOF

chmod +x "$USER_HOME/.local/bin/brightness-up"
chmod +x "$USER_HOME/.local/bin/brightness-down"
chown -R "$REAL_USER:$REAL_USER" "$USER_HOME/.local"

# Agregar al PATH en shell config
if ! grep -q ".local/bin" "$USER_HOME/.profile" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$USER_HOME/.profile"
    chown "$REAL_USER:$REAL_USER" "$USER_HOME/.profile"
fi

# ============================================================================
# FASE 11: CONFIGURACIÓN DE DOAS PARA BRIGHTNESS
# ============================================================================

print_step "FASE 11: Configurando doas para control de brillo sin password..."

# Backup de doas.conf si existe
[ -f /etc/doas.conf ] && cp /etc/doas.conf /etc/doas.conf.backup

# Agregar regla para wsconsctl sin password
if [ ! -f /etc/doas.conf ] || ! grep -q "wsconsctl" /etc/doas.conf; then
    echo "permit nopass $REAL_USER cmd wsconsctl" >> /etc/doas.conf
    print_step "Agregada regla a /etc/doas.conf para control de brillo"
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

chown "$REAL_USER:$REAL_USER" "$USER_HOME/.vimrc"

# ============================================================================
# FASE 13: INFORMACIÓN FINAL Y VERIFICACIÓN
# ============================================================================

print_step "FASE 13: Finalizando instalación..."

# Crear archivo de información
cat > "$USER_HOME/EVERFOREST_INFO.txt" <<EOF
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║         EVERFOREST HARD - OpenBSD CWM Setup Completo         ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

INSTALACIÓN COMPLETADA EXITOSAMENTE! 🌲

PRÓXIMOS PASOS:
===============

1. REBOOT del sistema:
   $ doas reboot

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
   
   SISTEMA:
   --------
   Super + Shift + R     : Recargar CWM

4. CONTROL DE BRILLO (ThinkPad T480s):
   $ brightness-up       : Aumentar brillo
   $ brightness-down     : Disminuir brillo

5. CONTROL DE VOLUMEN:
   $ mixerctl outputs.master=200    : Volumen alto
   $ mixerctl outputs.master=100    : Volumen medio
   $ mixerctl outputs.master=0      : Mute

ARCHIVOS DE CONFIGURACIÓN:
==========================
- CWM:        ~/.cwmrc
- Lemonbar:   ~/.config/lemonbar/lemonbar.sh
- XTerm:      ~/.Xresources
- Dunst:      ~/.config/dunst/dunstrc
- Vim:        ~/.vimrc
- Xinitrc:    ~/.xinitrc

TEMA:
=====
Everforest Hard - Paleta de colores oscuros con tonos verdes forestales

SERVICIOS HABILITADOS:
======================
- apmd (power management)
- messagebus (dbus)
- sndiod (audio)

WALLPAPERS:
===========
Coloca tus wallpapers en: ~/Pictures/wallpapers/
Edita ~/.xinitrc para configurar feh

TROUBLESHOOTING:
================
- Si lemonbar no aparece: verifica que esté en PATH
- Si no hay audio: verifica que sndiod esté corriendo
- Para logs de X: cat ~/.local/share/xorg/Xorg.0.log

¡DISFRUTA TU SETUP MINIMALISTA! 🌲

EOF

chown "$REAL_USER:$REAL_USER" "$USER_HOME/EVERFOREST_INFO.txt"

# Mostrar resumen
echo ""
echo "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo "${GREEN}    INSTALACIÓN COMPLETADA EXITOSAMENTE! 🌲${NC}"
echo "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo "📄 Lee el archivo: ${BLUE}~/EVERFOREST_INFO.txt${NC} para más información"
echo ""
echo "🔄 PRÓXIMO PASO:"
echo "   1. ${YELLOW}doas reboot${NC}"
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
        print_error "Archivo $file no se creó correctamente"
        ERRORS=$((ERRORS + 1))
    fi
done

if [ $ERRORS -eq 0 ]; then
    print_step "✓ Todos los archivos de configuración creados correctamente"
else
    print_warning "Algunos archivos no se crearon. Revisa los errores arriba."
fi

print_step "Script completado. Sistema listo para reboot."

exit 0
