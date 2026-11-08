---
conversation_id: "686d38ec-32c4-800c-a985-c33dd4b44161"
title: "Elevazione privilegi con script"
created: 2025-07-08
updated: 2025-07-08
model: "auto"
messages: 10
---

# Elevazione privilegi con script

## Utente — 2025-07-08 17:28

Modifica lo script in modo che dopo elevati i permessi esegue lo script in automatico

#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/logging.sh"

# Auto elevate to root if needed
if [[ $EUID -ne 0 ]]; then
  info "Elevating privileges with sudo..."
  exec sudo "$0" "$@"
fi

PLYMOUTH_THEME="bgrt"

info "Installing and configuring Plymouth theme..."

# Function to detect initramfs tool: mkinitcpio or dracut
detect_initramfs_tool() {
  if [[ -f /etc/mkinitcpio.conf ]]; then
    echo "mkinitcpio"
  elif [[ -f /etc/dracut.conf || -d /usr/lib/dracut/modules.d ]]; then
    echo "dracut"
  else
    echo ""
  fi
}

initramfs_tool=$(detect_initramfs_tool)
if [[ -z "$initramfs_tool" ]]; then
  error "Could not detect initramfs tool (mkinitcpio or dracut). Exiting."
  exit 1
fi

# Install Plymouth if missing
if yay -Qi plymouth &>/dev/null; then
  info "Plymouth is already installed"
else
  info "Installing Plymouth"
  yay -S --noconfirm plymouth >>"$LOG_FILE" 2>&1 && success "Plymouth installed" || {
    error "Failed to install Plymouth"
    exit 1
  }
fi

# Install Plymouth theme if missing
if yay -Qi "plymouth-theme-$PLYMOUTH_THEME" &>/dev/null; then
  info "Plymouth theme '$PLYMOUTH_THEME' is already installed"
else
  info "Installing Plymouth theme '$PLYMOUTH_THEME'"
  yay -S --noconfirm "plymouth-theme-$PLYMOUTH_THEME" >>"$LOG_FILE" 2>&1 && success "Theme '$PLYMOUTH_THEME' installed" || warn "Failed to install theme '$PLYMOUTH_THEME'"
fi

# Set Plymouth theme in configuration file
if grep -q "^Theme=" /etc/plymouth/plymouthd.conf 2>/dev/null; then
  sed -i "s/^Theme=.*/Theme=$PLYMOUTH_THEME/" /etc/plymouth/plymouthd.conf
else
  echo "Theme=$PLYMOUTH_THEME" >>/etc/plymouth/plymouthd.conf
fi
success "Set Plymouth theme to '$PLYMOUTH_THEME'"

if [[ "$initramfs_tool" == "mkinitcpio" ]]; then
  # Add plymouth hook to mkinitcpio.conf if not present
  if ! grep -q plymouth /etc/mkinitcpio.conf; then
    info "Adding 'plymouth' hook to mkinitcpio.conf"
    sudo sed -i 's/^\(HOOKS=.*\)/\1 plymouth/' /etc/mkinitcpio.conf
    info "Regenerating initramfs with mkinitcpio"
    mkinitcpio -P >>"$LOG_FILE" 2>&1 && success "Updated mkinitcpio with 'plymouth' hook" || warn "Failed to regenerate initramfs"
  else
    info "'plymouth' hook already present in mkinitcpio.conf"
  fi
elif [[ "$initramfs_tool" == "dracut" ]]; then
  # Add plymouth module to dracut config if not present
  if ! grep -q "plymouth" /etc/dracut.conf 2>/dev/null; then
    info "Adding 'plymouth' to dracut modules in /etc/dracut.conf"
    echo 'add_dracutmodules+=" plymouth "' >>/etc/dracut.conf
  else
    info "'plymouth' module already enabled in dracut config"
  fi
  info "Regenerating initramfs with dracut"
  dracut --force --kver "$(uname -r)" >>"$LOG_FILE" 2>&1 && success "Updated dracut initramfs with 'plymouth' module" || warn "Failed to regenerate dracut initramfs"
fi

success "Plymouth setup completed"

## ChatGPT — 2025-07-08 17:28

Puoi modificare lo script in questo modo per fare in modo che, **dopo l’elevazione dei privilegi**, venga **eseguito automaticamente senza uscire**. L’unica modifica necessaria è nell’uso di `sudo` per reinvocare lo script: bisogna usare `exec sudo bash "$0"` per garantire che venga rieseguito con lo stesso interprete (`bash`), utile quando lo script è lanciato con `./script.sh` ma senza il bit eseguibile o senza il corretto shebang.

Ecco la versione modificata (modifica principale commentata):

---

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/logging.sh"

# Auto elevate to root if needed
if [[ $EUID -ne 0 ]]; then
  info "Elevating privileges with sudo..."
  exec sudo bash "$0" "$@"   # <--- modificato per reinvocare correttamente lo script
fi

PLYMOUTH_THEME="bgrt"

info "Installing and configuring Plymouth theme..."

# Function to detect initramfs tool: mkinitcpio or dracut
detect_initramfs_tool() {
  if [[ -f /etc/mkinitcpio.conf ]]; then
    echo "mkinitcpio"
  elif [[ -f /etc/dracut.conf || -d /usr/lib/dracut/modules.d ]]; then
    echo "dracut"
  else
    echo ""
  fi
}

initramfs_tool=$(detect_initramfs_tool)
if [[ -z "$initramfs_tool" ]]; then
  error "Could not detect initramfs tool (mkinitcpio or dracut). Exiting."
  exit 1
fi

# Install Plymouth if missing
if yay -Qi plymouth &>/dev/null; then
  info "Plymouth is already installed"
else
  info "Installing Plymouth"
  yay -S --noconfirm plymouth >>"$LOG_FILE" 2>&1 && success "Plymouth installed" || {
    error "Failed to install Plymouth"
    exit 1
  }
fi

# Install Plymouth theme if missing
if yay -Qi "plymouth-theme-$PLYMOUTH_THEME" &>/dev/null; then
  info "Plymouth theme '$PLYMOUTH_THEME' is already installed"
else
  info "Installing Plymouth theme '$PLYMOUTH_THEME'"
  yay -S --noconfirm "plymouth-theme-$PLYMOUTH_THEME" >>"$LOG_FILE" 2>&1 && success "Theme '$PLYMOUTH_THEME' installed" || warn "Failed to install theme '$PLYMOUTH_THEME'"
fi

# Set Plymouth theme in configuration file
if grep -q "^Theme=" /etc/plymouth/plymouthd.conf 2>/dev/null; then
  sed -i "s/^Theme=.*/Theme=$PLYMOUTH_THEME/" /etc/plymouth/plymouthd.conf
else
  echo "Theme=$PLYMOUTH_THEME" >>/etc/plymouth/plymouthd.conf
fi
success "Set Plymouth theme to '$PLYMOUTH_THEME'"

if [[ "$initramfs_tool" == "mkinitcpio" ]]; then
  # Add plymouth hook to mkinitcpio.conf if not present
  if ! grep -q plymouth /etc/mkinitcpio.conf; then
    info "Adding 'plymouth' hook to mkinitcpio.conf"
    sudo sed -i 's/^\(HOOKS=.*\)/\1 plymouth/' /etc/mkinitcpio.conf
    info "Regenerating initramfs with mkinitcpio"
    mkinitcpio -P >>"$LOG_FILE" 2>&1 && success "Updated mkinitcpio with 'plymouth' hook" || warn "Failed to regenerate initramfs"
  else
    info "'plymouth' hook already present in mkinitcpio.conf"
  fi
elif [[ "$initramfs_tool" == "dracut" ]]; then
  # Add plymouth module to dracut config if not present
  if ! grep -q "plymouth" /etc/dracut.conf 2>/dev/null; then
    info "Adding 'plymouth' to dracut modules in /etc/dracut.conf"
    echo 'add_dracutmodules+=" plymouth "' >>/etc/dracut.conf
  else
    info "'plymouth' module already enabled in dracut config"
  fi
  info "Regenerating initramfs with dracut"
  dracut --force --kver "$(uname -r)" >>"$LOG_FILE" 2>&1 && success "Updated dracut initramfs with 'plymouth' module" || warn "Failed to regenerate dracut initramfs"
fi

success "Plymouth setup completed"
```

---

### Spiegazione della modifica:
```bash
exec sudo bash "$0" "$@"
```
- `exec` sostituisce il processo corrente (quindi lo script non continua da riga successiva dopo `sudo`);
- `bash "$0"` assicura che venga usato `bash` anche se lo script non ha il bit eseguibile o viene invocato con `sh`;
- `"$@"` passa tutti gli argomenti originali allo script.

Se preferisci che venga usato `env bash` per coerenza con lo shebang iniziale, puoi anche scrivere:

```bash
exec sudo env bash "$0" "$@"
```

Fammi sapere se vuoi anche gestire il caso in cui `sudo` non è installato o l’utente lo rifiuta.

## Utente — 2025-07-08 17:41

eseguendo il comando in questa maniera viene eseguito nel processo corrente sostituendo la shell questo provoca la chiusura immediata dell'emulatore di terminale

## ChatGPT — 2025-07-08 17:41

Hai ragione: l’uso di `exec` sostituisce il processo corrente con quello dello script rieseguito come `sudo`, e **se lo script è avviato da un terminale grafico** (es. `gnome-terminal`, `konsole`, `xfce4-terminal`), questo può causare la **chiusura immediata del terminale** una volta che lo script termina.

### ✅ Soluzione corretta: **evitare `exec` e usare `sudo` normalmente**

Sostituisci questa parte:

```bash
exec sudo bash "$0" "$@"
```

con:

```bash
sudo bash "$0" "$@"
exit $?
```

### Perché funziona meglio

- **`sudo bash "$0"`** lancia lo script in un nuovo processo figlio con privilegi elevati;
- **`exit $?`** termina lo script restituendo lo stesso codice di uscita del figlio (per trasparenza);
- Non si usa `exec`, quindi il terminale **rimane aperto** anche dopo la fine dello script.

### Codice aggiornato del blocco `if`:

```bash
# Auto elevate to root if needed
if [[ $EUID -ne 0 ]]; then
  info "Elevating privileges with sudo..."
  sudo bash "$0" "$@"
  exit $?
fi
```

### Se vuoi ancora più robustezza (es. fallback se `bash` non è disponibile sotto sudo), puoi usare:

```bash
sudo env "$0" "$@"
```

Ma nella maggior parte dei casi `sudo bash "$0"` va benissimo.

---

Fammi sapere se lo script potrebbe essere chiamato in contesti non interattivi (es. da cron, o da altre automazioni), e ti adatto il comportamento.

## Utente — 2025-07-08 21:36

Sudo env che shell userebbe?

## ChatGPT — 2025-07-08 21:36

Ottima domanda.

### Comportamento di `sudo env "$0"`:

Quando esegui:

```bash
sudo env "$0" "$@"
```

- **`env`** esegue lo script **usando lo shebang** (`#!`) specificato all'inizio del file.
- Quindi la shell usata sarà **quella dichiarata nel tuo script** nella prima riga:
  ```bash
  #!/usr/bin/env bash
  ```

- In pratica:
  - `env` cerca l'eseguibile `bash` nel `$PATH` dell'utente root (poiché stai usando `sudo`);
  - quindi lo script sarà eseguito con **`bash` installato nel sistema, come root**.

---

### Differenza con `sudo bash "$0"`:

| Comando                 | Shell usata      | Basata su |
|------------------------|------------------|-----------|
| `sudo bash "$0"`       | `/bin/bash` o simile | percorso esplicito (`bash` trovato nel `$PATH` o alias) |
| `sudo env "$0"`        | shebang (es. `env bash`) | esecuzione dinamica via `env`, rispetta lo shebang dello script |

---

### Quando usare l’uno o l’altro?

- ✅ **`sudo env "$0"`**: più *portabile*, se vuoi che lo script venga eseguito sempre con la shell dichiarata nel `#!` (utile se il tuo script richiede specificamente `bash`, `zsh`, ecc.).
- ✅ **`sudo bash "$0"`**: più *controllato*, se vuoi essere certo che venga usato proprio `bash`, a prescindere dallo shebang.

---

### Conclusione

Nel tuo caso, **`sudo env "$0" "$@"`** è perfettamente coerente con lo shebang:

```bash
#!/usr/bin/env bash
```

Quindi eseguirà il file usando `bash`, come root, e rispetterà la logica originale. Puoi tranquillamente usarlo come alternativa a `sudo bash "$0"` — specialmente se punti a maggiore compatibilità.

Fammi sapere se vuoi che testiamo il comportamento anche in ambienti più restrittivi (es. Alpine, BusyBox, WSL).

## Utente — 2025-07-08 21:37

Funzionerebbe anche se usassi sh?

## ChatGPT — 2025-07-08 21:37

Sì, funziona **anche se usi `sh`** – ma con delle differenze importanti da tenere in considerazione.

---

### ✅ Esempio con shebang `#!/bin/sh`:

Se il tuo script inizia così:

```bash
#!/bin/sh
```

E lo esegui con:

```bash
sudo env "$0" "$@"
```

allora:

- `env` legge il **shebang** e vede `/bin/sh`;
- `sudo` esegue lo script come **root**, usando `/bin/sh` come shell.

Quindi sì, **funzionerà**, *ma* sarà eseguito sotto `sh` (che è più limitato rispetto a `bash`).

---

### ⚠️ Differenze tra `sh` e `bash`

Molte funzionalità usate comunemente in `bash` **non esistono in `sh`**, ad esempio:

| Funzionalità                   | Supporto in `bash` | Supporto in `sh` (POSIX) |
|-------------------------------|--------------------|---------------------------|
| `[[ ... ]]` test avanzato     | ✅                 | ❌ (solo `[ ... ]`)       |
| `source`                      | ✅                 | ❌ (`.` deve essere usato) |
| Array                         | ✅                 | ❌                        |
| `set -euo pipefail`           | ✅                 | Parziale / variabile      |
| `$BASH_SOURCE`                | ✅                 | ❌                        |
| `function fname { ... }`      | ✅                 | ❌ (usa `fname() { ... }`) |

Nel tuo script attuale, ad esempio, hai:
```bash
[[ $EUID -ne 0 ]]
source "$SCRIPT_DIR/../lib/logging.sh"
```

Queste righe **non funzionerebbero in `sh`**: dovresti usare `[ $EUID -ne 0 ]` e `.` al posto di `source`.

---

### 🔄 Conclusione

- Se usi `#!/bin/sh`, **sì**, `sudo env "$0"` funzionerà;
- Ma **assicurati che il tuo script sia davvero compatibile con `sh`** (ovvero, scritto in stile POSIX puro);
- In alternativa, se stai usando funzionalità di `bash`, resta su `#!/usr/bin/env bash` e lancia con:

```bash
sudo env bash "$0" "$@"
```

oppure

```bash
sudo bash "$0" "$@"
```

---

Vuoi che ti converta lo script attuale per essere POSIX-compliant e funzionare sotto `sh`?

## Utente — 2025-07-08 21:38

Lo script che ti ho mandato è POSIX?

## ChatGPT — 2025-07-08 21:38

Il tuo script **non è POSIX-compliant**, perché utilizza diverse funzionalità specifiche di **Bash** che **non sono supportate da `/bin/sh`** o da shell POSIX-compliant.

---

## ⚠️ Analisi delle violazioni POSIX

### 1. `[[ ... ]]` — **non POSIX**
```bash
if [[ $EUID -ne 0 ]]; then
```
✅ In Bash  
❌ In POSIX: usa `[` o `test`:
```bash
if [ "$EUID" -ne 0 ]; then
```

---

### 2. `source` — **non POSIX**
```bash
source "$SCRIPT_DIR/../lib/logging.sh"
```
✅ In Bash  
❌ In POSIX: si usa `.` al posto di `source`:
```bash
. "$SCRIPT_DIR/../lib/logging.sh"
```

---

### 3. `${BASH_SOURCE[0]}` — **non POSIX**
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```
✅ Variabile speciale di Bash  
❌ Non esiste in POSIX. Soluzione alternativa:
```bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
```

---

### 4. `set -euo pipefail` — **parzialmente POSIX**
```bash
set -euo pipefail
```
- `-e` e `-u` sono **POSIX**.
- `pipefail` **non lo è** (solo in Bash).

In POSIX puro, non esiste `pipefail`. Dovresti ristrutturare i comandi in pipe per controllarne gli errori manualmente.

---

### 5. Uso di `yay` — **non correlato alla shell**, ma è una dipendenza Arch-specifica  
✔️ Va bene se il sistema è noto (Arch-based).  
❗ Ma **non portabile universalmente**.

---

## ✅ Parti compatibili con POSIX

- Uso di `if`, `elif`, `else`, `fi`, `echo`, `sed`, `grep`, `exit`
- Funzioni dichiarate con sintassi POSIX:
  ```bash
  detect_initramfs_tool() {
    ...
  }
  ```

---

## ✅ Come renderlo POSIX-compatibile

1. Modifica lo shebang:
   ```bash
   #!/bin/sh
   ```
2. Sostituisci:
   - `[[ ... ]]` → `[ ... ]`
   - `source` → `.`
   - `${BASH_SOURCE[0]}` → `$0`
   - rimuovi `pipefail` da `set`

---

## Vuoi che te lo converta io in versione POSIX compatibile?

Posso farlo mantenendo tutta la logica. Fammi sapere se vuoi:

- POSIX puro (`#!/bin/sh`)
- o solo **Bash minimale**, ma più portabile (`#!/usr/bin/env bash`, senza `pipefail`, ecc.)
