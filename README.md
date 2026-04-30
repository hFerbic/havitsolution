# 🎧 Havit Fuxi-H3 — Fix de Volume no Linux (PipeWire)

Correção para o bug onde baixar o volume no Linux muta um dos canais do headset imediatamente, deixando apenas um lado funcionando em qualquer volume abaixo de 100%.

Testado em: **Nobara Linux** com **KDE Plasma** e **PipeWire**.

---

## O Problema

Ao tentar reduzir o volume do Fuxi-H3 (via dongle USB), um dos canais é mutado imediatamente — seja pelo scroll do mouse, atalho de teclado ou pelos botões físicos do headset. O áudio só funciona nos dois lados com volume em 100%.

### Causa raiz

O Fuxi-H3 expõe dois controles PCM separados para o ALSA com um range de volume extremamente limitado (`min=0, max=100` com apenas `0.00dB` a `0.39dB`). Na prática, o hardware interpreta qualquer valor abaixo de 100% como mudo em um dos canais. O controle de volume real é feito no firmware do dongle, não pelo mixer do Linux.

Adicionalmente, o WirePlumber por padrão ativa `api.alsa.soft-mixer = true` e `api.alsa.ignore-dB = true` para este dispositivo, o que agrava o comportamento.

```
# Output do amixer revelando o problema:
numid=9, name='PCM Playback Volume'   min=0, max=100  dBminmax: 0.00dB ~ 0.39dB
numid=10, name='PCM Playback Volume', index=1   min=0, max=100  dBminmax: 0.00dB ~ 0.39dB
```

---

## A Solução

A correção tem duas partes:

1. **WirePlumber**: Configurar o dispositivo para usar soft-mixer (volume controlado por software pelo PipeWire), travando o hardware em 100%.
2. **udev**: Criar uma regra que trava automaticamente o volume do hardware em 100% sempre que o dongle for conectado.

---

## Instalação Manual

### 1. Regra do WirePlumber

Crie o arquivo de configuração:

```bash
mkdir -p ~/.config/wireplumber/wireplumber.conf.d/
nano ~/.config/wireplumber/wireplumber.conf.d/fuxi-h3-fix.conf
```

Cole o conteúdo:

```lua
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
```

Reinicie os serviços de áudio:

```bash
systemctl --user restart wireplumber pipewire pipewire-pulse
```

### 2. Script de fixação do volume de hardware

Crie o script:

```bash
sudo nano /usr/local/bin/fuxi-h3-volume-fix.sh
```

Cole o conteúdo:

```bash
#!/bin/bash
sleep 2
CARD=$(amixer -l | grep -i 'FuxiH3\|Fuxi-H3' | head -1 | grep -o 'card [0-9]*' | grep -o '[0-9]*')
amixer -c "$CARD" sset 'PCM',0 100%,100%
amixer -c "$CARD" sset 'PCM',1 100%
```

Dê permissão de execução:

```bash
sudo chmod +x /usr/local/bin/fuxi-h3-volume-fix.sh
```

### 3. Regra udev (executa o script automaticamente ao conectar o dongle)

```bash
sudo nano /etc/udev/rules.d/99-fuxi-h3.rules
```

Cole:

```
ACTION=="add", SUBSYSTEM=="sound", ATTRS{idVendor}=="040b", ATTRS{idProduct}=="0897", RUN+="/usr/local/bin/fuxi-h3-volume-fix.sh"
```

Recarregue as regras udev:

```bash
sudo udevadm control --reload-rules
```

---

## Instalação Automática

Use o script de instalação incluído neste repositório:

```bash
git clone https://github.com/seu-usuario/fuxi-h3-linux-fix
cd fuxi-h3-linux-fix
chmod +x install.sh
./install.sh
```

---

## Verificando se funcionou

Após a instalação, verifique se as propriedades foram aplicadas:

```bash
pactl list sinks | grep -A 3 "soft-mixer\|ignore-dB\|hw-volume"
```

A saída esperada é:

```
api.alsa.soft-mixer = "true"
api.alsa.ignore-dB = "true"
api.alsa.enable-hw-volume = "false"
```

---

## Compatibilidade com outros modos de conexão

| Modo de conexão | Afetado por este fix? |
|---|---|
| Dongle USB (2.4GHz) | ✅ Sim — é exatamente para isso |
| Cabo USB | ⚠️ Só se usar o mesmo `idVendor:idProduct` (verificar com `lsusb`) |
| P3 analógico | ❌ Não — vai direto para o jack da placa-mãe |
| Bluetooth | ❌ Não — aparece como dispositivo completamente diferente |

Para verificar se o cabo USB usa o mesmo ID:

```bash
lsusb | grep -i "040b\|Weltrend\|Fuxi\|XiiSound"
```

---

## Informações do Dispositivo

| Campo | Valor |
|---|---|
| Produto | Havit Fuxi-H3 |
| Vendor ID | `0x040b` (Weltrend Semiconductor) |
| Product ID | `0x0897` |
| Driver | `snd_usb_audio` |
| Interface | USB (dongle 2.4GHz) |

---

## Desinstalação

```bash
rm -f ~/.config/wireplumber/wireplumber.conf.d/fuxi-h3-fix.conf
sudo rm -f /usr/local/bin/fuxi-h3-volume-fix.sh
sudo rm -f /etc/udev/rules.d/99-fuxi-h3.rules
sudo udevadm control --reload-rules
systemctl --user restart wireplumber pipewire pipewire-pulse
```

---

## Contribuições

Se você tem um Fuxi-H3 e testou em outra distro ou ambiente desktop, abra uma issue ou PR com os resultados!
