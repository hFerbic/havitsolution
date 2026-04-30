#!/bin/bash
# =============================================================================
# Havit Fuxi-H3 — Fix de Volume no Linux (PipeWire)
# https://github.com/seu-usuario/fuxi-h3-linux-fix
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}${BOLD}🎧 Havit Fuxi-H3 — Fix de Volume no Linux${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_step() {
    echo -e "${BOLD}[${1}/${TOTAL_STEPS}]${NC} $2"
}

print_ok() {
    echo -e "    ${GREEN}✓${NC} $1"
}

print_warn() {
    echo -e "    ${YELLOW}⚠${NC} $1"
}

print_err() {
    echo -e "    ${RED}✗${NC} $1"
}

TOTAL_STEPS=4

print_header

# =============================================================================
# PASSO 1: Verificar dependências
# =============================================================================
print_step 1 "Verificando dependências..."

for cmd in pactl amixer systemctl udevadm; do
    if command -v "$cmd" &>/dev/null; then
        print_ok "$cmd encontrado"
    else
        print_err "$cmd não encontrado — instale o pacote correspondente e tente novamente."
        exit 1
    fi
done

# Verificar se o PipeWire está rodando
if systemctl --user is-active --quiet pipewire; then
    print_ok "PipeWire está rodando"
else
    print_warn "PipeWire não está ativo no momento (pode estar suspenso)"
fi

# Verificar se o dongle está conectado
if lsusb | grep -q "040b:0897"; then
    print_ok "Dongle Fuxi-H3 detectado (040b:0897)"
else
    print_warn "Dongle Fuxi-H3 não detectado agora — o fix será instalado assim mesmo e funcionará quando conectado"
fi

echo ""

# =============================================================================
# PASSO 2: Configuração do WirePlumber
# =============================================================================
print_step 2 "Criando regra do WirePlumber..."

WIREPLUMBER_DIR="$HOME/.config/wireplumber/wireplumber.conf.d"
WIREPLUMBER_FILE="$WIREPLUMBER_DIR/fuxi-h3-fix.conf"

mkdir -p "$WIREPLUMBER_DIR"

cat > "$WIREPLUMBER_FILE" << 'EOF'
monitor.alsa.rules = [
  {
    matches = [
      {
        device.vendor.id = "0x040b"
        device.product.id = "0x0897"
      }
    ]
    actions = {
      update-props = {
        api.alsa.soft-mixer       = true
        api.alsa.ignore-dB        = true
        api.alsa.enable-hw-volume = false
        api.alsa.headroom         = 0
      }
    }
  }
]
EOF

print_ok "Arquivo criado em $WIREPLUMBER_FILE"

echo ""

# =============================================================================
# PASSO 3: Script udev + regra
# =============================================================================
print_step 3 "Instalando script e regra udev (requer sudo)..."

SCRIPT_PATH="/usr/local/bin/fuxi-h3-volume-fix.sh"
UDEV_RULE="/etc/udev/rules.d/99-fuxi-h3.rules"

sudo tee "$SCRIPT_PATH" > /dev/null << 'EOF'
#!/bin/bash
sleep 2
CARD=$(amixer -l 2>/dev/null | grep -i 'FuxiH3\|Fuxi-H3' | head -1 | grep -o 'card [0-9]*' | grep -o '[0-9]*')

if [ -z "$CARD" ]; then
    exit 0
fi

amixer -c "$CARD" sset 'PCM',0 100%,100% > /dev/null 2>&1
amixer -c "$CARD" sset 'PCM',1 100% > /dev/null 2>&1
EOF

sudo chmod +x "$SCRIPT_PATH"
print_ok "Script criado em $SCRIPT_PATH"

sudo tee "$UDEV_RULE" > /dev/null << 'EOF'
ACTION=="add", SUBSYSTEM=="sound", ATTRS{idVendor}=="040b", ATTRS{idProduct}=="0897", RUN+="/usr/local/bin/fuxi-h3-volume-fix.sh"
EOF

print_ok "Regra udev criada em $UDEV_RULE"

sudo udevadm control --reload-rules
print_ok "Regras udev recarregadas"

echo ""

# =============================================================================
# PASSO 4: Reiniciar serviços de áudio
# =============================================================================
print_step 4 "Reiniciando serviços de áudio..."

systemctl --user restart wireplumber pipewire pipewire-pulse
print_ok "WirePlumber, PipeWire e PipeWire-Pulse reiniciados"

# Aplicar fix de hardware imediatamente se o dongle estiver conectado
sleep 1
CARD_NOW=$(amixer -l 2>/dev/null | grep -i 'FuxiH3\|Fuxi-H3' | head -1 | grep -o 'card [0-9]*' | grep -o '[0-9]*')
if [ -n "$CARD_NOW" ]; then
    amixer -c "$CARD_NOW" sset 'PCM',0 100%,100% > /dev/null 2>&1
    amixer -c "$CARD_NOW" sset 'PCM',1 100% > /dev/null 2>&1
    print_ok "Volume de hardware travado em 100% (dongle conectado)"
fi

echo ""

# =============================================================================
# Verificação final
# =============================================================================
echo -e "${BLUE}${BOLD}Verificação final...${NC}"

SOFT=$(pactl list sinks 2>/dev/null | grep -A 60 "Fuxi-H3" | grep "soft-mixer" | head -1 | grep -o '".*"')
HW=$(pactl list sinks 2>/dev/null | grep -A 60 "Fuxi-H3" | grep "enable-hw-volume" | head -1 | grep -o '".*"')

if [ "$SOFT" = '"true"' ] && [ "$HW" = '"false"' ]; then
    echo ""
    echo -e "${GREEN}${BOLD}✅ Fix aplicado com sucesso!${NC}"
    echo ""
    echo -e "   ${GREEN}api.alsa.soft-mixer       = true${NC}  (volume controlado por software)"
    echo -e "   ${GREEN}api.alsa.enable-hw-volume = false${NC} (hardware travado em 100%)"
elif [ -z "$SOFT" ]; then
    echo ""
    print_warn "Dongle não está conectado agora — não foi possível verificar."
    print_warn "Conecte o dongle e rode: pactl list sinks | grep -A 3 'soft-mixer\\|hw-volume'"
else
    echo ""
    print_warn "Verificação inconclusiva. Confira manualmente:"
    echo "    pactl list sinks | grep -A 3 'soft-mixer\\|hw-volume'"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Para desinstalar: ${BOLD}./uninstall.sh${NC}"
echo ""
