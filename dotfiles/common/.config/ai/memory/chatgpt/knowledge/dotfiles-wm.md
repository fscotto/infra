# Desktop — window manager, dotfiles, shell

> Distillato dalle conversazioni ChatGPT elencate in fondo (transcript completi in ~/.config/ai/memory/chatgpt/transcripts/).
> Generato da scripts/chatgpt_export_to_memory.py + distillazione AI, 2026-11-08.

## Preferenze e conclusioni stabili

- Filosofia UNIX/suckless come bussola: core system "noioso, stabile, sostituibile" separato dallo user environment (rif. separazione_core_system_vs_user_environment.md); tool piccoli e compositabili, niente feature creep né patch/dipendenze speculative.
- Velocità > effetti: compositing rimosso del tutto; anche su Hyprland niente blur/ombre/rounding, bordi sottili e contrasto pulito.
- Tiling statico (i3) sufficiente: abitudine a 1-2 finestre per workspace (quasi mai 3); apprezzata la modalità tab di i3; la filosofia dinamica di dwm piace "per curiosità" ma non serve al suo workflow.
- Preferenza per tool GTK su Qt: flameshot accettato solo come deviazione pragmatica e in seguito sostituito dal tool screenshot di XFCE; spectacle e xfce4-screenshooter scartati per le dipendenze.
- Font: nerd font esclusi ("troppo pesanti"; st con font fixed); scelta stabile successiva Liberation / Liberation Mono per terminale, bar e GTK; icone Papirus nell'esperimento Sway 2025.
- Wayland giudicato architetturalmente migliore ma immaturo: screencasting via portali, clipboard e tooling giovani sono limiti reali; X11 ritenuto non morente, anche per il fork XLibre.
- Su FreeBSD restare su Xorg: XLibre = entropia nel core (governance incerta, rischi input/GPU); Wayland su BSD "supportato ma non centrale" (DRM via port linuxkpi), da default solo su Linux.
- Login senza display manager (scelta esplicita): TTY → PAM → startx → i3 con dbus-run-session; su Void elogind; in precedenza lightdm.
- Flatpak riservato a GUI che accedono alla rete e software proprietari; XBPS per il resto; stack minimale flatpak + xdg-desktop-portal + xdg-desktop-portal-gtk + dbus (runit).
- Shell: un solo .bashrc portabile Void Linux + FreeBSD (detection via uname -s, alias con fallback GNU/BSD), niente GNU-centrismi né framework.

## Traiettoria storica (i3 → dwm → Hyprland → rimozione)

- 2025-07 "Tiling WM vs DE": interesse iniziale per Hyprland su Arch (tema catppuccin-frappe, kitty, waybar, hyprpaper, Thunar, ssh/gpg-agent via systemd, rofi-wayland poi sostituito con fuzzel) → cambio idea verso Sway; script di installazione convertito a Void (no systemd: link runit per dbus e NetworkManager, xinitrc): sway, fuzzel, foot, waybar, mako, grim+slurp, swayidle+swaylock, swaybg, pipewire, thunar, Papirus, font Cascadia Code Nerd.
- 2026-01 stagione suckless su FreeBSD: dwm patchato + st + dmenu + dwmblocks (poi slstatus) + dunst + clipboard clipmenu/xclip; schema colori habamax condiviso dwm/dmenu/st via Xresources; wallpaper versionato; migrazione a XLibre valutata e respinta (resta Xorg).
- 2026-03-05 Hyprland "all-black" su Void (ThinkPad T480): esperimento Nothing-style monocromatico (#000000/#0a0a0a/#e6e6e6, accent #ffffff), layout master, bordi bianchi sottili, wallpaper full-black con Gargantua; bar: dapprima Yambar, poi waybar (scelta per la system tray: cpu/ram/disco/tray, icone grandi, font Liberation, rebase sulla conf waybar già presente nel repo).
- 2026-03-06/17 i3 su Void (nymph): macchine dichiarate — ikaros (workstation, Void+XFCE+i3), nymph (laptop T480, da Void+Hyprland a i3; idea iniziale FreeBSD+dwm persa per problemi di dual boot; deve essere stabile per eventi), voidtest (laptop di test, Void+XFCE+i3), deadalus (lavoro, Windows → previsto Debian+GNOME); piano: ikaros → Xorg+i3, nymph → XLibre+i3, voidtest → Hyprland "i3-like"; "scelta di produttività" dichiarata: i3.
- Evoluzione tool dichiarata nello stack i3: polybar → i3blocks, diodon → clipboard XFCE (clipman), flameshot → screenshot di XFCE.
- Esito finale (fuori da queste chat): i3 rimosso dal repo (scripts/remove_i3.sh); ikaros/nymph oggi Fedora GNOME con dotfiles condivisi; su Void il profilo desktop gestisce Sway e Niri (.bashrc.d, alacritty, foot, rofi, waybar, wlogout, mpv).

## Prompt bash e shell

- Prompt bash single-line stile dark/gothic "con accento BSD", formato finale: `fscotto:~/src/dotfiles <main> ›`; path "classico" con `~/` al posto di `/home/fscotto`; colori un po' accesi; no powerline, nessuna Nerd Font obbligatoria.
- Feature del prompt: branch git + stato repo (`* + ?`), venv Python, rilevamento container/chroot, host mostrato solo via SSH, exit code riflesso nel colore del simbolo ($ vs # per root).
- Origini: config Bash "sobria" nata su FreeBSD (branch git nel prompt + fzf sulla history), poi resa realmente portabile tra Void Linux e FreeBSD.
- .bashrc portabile: PLATFORM via `uname -s`; HISTSIZE=10000, HISTFILESIZE=20000, HISTCONTROL=ignoredups:erasedups, HISTIGNORE='ls:ll:la:l:pwd:exit:clear:history'; sync history via PROMPT_COMMAND (`history -a; -c; -r`); shopt histappend checkwinsize cmdhist; set -o emacs; exit se non interattiva.
- Alias: `ls --color=auto` con fallback `ls -G`, `grep --color=auto`, l/ll/la, `..`/`...`, git (g, ga, gb, gc, gca, gco, gd, gl, gp, gs, glog), cp/mv/rm con `-i`; PATH con ~/.local/bin e ~/bin; umask 022.
- fzf su Ctrl-r (bind -x `__fzf_history__`: history deduplicata, ordine inverso, layout reverse 40%).

## Configurazioni specifiche (st, dmenu, slstatus, notifiche, clipboard)

- st: patch applicate alpha, blink-cursor, oneclipboard, Xresources, scrollback-ringbuffer; patch mantenute in repo personale; font fixed (no glifi); patch "search" ufficiale inesistente (alternative: vim_browse, keyboard_select) → decisione: fermarsi, aggiungere patch solo a fronte di attrito reale.
- dmenu: patch case-insensitive, desktoponly, xresources; comportamento riconfigurabile via Xresources e non hardcodato; evitare patch con decorazioni, popup o menù a tab.
- dwm: patch applicate attachaside, pertag, swallow, Xresources, movestack, cyclelayouts, restartsig, titlecolor (per la bar); exitmenu scartato di proposito; patch consigliate ma non aggiunte: resizecorners o resizehere (una sola), focusonnetactive (opzionale); patch rifiutate: winview, windowtags, stacker, switcher grafici, IPC, scratchpad.
  - config.h: font Liberation Mono 12 (anche dmenufont); colori norm #222222/#bbbbbb/#444444, sel #005577/#eeeeee; tags 1-9; regole: Gimp floating, Firefox su tag 9, St come terminale (noswallow).
  - Navigazione: Mod+j/k focusstack, Mod+Shift+j/k movestack, Mod+m focusmaster; layout tile/monocle/floating implicito (cyclelayouts per ciclarli).
  - Schema habamax unico per dwm/dmenu/st via Xresources; wallpaper con percorso stabile, versionato, impostato con tool semplice (feh/xsetroot), non deve influenzare dwm.
  - Startup pulito e deterministico in un solo punto: ~/.xinitrc (o ~/.xsession) per Xresources, wallpaper, bar, input; config giudicata "da power user UNIX": non aggiungere altro.

- dwmblocks: parte dello user environment, installato in ~/.local (`make install PREFIX=$HOME/.local`); script dei blocchi in ~/.config/dwmblocks (ora, batteria, cpu, memoria, temperatura, rete, volume); blocks.h con interval + update signal (`pkill -RTMIN+N dwmblocks`); avvio via autostart di dwm.
- Tray richiesta da ProtonMail Bridge: stalonetray scartato ("veramente tremendo"); applicata la patch systray di dwm (merge riuscito).
- Blocco volume su FreeBSD: output reale di `mixer vol` è `vol.volume=0.70:0.70` + `vol.mute=on`; script definitivo (una sola chiamata a mixer, POSIX sh, mai output vuoto):

```sh
#!/bin/sh
out=$(mixer vol)
echo "$out" | grep -q 'vol.mute=on' && { printf "MUTE"; exit 0; }
vol=$(echo "$out" | awk -F'[=:]' '/vol.volume/ { printf "%d", $2 * 100 }')
printf "%s%%" "$vol"
```

- slstatus: su FreeBSD la compilazione falliva per `sndio.h` assente (sndio è l'audio di OpenBSD; su FreeBSD l'audio nativo è OSS; sndctl non c'entra nulla) → rimossi modulo volume e riferimenti `-lsndio` da config.h/config.mk: funziona senza audio.
- Verdetto architetturale: slstatus (standalone, pull-based, run→print→exit, zero IPC) preferito a dwmblocks ("mini-framework", loop residente, coupling con dwm); dichiarato più coerente con gli obiettivi minimale/ricostruibile.
- Notifiche: dunst + notify-send per dwm/X11 (dunstrc con tema coerente con st/dwm); mako come equivalente Wayland; dunst confermato anche negli stack Hyprland e i3 (con gap tra le notifiche).
- Clipboard (fase dwm): X11 ha PRIMARY (middle click) e CLIPBOARD separate, da supportare entrambe; xclip nello user environment; storia solo testo via clipmenu + clipmenud (`clipmenud &` in .xinitrc, binding Mod+v in config.h); da evitare manager grafici (parcellite, copyq), systemd user service, notifiche a ogni copia.
  - Immagini: dmenu/clipmenu non gestiscono immagini; screenshot → clipboard con `maim -s | xclip -selection clipboard -t image/png` (binding Mod+Shift+s); flameshot = deviazione pragmatica per annotazioni (Qt + demone residente); via di mezzo: `gnome-screenshot -a -c`; persistenza solo su file, mai in history.
- i3 puro su Void (nymph): stack finale dichiarato completo — i3, rofi (visualizzato stile dmenu), dunst, alacritty (nero profondo), i3blocks, powermenu rofi con icone (Shutdown/Reboot/Logout/Lock/Suspend), i3lock-color con lockscreen screenshot+blur (scrot + convert), pipewire, power management, automount USB con tray, gnome-keyring funzionante, ProtonMail Bridge verificato.
  - Temi: Yaru dark accento blue (pacchetti yaru, yaru-plus) + font Liberation per GTK, applicati da script invocato dalla config i3; palette blu #4a90d9 unificata su i3/dunst/rofi/i3blocks/i3lock; wallpaper minimal con Gargantua; rofi con contrasto ridotto tra righe non selezionate.
  - i3blocks attivi: memory, temperature, backlight, essid, keyindicator, time (script in ~/.config/i3blocks/scripts); risolti problemi di visibilità di brightness e keyindicator.
  - Keyring: la causa era il doppione di keyring `login`/`Login`; fix: un solo keyring `login` con password uguale all'utente, pam_gnome_keyring in /etc/pam.d/login (auth/session optional + use_authtok), rimosso `exec gnome-keyring-daemon` manuale dalla config i3; flusso: TTY login → PAM → startx → i3 → dbus-run-session; verifiche con secret-tool e busctl (org.freedesktop.secrets).
- Flatpak + i3 (Void): nessun problema strutturale con i3; stack minimale flatpak + xdg-desktop-portal + xdg-desktop-portal-gtk (+ dbus runit: `ln -s /etc/sv/dbus /var/service`); senza gnome-shell, gvfs, gnome-settings-daemon; portal via DBus activation; dati app in ~/.var/app.
  - App Flatpak installate (approvate): ProtonMail Bridge, Flatseal, Warehouse, Spotify, Telegram; Calibre neutro (alternativa XBPS lecita); Chromium rimasto da XBPS su ikaros.
  - Separazione dichiarata: base XBPS (i3, rofi, dunst, alacritty, chromium, neovim, git, mpv, zathura) vs app isolate in Flatpak; audit periodico `flatpak list --runtime` e `flatpak uninstall --unused`.

## Thread aperti

- dwm: exitmenu solo se strettamente necessario; policy floating via Rules (dialog, file picker) al posto di nuove patch; modello multi-monitor da decidere.
- slstatus: revisione del config.h e scelta di dove eseguirlo (loop, cron, autostart dwm); eventuale modulo OSS custom per il volume (manutenzione propria, non upstream).
- st: valutare vim_browse/keyboard_select solo a fronte di attrito reale; confronto scrollback-ringbuffer vs workflow `less`.
- i3: struttura definitiva dei dotfiles (i3, rofi, dunst, i3blocks, scripts) da preparare e replicare su ikaros; rifiniture durante l'uso quotidiano.
- Sperimenti rimandati: Hyprland "i3-like" su voidtest (plugin + keybinding stile i3) come esercizio per il futuro; XLibre previsto per nymph su Void (poi abbandonato con l'intera linea i3).
- Prompt bash: rifiniture facoltative — git dirty compatto (`<main*>`), prompt root rosso con `#`.
- Flatpak: integrazione automatica di tema/font per le app Flatpak proposta ma non implementata.
- 2026-07-19 "Notifications Summary": non pertinente (sintesi di una pagina di notifiche ChatGPT), nessun contenuto tecnico.

## Fonti

| Data | Conversazione | Transcript |
| --- | --- | --- |
| 2025-07-08 → 2025-07-16 | Tiling WM vs DE | transcripts/2025-07-08-tiling-wm-vs-de.md |
| 2026-01-27 → 2026-01-28 | Review configurazione terminale st | transcripts/2026-01-27-review-configurazione-terminale-st.md |
| 2026-01-28 | Patch consigliate DWM | transcripts/2026-01-28-patch-consigliate-dwm.md |
| 2026-01-28 | Review configurazione dmenu | transcripts/2026-01-28-review-configurazione-dmenu.md |
| 2026-01-28 | Sistema di notifiche Linux | transcripts/2026-01-28-sistema-di-notifiche-linux.md |
| 2026-01-28 → 2026-01-30 | Configurazione dwmblocks | transcripts/2026-01-28-configurazione-dwmblocks.md |
| 2026-01-29 | Configurare clipboard con dmenu | transcripts/2026-01-29-configurare-clipboard-con-dmenu.md |
| 2026-01-30 | Errore compilazione slstatus | transcripts/2026-01-30-errore-compilazione-slstatus.md |
| 2026-01-30 | Migrazione X11 a XLibre | transcripts/2026-01-30-migrazione-x11-a-xlibre.md |
| 2026-03-05 → 2026-03-10 | Configurazione Hyprland All-Black | transcripts/2026-03-05-configurazione-hyprland-all-black.md |
| 2026-03-06 → 2026-03-17 | Configurazione i3 | transcripts/2026-03-06-configurazione-i3.md |
| 2026-03-14 | Prompt bash personalizzato | transcripts/2026-03-14-prompt-bash-personalizzato.md |
| 2026-03-14 → 2026-03-15 | Flatpak con i3 | transcripts/2026-03-14-flatpak-con-i3.md |
| 2026-07-19 | Notifications Summary | transcripts/2026-07-19-notifications-summary.md |

