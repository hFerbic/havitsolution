#!/bin/bash
# =============================================================================
# Havit Fuxi-H3 — Desinstalação do Fix de Volume
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BLUE}${BOLD}🗑️  Havit Fuxi-H3 — Desinstalação${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

rm -f "$HOME/.config/wireplumber/wireplumber.conf.d/fuxi-h3-fix.conf"
echo -e "${GREEN}✓${NC} Regra do WirePlumber removida"

sudo rm -f /usr/local/bin/fuxi-h3-volume-fix.sh
echo -e "${GREEN}✓${NC} Script de volume removido"

sudo rm -f /etc/udev/rules.d/99-fuxi-h3.rules
echo -e "${GREEN}✓${NC} Regra udev removida"

sudo udevadm control --reload-rules
echo -e "${GREEN}✓${NC} Regras udev recarregadas"

systemctl --user restart wireplumber pipewire pipewire-pulse
echo -e "${GREEN}✓${NC} Serviços de áudio reiniciados"

echo ""
echo -e "${BOLD}Desinstalação concluída.${NC}"
echo ""
