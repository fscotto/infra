# Sistema operativo e distribuzioni — Linux, Unix, BSD

> Distillato dalle conversazioni ChatGPT elencate in fondo (transcript completi in ~/.config/ai/memory/chatgpt/transcripts/).
> Generato da scripts/chatgpt_export_to_memory.py + distillazione AI, 2026-11-08.

## Posizioni e preferenze stabili

- Criterio guida per la distro ideale: fedeltà a UNIX sia nella filosofia sia nell'esecuzione tecnica (organizzazione leggibile e componibile del sistema); conta la coerenza, non l'estetica "retro".
- Preferenza stabile: restare lontano da systemd; runit apprezzato per minimalismo, leggibilità dei servizi, assenza di "piattaforma integrata"; xbps-src considerato trasparente e formativo (studio del packaging e del basso livello).
- Void Linux = distro "strumento" di riferimento ("Penso che Void Linux sia perfetta", 2025-07); nel playbook personale il profilo Void ha SwayFX predefinito + Hyprland.
- Distro "strumento" (Void, Arch, Gentoo, Alpine, Debian minimale) preferita alle distro "ambiente" (Mint, Fedora Workstation, Ubuntu): l'ambiente pronto è accettabile solo quando serve stabilità già testata.
- Workflow consolidato dentro Emacs (mu4e, elfeed, org-mode, pdf-tools) → bassa dipendenza dal desktop: accettabile sia tiling WM sia floating, se l'intero workflow vive in terminale/Emacs.
- Preferenza netta per applicazioni GTK: Firefox, Emacs GTK, Thunar/Nemo, Xournal++, pavucontrol, nm-applet, blueman, dunst/mako, rofi/wofi.
- Per lo sviluppo in C non serve inseguire l'ultima versione del compilatore (C11 è sufficiente, anche per il kernel).
- Separazione netta core system / user environment (2026-01-28), regola del setup BSD:
  - core system: minimale, stabile, non-opinionated (kernel, init, libc, coreutils, rete base, /etc); sudo serve solo per il core.
  - user environment: opinionated, ricostruibile, buttabile, versionabile ($HOME/.config + dotfiles via git+stow); test: "se cancello $HOME e lo ricostruisco da git, il sistema deve restare sano".
  - categoria "svago" (mpv, ncmpcpp, yt-dlp) separata dai tool di lavoro; il browser (LibreWolf) accettato come compromesso inevitabile.
- Minimalismo anche nei font: Nerd Fonts rimossi con la "pulizia UNIX"; scelta finale Liberation Mono; Inconsolata unica alternativa piaciuta; Hack, Fira Code, JetBrains Mono rifiutati come "developer font" (ligature, IDE-centric, marketing).
- Coerenza UNIX dei terminali (rating ChatGPT, 2025-07): st > foot > alacritty > kitty > wezterm.
- Shell su BSD: /bin/sh (POSIX) per scripting e portabilità (shell di root da FreeBSD 14+), tcsh/csh storica, zsh/bash per uso interattivo moderno, ksh su OpenBSD; sui propri sistemi usa bash come shell utente.
## Criteri di scelta e valutazioni (distro/OS provati)

- 2025-07 · "Quale distro Linux è più UNIX": candidate valutate Slackware, Gentoo, CRUX, Alpine, Arch, Void → scelta Void (runit, nata da ex utenti NetBSD, rolling senza essere caotica). Flatpak discusso come deviazione dalla filosofia UNIX; piano di sostituire i tool Electron/X11 con alternativi nativi Wayland; setup Hyprland minimale con ssh/gpg integrato; configurazione kitty convertita in foot.ini (tema catppuccin frappe).
- 2025-09 → 2026-03 · conversazione "Sistema operativo" (304 messaggi, il percorso completo):
  - ChatGPT indica Void+runit come sistema ideale (coerenza UNIX, studio kernel/user space, Emacs senza sovrastrutture).
  - Deviazione "stabilità": Linux Mint + workflow interamente in Emacs ("la distro conta poco"); desktop: sessione XFCE con i3 come window manager + tool XFCE/Cinnamon alternativi.
  - Scelte registrate durante la chat (poi superate): EndeavourOS su tutti i desktop → Arch Linux dichiarata "distribuzione di riferimento".
  - Stato flotta dichiarato (all'epoca): deadalus (workstation di lavoro) → Debian stable (o Ubuntu LTS solo per problemi hardware); prometheus (RPi 4) → Ubuntu LTS; ikaros (desktop personale) → Void + XFCE+i3, valutando i3 puro; portatile dedicato a FreeBSD per test/studio.
  - Debian "esperta" minimale (LUKS2 + btrfs + zram + XFCE+i3): provata in VM → scartata, installazione troppo macchinosa.
  - Mint XFCE (btrfs, Timeshift, YubiKey per sblocco LUKS con password di fallback via systemd-cryptenroll, YubiKey pam per login+sudo) → scartata: Mint/Ubuntu impongono automaticamente layout ext4 invece di btrfs.
  - Fedora spin XFCE = base finale della workstation: script idempotente per il layout dei subvolumi (copia dei dati in /var/log e /var/cache), snapper con snapshot pre-aggiornamento dnf, entry snapper in GRUB → da qui evolve il playbook Ansible fedora-playbook (repo verificato su codeberg, poi https://github.com/fscotto/fedora-playbook).
  - Nella stessa chat nasce l'interesse per NixOS (configurazione portabile via flake, prova su WSL prima di altre macchine).
- 2026-01 · BSD per un laptop di studio: comprato un Lenovo ThinkPad T480; scelto FreeBSD perché è l'unico BSD che parte con il Wi-Fi funzionante ("gli altri o non partono o non riescono a connettersi al wifi"); OpenBSD apprezzato (filosofia, sicurezza, driver iwx(4)) ma più compromesso su laptop; NetBSD/DragonFlyBSD citati ma non scelti.
- 2026-03 · Bluefin (Universal Blue, Fedora Silverblue immutabile, developer image con KVM/QEMU, Podman, VSCode) valutato come sistema del portatile di lavoro ("deve funzionare sempre"): a favore — aggiornamenti atomici rpm-ostree, rollback, Btrfs già configurato, manutenzione quasi zero; contro — minor controllo (solo layering rpm-ostree o immagine custom), Ansible perde senso, filosofia container-first vs tool locale (mise); nessuna decisione finale registrata.
- 2026-03 · NixOS: configurazione sperimentale partita dal fedora-playbook (host deadalus); nessun esito successivo documentato.
- 2026-06 · Scelta distro "per filosofia", con playbook già pronto e profilo Void attivo: adora Void e la sua configurazione SwayFX/Hyprland ma trova fragile il supporto Hyprland (repo di terzi) e cerca un ambiente più supportato; ora accettabile anche un WM floating se il workflow resta in terminale/Emacs. Fallback valutati: KDE più istituzionale su Void (handbook ufficiale: kde-plasma, kde-baseapps, SDDM), Cinnamon più GTK-friendly ma poco integrato su Void. Decisione finale: restare su Hyprland finché il problema non si pone; nel playbook SwayFX è il predefinito; se il repo Hyprland si ferma, sistemare il playbook da SwayFX verso KDE, migrando le app verso Qt solo dove dà integrazione reale (Dolphin, Okular, Spectacle, Gwenview, Ark; tenere Firefox, Emacs, Alacritty, Xournal++, pavucontrol). "KDE non deve diventare una religione."
## Configurazioni e esiti pratici

### FreeBSD su ThinkPad T480 (2026-01)
- Hardware: em0 (Intel I219-LM) con link flapping "no carrier" → risolto pulendo i connettori fisici di router e PC (difetto hardware: non funzionava nemmeno su Linux); ue0 = scheda della dock USB-C, da non confondere con em0; Wi-Fi con driver iwm funzionante da sistema base.
- Rete finale in rc.conf:
  ```sh
  # /etc/rc.conf
  ifconfig_em0="DHCP mtu 1480"
  wlans_iwm0="wlan0"
  ifconfig_wlan0="WPA DHCP"
  ```
- pr_io_timeout_error (HTTPS in timeout; ping e SSH OK; nessun firewall attivo: pf.ko non caricato, ipfw non abilitato) → diagnosi: PMTU blackhole — "frag needed and DF set (MTU 1480)", path reale 1480 (probabile PPPoE/VLAN); diagnostica: `ping -D -s 1472 8.8.8.8`, `traceroute -M do -s <size>`; opzionale `net.inet.tcp.mssdflt=1440` in /etc/sysctl.conf. Nota: FreeBSD è RFC-compliant e non maschera gli errori di rete (Linux "funziona spesso" grazie a fallback MSS più permissivo).
- GPU: dGPU NVIDIA (drmn0 "Link Training Unsuccessful", Optimus) lasciata non gestita; si usa la sola iGPU con drm-kmod.
- Desktop minimal: `pkg install xorg dwm stterm xinit`; `~/.xinitrc` con `exec dwm`; dwm/dmenu/st compilati manualmente dalla propria repo; extra: slstatus, xrandr, xrdb; aggiornamenti: `freebsd-update fetch install` + `pkg upgrade`.
- Pacchetti utente finali (setup ritenuto coerente): bash, dmidecode, drm-kmod, entr, feh, fzf, git, git-delta, isync, lf, librewolf, mpv, ncmpcpp, nsxiv, pkg, pkgconf, sfeed, stow, sudo, tmux, vim, wget, xclip, xlsfonts, xorg, yt-dlp.
- Prompt shell minimale (solo info git + un po' di colore); fzf per la history con bug di selezione corretto; font finale: Liberation Mono.
### Script di installazione Void (2026-03, gist install_void_btrfs.sh, host `nymph`)
- Layout disco richiesto e ottenuto: /boot/efi (FAT32, 512M) + /boot (ext4, 1024M) + root btrfs su LUKS2; LVM rimosso; montaggi via `UUID=<BTRFS_PART_UUID>`; subvolumi: @ (radice), @home, @libvirt (/var/lib/libvirt), @cache, @log, @docker (/var/lib/docker), @snapshots; NODATACOW su @docker e @libvirt; opzioni btrfs: noatime,compress=zstd.
- Configurazione dello script:
  ```bash
  HOSTNAME="nymph"; USERNAME="fscotto"
  USER_SHELL="/bin/bash"; TIMEZONE="Europe/Rome"
  CRYPT_NAME="cryptroot"; EFI_SIZE="+512M"; BOOT_SIZE="+1024M"
  BTRFS_OPTS="noatime,compress=zstd"
  ```
- Fix di scripting applicati: heredoc quotati `<<'EOF'` (nel gist erano troncati e corrompevano i file generati → lo script "spariva" senza errori dopo i locales); variabili esterne passate al chroot con `xchroot /mnt env ... /post_install.sh`; CRYPT_UUID ricavato con `blkid` dentro il chroot; `rm -f /etc/resolv.conf || true` + `ln -sf /run/NetworkManager/resolv.conf` per evitare uscite silenziose con `set -e`; debug consigliato: `set -x` + `trap ... ERR`.

### NixOS (2026-03, bozza)
- Struttura proposta: `flake.nix` + `hosts/deadalus/{configuration,hardware-configuration}.nix` + `home/fscotto.nix`; nixpkgs `nixos-24.11`, home-manager `release-24.11` (useGlobalPkgs, useUserPackages); replica i blocchi del playbook Fedora: Flatpak+Flathub (Chrome/Telegram/Spotify/Postman/DevPod), policy Snapper + grub-btrfs, hardening (sysctl, sudo, firewall, session timeout, auto-upgrade), YubiKey + pcscd + regole udev, dotfiles + stow, font.
## Thread aperti

- Bluefin vs Fedora+playbook per il portatile di lavoro: valutazione fra "affidabilità e manutenzione quasi zero" e "controllo esplicito della macchina"; nessuna decisione finale.
- Prova NixOS ferma alla configurazione flake proposta (porta del fedora-playbook); nessuna installazione o test documentato.
- FreeBSD: patch dello stack grafico dwm+st+dmenu+slock rimandata a un thread dedicato; dGPU NVIDIA/Optimus non gestita.
- MTU: sistemare l'MTU sul router/ISP (soluzione "definitiva"), capire perché il path è 1480; eventuale check automatico via rc.d; MSS clamping (mssdflt=1440) non decisionato.
- DNS su Void: scelta definitiva tra NetworkManager default, resolvconf o "non toccare resolv.conf" lasciata in sospeso.
- Documento di separazione core/user: da versionare come SYSTEM_LAYOUT.md / PHILOSOPHY.md nella repo principale, con sezione anti-pattern (es. editor in /usr/local con config in /etc) e bootstrap formalizzato (installazione base → clone dotfiles → sistema ricostruito).
- KDE come fallback su Void: sostituzione opportunistica delle app verso Qt (Dolphin, Okular, Spectacle, Gwenview, Ark) solo se/dove dà integrazione reale; da rivalutare solo se il repo Hyprland si fermasse.

## Fonti
| Data | Conversazione | Transcript |
| --- | --- | --- |
| 2025-07-14 | Distribuzioni Linux più UNIX | transcripts/2025-07-14-distribuzioni-linux-piu-unix.md |
| 2025-09-17 | Sistema operativo | transcripts/2025-09-17-sistema-operativo.md |
| 2026-01-16 | Sistemi BSD per laptop | transcripts/2026-01-16-sistemi-bsd-per-laptop.md |
| 2026-01-25 | Shell più usate BSD | transcripts/2026-01-25-shell-piu-usate-bsd.md |
| 2026-01-26 | Font UNIX simili Nerd | transcripts/2026-01-26-font-unix-simili-nerd.md |
| 2026-01-28 | Separazione core system user | transcripts/2026-01-28-separazione-core-system-user.md |
| 2026-01-29 | Troubleshooting FreeBSD Firewall | transcripts/2026-01-29-troubleshooting-freebsd-firewall.md |
| 2026-03-03 | Configurazione NixOS da Fedora | transcripts/2026-03-03-configurazione-nixos-da-fedora.md |
| 2026-03-04 | Void Linux install script | transcripts/2026-03-04-void-linux-install-script.md |
| 2026-06-21 | Scelta distro Linux filosofia | transcripts/2026-06-21-scelta-distro-linux-filosofia.md |