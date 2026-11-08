---
conversation_id: "69b5da0f-d374-8389-9991-89a66fa1e673"
title: "Flatpak con i3"
created: 2026-03-14
updated: 2026-03-15
model: "gpt-5-3"
messages: 14
---

# Flatpak con i3

## Utente — 2026-03-14 23:00

Adesso passiamo al dilemma, Flatpak o non Flatpak?

Generalmente installavo tutti i software con GUI che accedevano in qualche modo alla rete o software proprietari tramite Flatpak, però volevo capire se in qualche modo questo potesse risultare problematico nella sessione i3 che abbiamo costruito insieme.

## ChatGPT — 2026-03-14 23:00

Domanda molto sensata. In un setup **minimalista come il tuo (Void + i3 + runit)** vale la pena ragionarci bene perché Flatpak cambia un po’ la filosofia del sistema.

Ti anticipo la conclusione pratica:  
👉 **Flatpak funziona perfettamente con i3**. Non crea problemi strutturali.  
Ma ci sono **3 aspetti tecnici** da considerare nel tuo tipo di ambiente.

---

# 1️⃣ Integrazione con i3 / environment
Flatpak non dipende dal desktop environment ma da **portals** e **dbus**, quindi con un window manager puro come i3 alcune cose vanno configurate.

Le componenti necessarie sono:

- `flatpak`
- `xdg-desktop-portal`
- `xdg-desktop-portal-gtk`

Su Void normalmente:

```bash
xbps-install flatpak xdg-desktop-portal xdg-desktop-portal-gtk
```

e poi attivi il servizio:

```bash
ln -s /etc/sv/dbus /var/service
```

Se usi PipeWire (per screen sharing ecc):

```bash
xbps-install pipewire wireplumber
```

Con questo setup **Flatpak funziona anche in i3 senza problemi**.

---

# 2️⃣ Temi, font e look (questo è il problema più comune)
In ambienti minimal come il tuo capita spesso che le app Flatpak:

- non vedano il **tema GTK**
- non vedano i **font**
- non vedano le **icone**

Si risolve in due modi.

### Metodo 1 (consigliato)
Installare il tema via Flatpak:

```bash
flatpak install org.gtk.Gtk3theme.Adwaita-dark
```

Oppure il tema che usi.

---

### Metodo 2
Esportare variabili:

```bash
flatpak override --env=GTK_THEME=Adwaita:dark
```

---

# 3️⃣ Integrazione filesystem
Flatpak usa sandboxing, quindi alcune app non vedono tutto il filesystem.

Per un utente tecnico come te può essere fastidioso.

Puoi vedere i permessi con:

```bash
flatpak info --show-permissions APP
```

Oppure modificarli:

```bash
flatpak override --filesystem=home APP
```

Oppure usare:

```bash
xbps-install flatseal
```

---

# 4️⃣ Impatto sulla filosofia Void
Qui entra la parte interessante.

Void è:

- rolling
- semplice
- binari leggeri
- filosofia UNIX molto pulita

Flatpak introduce:

- runtime duplicati
- sandbox
- runtime GNOME/KDE
- spazio disco extra

Per esempio:

```
~/.var/app
/var/lib/flatpak
```

Non è “sporco”, ma **rompe un po’ l’idea minimalista**.

---

# 5️⃣ Strategia che usano molti utenti Void
Questa è la strategia che di solito funziona meglio:

### Pacchetti XBPS per
- tool CLI
- librerie
- programmi core

### Flatpak per
- software proprietari
- software pesanti
- software che vogliamo isolare

Tipicamente:

Flatpak per:

- ProtonMail Bridge
- Discord
- Spotify
- Zoom
- Telegram
- Obsidian
- Bitwarden
- Slack

XBPS per:

- Firefox
- Alacritty
- Neovim
- Git
- mpv
- GIMP
- Zathura

---

# 6️⃣ Nel tuo caso specifico
Dato il tuo workflow (Void + i3 + sviluppo C + tooling UNIX):

Io farei:

**Sistema base via XBPS**

e Flatpak solo per:

- ProtonMail Bridge
- Discord
- eventuali tool proprietari

Quindi **pochissimi Flatpak**.

---

# 7️⃣ Vantaggio reale per te
Flatpak ti dà una cosa utile:

👉 **isola software che accede alla rete**

Questo è coerente con la tua idea iniziale.

---

💡 Ti faccio una domanda che cambia molto la risposta finale:

**Vuoi usare Firefox da Flatpak o da XBPS?**

Perché quello è il **vero bivio architetturale** nel tuo sistema.  
Molti utenti Void decidono tutta la strategia Flatpak basandosi proprio su questo.

## Utente — 2026-03-14 23:03

Io sto usando Chromium ma per esempio su ikaros sto usando la versione da XBPS anche se per quello che ti ho detto prima dovrei usare il Flatpak, un tuo consiglio?

## ChatGPT — 2026-03-14 23:03

Ti do un parere molto diretto, ragionando sul **tipo di sistema che stai costruendo (Void + i3 + ambiente molto UNIX-like)**.

👉 **Io Chromium lo terrei da XBPS.**

E ti spiego perché, nel tuo caso specifico.

---

## 1️⃣ Chromium è già abbastanza sandboxato
Chromium ha già una sandbox molto aggressiva:

- namespace
- seccomp
- user namespaces
- sandbox GPU
- sandbox renderer

Quindi hai già:

- isolamento dei processi
- limitazione syscall
- separazione tra renderer e browser

Flatpak aggiungerebbe **un secondo livello di sandbox**, ma il guadagno reale è piccolo.

---

## 2️⃣ Con XBPS hai integrazione migliore con il sistema
Con Chromium da pacchetto di sistema ottieni:

✔ integrazione con:

- keyring di sistema  
- font locali  
- tema GTK  
- file chooser  
- clipboard  
- GPU acceleration  
- pipewire screen capture  

Con Flatpak a volte devi fare override tipo:

```bash
flatpak override --filesystem=home
flatpak override --socket=wayland
flatpak override --device=dri
```

Non è terribile, ma diventa **più fragile**.

Nel tuo setup minimalista può diventare fastidioso.

---

## 3️⃣ Aggiornamenti
Su Void Chromium viene aggiornato velocemente.

Flatpak spesso:

- è **un po' indietro**
- oppure dipende da runtime GNOME

E nel tuo sistema stai evitando di trascinarti dietro mezzo GNOME.

---

## 4️⃣ Consumo disco
Chromium Flatpak si porta dietro runtime tipo:

```
org.freedesktop.Platform
org.freedesktop.Sdk
org.gnome.Platform
```

Facilmente **1–2 GB extra**.

---

## 5️⃣ Filosofia del tuo sistema
Dal tipo di ambiente che stai costruendo:

- Void
- i3
- configurazione minimal
- controllo totale del sistema

Flatpak per il browser principale **non è molto coerente**.

Molti utenti Void lo usano invece per **software “esterni” al sistema**.

---

# La strategia che userei io nel tuo sistema

### XBPS
software che voglio **integrato con il sistema**

- chromium
- firefox
- mpv
- gimp
- zathura
- alacritty
- neovim

---

### Flatpak
software **isolati o proprietari**

- ProtonMail Bridge
- Discord
- Spotify
- Slack
- Telegram
- Bitwarden
- Obsidian

---

# Una cosa interessante per te
Dato il tuo interesse per la **sicurezza e i sistemi**, potresti fare anche questa cosa molto elegante:

browser separati per scopi diversi.

Per esempio:

```
chromium      -> XBPS (browser principale)
firefox       -> Flatpak (browser isolato)
```

Oppure viceversa.

Molti sviluppatori fanno così.

---

💡 Ti faccio però una domanda importante per il tuo setup:

**Stai usando Chromium su Wayland o su X11 dentro i3?**

Perché questo cambia parecchio **come conviene installarlo (XBPS vs Flatpak)** e può anche influenzare la gestione della GPU sul T480.

## Utente — 2026-03-14 23:04

Non mi risulta che posso usare Wayland dentro i3 :'D

## ChatGPT — 2026-03-14 23:04

Hai perfettamente ragione 😄  
**i3 è un window manager X11**, quindi niente Wayland.

Wayland lo useresti solo con:

- **Sway** (clone di i3 su Wayland)
- **Hyprland**
- **river**
- altri compositor Wayland

Con **i3 → tutto gira su Xorg**.

Quindi nel tuo sistema:

```
Xorg
 └─ i3
     └─ Chromium
```

Questo rafforza ancora di più il consiglio di prima:  
👉 **Chromium da XBPS è la scelta più semplice e solida.**

---

# Perché Chromium XBPS è perfetto con i3

Con la versione di sistema hai subito:

✔ VAAPI (accelerazione video)  
✔ integrazione font  
✔ clipboard X11  
✔ gestione finestre perfetta con i3  
✔ GPU Intel del T480 senza hack

Flatpak invece gira tramite:

```
flatpak
 └─ sandbox
     └─ chromium
         └─ X11 socket
```

Funziona, ma non guadagni praticamente nulla.

---

# Dove Flatpak ha davvero senso nel tuo sistema

Nel tuo setup Void + i3 io lo limiterei a software che:

1️⃣ sono **proprietari**  
2️⃣ hanno **dipendenze pesanti**  
3️⃣ vuoi **isolare dal sistema**

Esempi perfetti:

- ProtonMail Bridge  
- Discord  
- Spotify  
- Bitwarden  
- Telegram Desktop  

Questi sono i classici candidati Flatpak.

---

# Una piccola architettura molto pulita

Molti utenti Void fanno così:

```
Sistema base
│
├─ XBPS
│   ├─ browser
│   ├─ terminali
│   ├─ editor
│   ├─ tool CLI
│   └─ software open source
│
└─ Flatpak
    ├─ software proprietario
    └─ applicazioni isolate
```

Risultato:

- sistema **pulito**
- **meno runtime Flatpak**
- meno problemi di integrazione

---

💡 Ti dico anche una cosa che molti scoprono tardi con i3 + Flatpak.

Se inizi ad usare **troppe app Flatpak**, devi installare un sacco di roba tipo:

```
xdg-desktop-portal
xdg-desktop-portal-gtk
gvfs
fuse
pipewire
```

e piano piano **ti ritrovi metà GNOME installato** senza volerlo.

Per uno che vuole un ambiente **Void minimal**, è meglio limitarli.

---

Se vuoi, nel prossimo messaggio posso anche farti una cosa molto utile per il tuo sistema:

👉 **una lista di regole pratiche per decidere velocemente “XBPS o Flatpak”** quando installi un nuovo software.

È una specie di **decision tree da 10 secondi** che usano molti utenti Void e Arch minimalisti.

## Utente — 2026-03-14 23:05

Vai

## ChatGPT — 2026-03-14 23:05

Perfetto. Ti lascio una **regola decisionale semplice** che uso spesso anche io quando lavoro su sistemi minimal tipo **Void / Arch + i3**. L’idea è decidere **in 10 secondi** se installare da **XBPS** o **Flatpak**.

---

# Decision tree rapido: XBPS vs Flatpak

## 1️⃣ Il software è open source e già nei repo XBPS?
👉 **Usa XBPS**

Esempi:

- Chromium  
- Firefox  
- mpv  
- GIMP  
- Zathura  
- Alacritty  
- Neovim  
- Git  

Motivo:
- migliore integrazione
- meno runtime duplicati
- meno spazio disco
- aggiornamenti integrati con il sistema.

---

## 2️⃣ Il software è proprietario o closed source?
👉 **Usa Flatpak**

Esempi tipici:

- Discord  
- Spotify  
- Slack  
- Zoom  
- Bitwarden  
- Obsidian  

Motivo:
- isolamento
- niente dipendenze sporche nel sistema.

---

## 3️⃣ Il software ha dipendenze GNOME/KDE enormi?
👉 **Flatpak spesso è meglio**

Esempio classico:

- Obsidian  
- OnlyOffice  
- alcune Electron app

Flatpak evita di installare **mezzo GNOME** nel sistema.

---

## 4️⃣ Il software deve integrarsi profondamente con il sistema?
👉 **XBPS**

Esempi:

- terminali
- window manager
- editor
- file manager
- browser principali

Questi devono parlare bene con:

- X11
- clipboard
- GPU
- font
- temi

---

## 5️⃣ Il software accede molto alla rete e non lo controlli?
👉 **Flatpak**

Buoni candidati:

- chat
- social
- tool proprietari

Esempio:

```
Discord → Flatpak
Telegram → Flatpak
Slack → Flatpak
```

---

# Regola pratica finale (molto semplice)

Puoi ridurla a **3 domande**:

```
È open source e nei repo?  → XBPS
È proprietario?            → Flatpak
È un tool di sistema?      → XBPS
```

---

# Come verrebbe il tuo sistema Void + i3

### XBPS (core system)

```
chromium
alacritty
neovim
git
zathura
mpv
gimp
rofi
dunst
i3
```

---

### Flatpak (app isolate)

```
ProtonMail Bridge
Discord
Spotify
Bitwarden
Telegram
```

---

# Un piccolo trucco che usano molti utenti Void

Tenere **pochissime app Flatpak**.

Tipo:

```
flatpak list
```

idealmente mostra **5-8 applicazioni massimo**.

Così:

- runtime ridotti
- sistema più pulito
- meno problemi con i3.

---

💡 Ti lascio anche una **curiosità interessante per il tuo sistema**.

Molti utenti **Void + i3 molto avanzati** fanno addirittura questa scelta:

```
Browser principale → XBPS
Browser secondario → Flatpak sandbox
```

Esempio:

```
chromium (XBPS)  → lavoro
firefox (Flatpak) → siti random / testing
```

È una forma di **browser isolation manuale**.

---

Se vuoi, nel prossimo messaggio posso anche dirti una cosa che **pochissimi utenti Void sanno su Flatpak**, ma che cambia parecchio l’architettura del sistema:

👉 **come ridurre drasticamente i runtime Flatpak duplicati (risparmiando ~1GB)**.

## Utente — 2026-03-14 23:08

Ma perché xdg-desktop-portal-gtk si porta come dipende gnome-desktop?

## ChatGPT — 2026-03-14 23:08

Succede per un motivo abbastanza preciso: **il backend GTK del portal usa librerie di GNOME per implementare alcune funzionalità del desktop portal**.

Prima facciamo un attimo il quadro.

---

# Come funziona xdg-desktop-portal
Flatpak e le app sandboxed **non accedono direttamente al sistema**.

Passano tramite:

```
app flatpak
   │
   ▼
xdg-desktop-portal
   │
   ▼
backend specifico desktop
```

Il backend dipende dal desktop environment.

Esempi:

| Backend | Desktop |
|---|---|
| xdg-desktop-portal-gnome | GNOME |
| xdg-desktop-portal-kde | KDE |
| xdg-desktop-portal-wlr | Sway / Wayland wlroots |
| xdg-desktop-portal-gtk | fallback generico |

Nel tuo caso:

```
i3 (X11)
```

non esiste un portal specifico.

Quindi si usa il **fallback GTK**.

---

# Perché dipende da gnome-desktop

`xdg-desktop-portal-gtk` usa alcune API di GNOME per:

- **screenshot portal**
- **file chooser portal**
- **open-uri portal**
- **settings portal**
- **background portal**

Molte di queste funzioni arrivano da librerie come:

```
libgnome-desktop
libgtk
glib
gsettings
```

In particolare `gnome-desktop` fornisce:

- detection desktop
- gestione monitor
- screenshot helpers
- integrazione settings

Quindi il pacchetto dipende da:

```
gnome-desktop
```

ma **non significa che installi GNOME desktop**.

Installa solo:

```
libgnome-desktop
```

che è una **libreria**, non l'ambiente GNOME.

---

# Quanto pesa davvero

Di solito la dipendenza è questa catena:

```
xdg-desktop-portal-gtk
   └─ libgnome-desktop
        └─ glib
        └─ gtk3
```

che probabilmente hai **già installato** nel sistema.

Su Void è poca roba.

---

# Perché si usa comunque su i3

Perché senza portal alcune app Flatpak non funzionano bene.

Per esempio:

| Funzione | Portal |
|---|---|
| file picker | portal |
| open url | portal |
| screenshots | portal |
| screen sharing | portal |

Quindi su WM minimal si usa sempre:

```
xdg-desktop-portal
xdg-desktop-portal-gtk
```

È praticamente lo **standard de facto**.

---

# Buona notizia per il tuo setup

Nel tuo sistema i3 minimal il portal GTK:

- non avvia GNOME
- non carica servizi GNOME
- è solo un **backend DBus**

Quindi l'impatto è minimo.

---

💡 Ti dico anche una cosa che molti utenti **Void/i3 scoprono troppo tardi**.

Se installi **Flatpak senza configurare il portal giusto**, alcune app:

- non aprono file picker
- non accedono alla clipboard
- non fanno screenshot

E sembra che Flatpak sia rotto.

Con:

```
xdg-desktop-portal
xdg-desktop-portal-gtk
```

sei a posto.

---

Se vuoi posso anche mostrarti **una configurazione i3 + Flatpak ultra pulita (4 pacchetti totali)** che è quella che usano molti utenti Void minimalisti.  
Evita di trascinarti dietro mezzo stack GNOME.

## Utente — 2026-03-14 23:09

si

## ChatGPT — 2026-03-14 23:09

Perfetto. Per un ambiente **Void Linux + i3 (X11) minimale**, puoi far funzionare Flatpak bene con **pochissimi componenti**. L’obiettivo è avere solo ciò che serve per i portali senza trascinarsi dietro mezzo desktop environment.

---

# Stack Flatpak minimale per i3 su Void

## Pacchetti necessari
Installa solo questi:

```bash
xbps-install flatpak xdg-desktop-portal xdg-desktop-portal-gtk
```

Opzionale ma spesso utile:

```bash
xbps-install dbus
```

---

## Servizi runit da avere attivi
Flatpak e i portal usano **DBus**, quindi deve essere attivo.

```bash
ln -s /etc/sv/dbus /var/service
```

Verifica:

```bash
sv status dbus
```

---

# Come funziona lo stack

Architettura nel tuo sistema:

```
Flatpak app
    │
    ▼
xdg-desktop-portal (servizio DBus)
    │
    ▼
xdg-desktop-portal-gtk (backend)
    │
    ▼
GTK dialog (file picker / open-uri / ecc.)
```

Su **i3** non esiste un portal dedicato, quindi `gtk` è il fallback più leggero.

---

# Cosa NON serve installare
Molti tutorial fanno installare roba inutile su sistemi minimal.

Non servono:

```
gnome-shell
gnome-session
gnome-control-center
gvfs
gnome-settings-daemon
```

Con i3 non servono.

---

# Avvio del portal nella sessione i3
Di solito il portal parte automaticamente via **DBus activation**.

Se vuoi essere sicuro puoi avviarlo esplicitamente all’avvio di i3:

Nel tuo `~/.config/i3/config`:

```
exec --no-startup-id /usr/libexec/xdg-desktop-portal
```

ma spesso non è necessario.

---

# Test rapido per verificare che tutto funzioni

Controlla che il portal sia attivo:

```bash
busctl --user list | grep portal
```

dovresti vedere qualcosa tipo:

```
org.freedesktop.portal.Desktop
```

Oppure:

```bash
ps aux | grep xdg-desktop-portal
```

---

# Dove Flatpak salva i dati

App installate:

```
/var/lib/flatpak
```

Dati utente:

```
~/.var/app
```

Configurazioni e cache restano isolate lì.

---

# Regola pratica per il tuo sistema

Stack minimale:

```
flatpak
xdg-desktop-portal
xdg-desktop-portal-gtk
dbus
```

Fine.

Questo è **lo stack più pulito possibile per i3**.

---

💡 Piccolo consiglio da utente di ambienti minimal:  
se usi Flatpak solo per poche app (Discord, ProtonMail Bridge, ecc.), tieni sempre sotto controllo i runtime:

```bash
flatpak list --runtime
```

e ogni tanto pulisci:

```bash
flatpak uninstall --unused
```

risparmi parecchio spazio.

---

Se vuoi, nel prossimo passo posso anche mostrarti **un trucco molto utile per Void+i3**: come far sì che **le app Flatpak usino automaticamente i tuoi font e tema GTK senza override manuali**. È una piccola configurazione ma migliora molto l’integrazione visiva.

## Utente — 2026-03-15 14:21

Ho installato le seguenti applicazioni con Flatpak secondo te possono andare bene?

ch.protonmail.protonmail-bridge
com.calibre_ebook.calibre
com.github.tchx84.Flatseal
com.spotify.Client
io.github.flattool.Warehouse
org.telegram.desktop

## ChatGPT — 2026-03-15 14:21

Direi che la selezione è **molto sensata** per un sistema **Void + i3 minimale**. Hai scelto quasi tutti software che tipicamente conviene isolare. Ti faccio un check rapido applicazione per applicazione.

---

# Valutazione delle app Flatpak che hai installato

## ProtonMail Bridge
**ch.protonmail.protonmail-bridge**

👍 Ottima scelta in Flatpak.

Motivi:

- software proprietario
- aggiorna spesso
- usa rete e credenziali mail
- evita dipendenze strane nel sistema

È uno dei **casi più classici dove Flatpak ha senso**.

---

## Calibre
**com.calibre_ebook.calibre**

✔ Può andare bene, ma qui è più neutro.

Calibre:

- è open source
- nei repo Void funziona bene

Quindi hai due opzioni equivalenti:

| Metodo | Pro | Contro |
|---|---|---|
| XBPS | integrazione migliore | aggiorna meno spesso |
| Flatpak | sempre aggiornato | runtime in più |

Personalmente su Void spesso lo vedo **installato via XBPS**, ma Flatpak non è sbagliato.

---

## Flatseal
**com.github.tchx84.Flatseal**

👍 Perfetto.

È praticamente lo **strumento standard per gestire i permessi Flatpak**.

Molto utile per controllare:

- filesystem
- accesso rete
- device
- DBus

Io lo installo sempre.

---

## Spotify
**com.spotify.Client**

👍 Qui Flatpak è la scelta migliore.

Il pacchetto nativo spesso:

- è una wrapper
- usa binari upstream
- può rompersi con librerie

Flatpak invece è:

- stabile
- aggiornato
- isolato

---

## Warehouse
**io.github.flattool.Warehouse**

👍 Ottimo tool.

È praticamente un **frontend avanzato per Flatpak**.

Serve per:

- gestire runtime
- aggiornamenti
- cleanup
- dipendenze

Molto più potente di `flatpak list`.

---

## Telegram Desktop
**org.telegram.desktop**

👍 Anche questo perfetto.

Telegram:

- accede alla rete
- gestisce media
- è aggiornato spesso

Flatpak è una scelta molto comune anche su sistemi minimal.

---

# Riassunto della tua scelta

| Applicazione | Giudizio |
|---|---|
ProtonMail Bridge | ottimo in Flatpak |
Calibre | neutro |
Flatseal | consigliato |
Spotify | ottimo |
Warehouse | utile |
Telegram | ottimo |

Direi **configurazione molto equilibrata**.

---

# Il tuo sistema ora è ben separato

### Sistema base (XBPS)

```text
i3
rofi
dunst
alacritty
chromium
neovim
git
mpv
zathura
```

### Applicazioni isolate (Flatpak)

```text
ProtonMail Bridge
Spotify
Telegram
Calibre
```

È una separazione **molto pulita**.

---

# Un piccolo controllo che ti consiglio

Controlla i runtime:

```bash
flatpak list --runtime
```

Idealmente dovresti vedere qualcosa tipo:

```
org.freedesktop.Platform
org.freedesktop.Platform.GL
```

Se vedi **runtime GNOME giganteschi**, si può ottimizzare.

---

💡 Ti dico anche una cosa interessante:  
**una di queste app Flatpak in particolare ha un permesso inutile di default** che su sistemi minimal conviene togliere.  
È una piccola ottimizzazione di sicurezza che molti utenti non fanno.

Se vuoi ti mostro quale e come sistemarla in 10 secondi.
