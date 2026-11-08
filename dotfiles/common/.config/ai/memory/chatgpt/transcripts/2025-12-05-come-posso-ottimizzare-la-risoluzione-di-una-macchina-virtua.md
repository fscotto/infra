---
conversation_id: "6932dbf4-7a64-832d-a7f7-5005245cf511"
title: "Come posso ottimizzare la risoluzione di una macchina virtuale su KVM/..."
created: 2025-12-05
updated: 2025-12-05
model: "auto"
messages: 2
---

# Come posso ottimizzare la risoluzione di una macchina virtuale su KVM/...

## Utente — 2025-12-05 14:19

Come posso ottimizzare la risoluzione di una macchina virtuale su KVM/Qemu con installato EndevourOS?

## ChatGPT — 2025-12-05 14:19

Per ottimizzare la **risoluzione video** di una VM KVM/QEMU che esegue **EndeavourOS (Arch-based)**, e ottenere un supporto grafico fluido, ridimensionamento dinamico e risoluzioni elevate (1080p, 1440p, 4K), ecco la procedura completa e “best practice”.

---

# ✅ **1. Configura correttamente la VM lato QEMU/KVM**

### **Impostazioni consigliate in virt-manager**
Apri la VM → *“Show virtual hardware details”* → e verifica:

### **📌 Display**
- **Display Type:** `Spice`
- **Graphics:** `Spice server`
- **Listen type:** `None` (o `Socket`, se usi virt-manager locale)
- **OpenGL:** **ON**
- **GL Acceleration:** **ON** (se disponibile)

### **📌 Video**
Scegli *solo uno* dei seguenti driver:

### **Opzione A — Virtio GPU (raccomandato)**
- **Video Model:** `Virtio`
- **Vulkan:** opzionale (sperimentale su alcune build)
  
👉 Offre migliori prestazioni e supporto per ridimensionamento dinamico con agenti SPICE.

### Opzione B — QXL (solo se devi usare display legacy)
- **Video Model:** `QXL`
  
👉 Più compatibile, ma meno performante. Consigliato solo per sistemi con SPICE vecchi.

---

# ✅ **2. Installa Spice Guest Tools dentro EndeavourOS**

Apri un terminale nella VM:

```bash
sudo pacman -Syu
sudo pacman -S spice-vdagent xf86-video-qxl xf86-video-fbdev
```

Se usi **Virtio GPU**, installa anche:

```bash
sudo pacman -S xf86-video-qxl vulkan-radeon mesa
```

*(“vulkan-radeon” o “vulkan-intel” dipende da host e passthrough; mesa è comunque necessario.)*

### Verifica che `spice-vdagent` sia attivo:
```bash
systemctl --user status spice-vdagent.service
```

Se non è attivo:
```bash
systemctl --user enable --now spice-vdagent.service
```

### Cosa abilita?
- Ridimensionamento automatico finestra VM  
- Copia/incolla avanzato  
- Supporto multi-monitor  
- Miglior supporto HiDPI  

---

# ✅ **3. Imposta risoluzioni personalizzate (se non cambiano automaticamente)**

### Con Virtio GPU puoi aggiungerle tramite `xrandr`:

1. Trova il nome del display:
```bash
xrandr
```

Esempio: `Virtual-1`

2. Genera il modeline per la risoluzione desiderata (es. 1920x1080):
```bash
cvt 1920 1080
```

3. Aggiungi la risoluzione:
```bash
xrandr --newmode "1920x1080_60.00" <OUTPUT_CVT>
xrandr --addmode Virtual-1 "1920x1080_60.00"
xrandr --output Virtual-1 --mode "1920x1080_60.00"
```

---

# ✅ **4. Wayland: attenzione (EndeavourOS usa spesso KDE Plasma/Wayland)**

Su **Wayland**, il ridimensionamento dinamico potrebbe richiedere:

```bash
sudo pacman -S wlroots
```

Se usi KDE Plasma su Wayland, Virtio GPU funziona al 90%.  
Se vuoi la massima compatibilità → **usa X11**, perché SPICE è più maturo lì.

Login manager → scegli:

```
Plasma (X11)
```

---

# ✅ **5. Attiva accelerazione 3D**

In `virt-manager` → Video → Virtio:

- `Accel3D` → **ON**
- In Display → Spice → OpenGL → **ON**

Lato guest (EndeavourOS):

```bash
sudo pacman -S mesa mesa-vulkan-drivers
```

Verifica:

```bash
glxinfo | grep "direct rendering"
```

Deve essere:
```
direct rendering: Yes
```

---

# ✅ **6. Performance avanzate (opzionale)**

### **Usa virtio-gpu-pci con virglrenderer**
Nel dominio XML puoi usare:

```xml
<video>
  <model type='virtio' heads='1' accel3d='yes'/>
</video>
```

### **Per 4K o multicore GPU emulation**
Agisci su:

```
Settings → CPUS → Topology
Settings → Memory → Hugepages
```

Solo se ti serve molta fluidità grafica.

---

# 🚀 RISULTATO ATTESO

Dopo queste configurazioni dovresti ottenere:

- Risoluzione dinamica immediata (resize della finestra)
- Supporto HiDPI migliore
- Accelerazione 3D funzionante
- Esperienza fluida su Plasma/GNOME
- Prestazioni grafiche ottimali con Virtio + SPICE

---

# Se vuoi, posso:
✔️ controllarti la tua configurazione XML della VM  
✔️ suggerirti il driver video migliore per il tuo hardware host  
✔️ ottimizzare CPU/RAM/virtio per sviluppo e test  

Vuoi mostrarmi *come hai configurato la tua VM*?
