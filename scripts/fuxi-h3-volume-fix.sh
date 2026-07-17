#!/bin/bash
sleep 2

# amixer -l foi removido no alsa-utils 1.2.15+; usar /proc/asound/cards
CARD=$(grep -iE 'FuxiH3|Fuxi-H3' /proc/asound/cards 2>/dev/null | head -1 | awk '{print $1}')

if [ -z "$CARD" ]; then
    exit 0
fi

/usr/bin/amixer -c "$CARD" sset 'PCM',0 100%,100% > /dev/null 2>&1
/usr/bin/amixer -c "$CARD" sset 'PCM',1 100% > /dev/null 2>&1
