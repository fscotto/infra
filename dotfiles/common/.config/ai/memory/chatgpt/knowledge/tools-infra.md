# Tool e infrastruttura — VM, backup, SSH/GPG, DNS, dischi

> Distillato dalle conversazioni ChatGPT elencate in fondo (transcript completi in ~/.config/ai/memory/chatgpt/transcripts/).
> Generato da scripts/chatgpt_export_to_memory.py + distillazione AI, 2026-11-08.

## Macchine virtuali e desktop remoto

**VM Windows 11 su KVM/QEMU (da conversione P2V VMware)**
- Windows 11 fisico virtualizzato con VMware vCenter Converter Standalone; disco VMDK convertito con `qemu-img convert -p -O qcow2 in.vmdk out.qcow2` (opzione `-c` per compressione interna).
- VMDK "split": passare a qemu-img solo il file descriptor (`Windows11.vmdk`), mai i file `-s001...`.
- VM "Windows 11 - TIF": machine q35, OVMF con Secure Boot + enrolled keys e TPM 2.0 emulato, 16 GiB RAM, 4 vCPU, cpu `host-passthrough` con AES/AVX/AVX2 e `<pmu state='on'/>`, Hyper-V enlightenments `mode="custom"` (relaxed, vapic, spinlocks 8191, vpindex, runtime, synic, stimer, frequencies, tlbflush, ipi, avic).
- Driver VirtIO (qemu-guest-agent, balloon, NetKVM, viostor) installati in Windows da virtio-win.iso; passare disco a bus virtio (`io='native'`, `discard='unmap'`, `cache='writeback'`, I/O thread) e rete a virtio-net SOLO dopo aver installato i driver in Windows (prima backup dell'XML/disco); in Windows rimuovere i driver dell'hardware fisico (sensore biometrico, GPU, Wi-Fi, chipset, NVMe/RST) e impostare power plan High Performance.
- Problema impronta digitale post-P2V: risolto reimpostando il PIN di Windows.

**Risoluzione grafica VM Linux (EndeavourOS)**
- Video Virtio (QXL solo per SPICE legacy), display Spice con OpenGL + 3D accel, guest `spice-vdagent` (pacman) per auto-resize, copia/incolla e multi-monitor; su Wayland virtio-gpu funziona al 90%, per maturità di SPICE meglio sessione Plasma X11.

**Audio remoto con RDP (Remmina su Fedora Silverblue → laptop Windows 11 Pro)**
- Setup funzionante per Teams con audio bidirezionale: `Audio output mode: Local`, `Redirect local audio output: sys:pulse`, `Redirect local microphone: sys:pulse` (la build FreeRDP richiede il formato `sys:{} device:{}`; fallback `sys:alsa,device:default`).
- Lato Windows abilitare in gpedit "Allow audio and video playback redirection" e "Allow audio recording redirection"; FreeRDP consigliato ≥ 2.8.
- Test: `xfreerdp /sound:sys:pulse` e `/microphone:sys:pulse`; in Windows devono comparire "Microfono remoto RDP" e "Remote Audio". Miglioramenti suggeriti ma non adottati: `/gfx:rfx /network:auto /audio-mode:1`, NoMachine/RustDesk.

## Strategia backup (Borg, USB offline, ripristino)

**Architettura dati Atlas (NAS Rocky 9, ZFS) — tre livelli**
- ZFS snapshot (rollback e cancellazioni accidentali) → Borg → Hetzner Storage Box off-site (cifratura, deduplica, retention) → rsync → HDD USB scollegato dopo il backup (anti-ransomware; recovery banale su qualunque Linux).

**Passphrase e chiavi Borg (Borg 1.4, modalità repokey)**
- `vault_atlas_borg_passphrase` = passphrase di cifratura del repository, in `secrets/vault.yml` (Ansible Vault), mai in chiaro nel Git; Borg conserva la repokey cifrata dentro il repository.
- Credenziali distinte: la chiave SSH borg (`/etc/atlas-borg/id_ed25519`, 0600 borg:borg) autentica Atlas verso Hetzner ed è rigenerabile, NON è materiale di disaster recovery.
- Generare la passphrase con `openssl rand -base64 48` e salvarla subito nel password manager. Kit DR = passphrase Borg + export recovery key (`borg key export` dopo `borg init`, prodotto dal playbook; export cifrato senza passphrase, reintegrabile con `borg key import`; variante `--paper` da stampare) + password Ansible Vault.
- In automazione usare `BORG_PASSPHRASE`/`BORG_PASSCOMMAND`, mai la passphrase in command line (visibile in process list).
- Playbook: `ansible-playbook ansible/site.yml --limit atlas --tags borg --ask-vault-pass` (dry-run con `--check --diff`); prima caricare su Hetzner la public key borg (`atlas-borg@atlas`).

**Verifica backup Borg (primo popolamento di /zpool/archive)**
- Metriche da valutare: durata, Original size, Compressed size, Deduplicated size, dimensione repo; secondo run senza modifiche per confermare la deduplicazione; poi test con modifica controllata (attesi solo i chunk nuovi).
- `atlas-borg-backup.service`: Type=oneshot, TimeoutStartSec=infinity, SuccessExitStatus=1, Restart=on-failure/30m, Condition su `/etc/atlas-borg/{passphrase,id_ed25519,known_hosts}`, sandbox systemd.
- `Result=success` con `ExecMainExitTimestamp` vuoto = job ancora in corso, non completato (le statistiche `--stats` compaiono solo alla fine) → non interrompere il primo backup lungo.
- `borg create` sul dataset live non è uno snapshot coerente (warning "file changed while we backed it up", exit 1): decisione di design = far leggere a Borg uno snapshot ZFS (valutare il riuso degli snapshot ricorsivi già previsti), dati aggiunti durante il job entreranno nel backup successivo.

**Backup USB offline (realizzato come `atlas-usb-backup.service`)**
- Vincolo all'UUID (`atlas_usb_backup_uuid`): UUID corrisponde → mount → backup → verifica → umount, altrimenti abort; disco collegato solo durante il backup; routine manuale ogni 2–4 settimane (la presenza fisica del disco è una feature, non automatizzare il collegamento).
- rsync versionato con `--link-dest`: directory datate (es. `2026-09-23/`) + symlink `latest`, file invariati condivisi come hard link; NO mirror puro con `--delete` (propaga le cancellazioni).
- Il service gestisce namespace privato, LUKS, snapshot consistente, rsync, verifica checksum, pubblicazione `latest`, cleanup; oltre all'exit code controllare filesystem montato corretto e struttura plausibile; restore test periodico su un campione di file.

**Ripristino e monitoraggio (protezione dati operativa)**
- Test Borg normale completato: `borg extract` dell'archivio reale da Hetzner in dir temporanea, confronto di 170 file con `/zpool/archive` → backup leggibile e ripristinabile.
- Checklist: recovery indipendente per livello — ZFS (recupero file da `.zfs/snapshot`, senza rollback), Borg/Hetzner da ambiente pulito (recovery key offline + passphrase + nuova SSH key), USB. Manca ancora il test Borg da ambiente pulito.
- Controlli: `zpool status` ONLINE senza errori READ/WRITE/CKSUM, scrub/resilver senza errori, SMART (reallocated/pending/uncorrectable, self-test), temperature, spazio 80%/90% (pool e dataset), fallimenti unit systemd, età dell'ultimo backup riuscito; "timer attivo" ≠ "backup recente"; un backup "silenziosamente morto" (timer mai partito) non produce failure.
- Proposta `atlas-health-check.timer` (ogni 15–30 min, controlli pesanti giornalieri), silenzioso se tutto OK; alert via email o ntfy; livello 1 failure immediate → 45Drives Alerts, livello 2 controlli periodici giornalieri, livello 3 Prometheus/Grafana solo come evoluzione.
- Prometheus (Raspberry Pi) come controllo esterno (Atlas raggiungibile? metriche fresche? backup recente?); base per il futuro "backup pull da Prometheus verso Atlas"; voce checklist completata solo dopo aver provocato un errore innocuo e ricevuto l'alert (configurato ≠ verificato).
- 45Drives Cockpit Scheduler (Houston, Rocky 9 supportato): genera unit systemd service+timer; task nativi scrub ZFS, SMART self-test, snapshot ZFS, rsync, replica ZFS, custom. Migrazione selettiva: sì a scrub e SMART self-test; snapshot da valutare (vs nostra retention); no a Borg, backup USB e reminder USB (già negli Alerts). Da verificare prima: integrazione reale Scheduler→Cockpit Alerts sulla versione installata, sovrapposizioni coi timer esistenti (evitare doppio scrub/snapshot), provisioning dei task via Ansible.

## SSH, GPG e protezione dischi

**Agenti SSH/GPG su FreeBSD**
- Principio: agenti solo user-space, chiavi solo in `$HOME` (mai in `/etc`), core system standard minimale; dotfiles versionati con git+stow.
- ssh-agent in `.profile`/`.bashrc`: crea `~/.ssh/agent_env` (chmod 600) con `SSH_AUTH_SOCK`/`SSH_AGENT_PID`, lo ri-sourca a ogni login, riparte solo se l'agente non è più vivo; `ssh-add` di `~/.ssh/id_rsa` e `~/.ssh/id_ed25519`. Senza quelle variabili esportate la shell non comunica con l'agente.
- gpg-agent: `~/.gnupg/gpg-agent.conf` (`pinentry-program /usr/local/bin/pinentry-curses`, default-cache-ttl 600, max-cache-ttl 7200), avvio user-space `gpg-agent --daemon --enable-ssh-support`; firma git con `user.signingkey` + `commit.gpgsign true`.

**Blocco scrittura dischi esterni (Windows)**
- GPO (Pro/Enterprise): gpedit → Sistema → Accesso all'archiviazione rimovibile → "Dischi rimovibili: nega accesso in scrittura"; oppure registro: `reg add HKLM\SYSTEM\CurrentControlSet\Control\StorageDevicePolicies /v WriteProtect /t REG_DWORD /d 1 /f` (0 per rimuovere).
- Varianti aziendali: GPO di dominio con eccezioni per gruppo, Intune/Defender Device Control (whitelist VID/PID/seriale), consentire la scrittura solo su USB cifrate BitLocker To Go.
- Verifiche: `gpresult /h report.html`, `reg query`/`Get-ItemProperty` su StorageDevicePolicies, test di scrittura su chiavetta, `dsregcmd /status` per dominio/Entra.

**Dual boot con BitLocker (ThinkPad P1 Gen 7, 2 TB, Windows 11 Enterprise, dominio IBM)**
- Fattibile senza reinstallare né disattivare: backup dati → salvare la Recovery Key (`manage-bde -protectors -get C:\`) → sospendere BitLocker prima del partizionamento (`manage-bde -protectors -disable C:\`) → ridurre C: da Gestione Disco → installare Fedora nello spazio libero usando la stessa ESP (non toccare ESP/MSR/recovery) → riattivare (`-enable`); possibile richiesta della Recovery Key al primo avvio; Fedora supporta Secure Boot nativamente.
- Su macchina gestita (Intune/Entra ID/EDR): prima chiedere all'IT — cambiare bootloader può generare alert SOC o violare policy; alternative: WSL2, VM Fedora (VMware/VirtualBox/Hyper-V), secondo SSD NVMe (SSD1 Windows, SSD2 Fedora) se il modello ha due slot.
- Sul portale IBM esistono istruzioni ufficiali per installare Fedora: leggerle per capire lo scenario previsto (dual boot, immagine Fedora gestita o dispositivo "Linux-managed").

## DNS e rete locale

**AdGuard Home + FRITZ!Box**
- Spostato il DNS dal FRITZ!Box a AdGuard → persa la risoluzione hostname↔IP dei client DHCP: aggiungere upstream condizionali `[/fritz.box/]192.168.178.1` e `[//]192.168.178.1` (nomi non qualificati), accanto agli upstream normali (es. DoH Cloudflare/Quad9); in Private reverse DNS mettere `192.168.178.1`.
- Architettura scelta: DHCP resta sul FRITZ!Box, AdGuard solo DNS/filter; il FRITZ rimane autoritativo per la LAN; verifica: `dig @192.168.178.1 host.fritz.box` e `dig @IP_ADGUARD host.fritz.box` devono coincidere.
- `localhost` non dipende dal DNS: risolto da `/etc/hosts` prima del DNS; `dig` interroga direttamente il DNS, mentre `getent`/`ping`/`curl` passano dal resolver NSS (`nsswitch.conf` deve avere `files`); confrontare `curl http://127.0.0.1:porta` vs `http://localhost:porta` per distinguere problema di servizio da problema di risoluzione.
- Verifica servizio locale: `ss -ltnp` (porta in ascolto su 127.0.0.1 vs 0.0.0.0), `nc -vz 127.0.0.1 8080`, `systemctl status`/`journalctl -u`.

## Thread aperti

- Modificare il job Borg per leggere da uno snapshot ZFS (valutando il riuso degli snapshot ricorsivi esistenti) invece del dataset live.
- Test di ripristino Borg da ambiente pulito con recovery key offline + passphrase del password manager; test di recovery indipendente anche per il livello USB.
- Esito della verifica Codex (read-only su Atlas): versione/integrazione Scheduler↔Alerts 45Drives, sovrapposizioni coi timer systemd esistenti, provisioning via Ansible → poi migrazione selettiva dei task.
- Verificare dove viene salvato l'export della Borg recovery key (fuori da Atlas) e come la passphrase passa dal Vault a Borg (file 0600 / BORG_PASSCOMMAND).
- Prometheus come controllore esterno di Atlas e futuro "backup pull da Prometheus verso Atlas".
- Workstation IBM: interpretare le istruzioni del portale per scegliere tra dual boot, WSL2, VM o secondo SSD.

## Fonti
| Data | Conversazione | Transcript |
| --- | --- | --- |
| 2025-12-05 | Convertire VMDK in QCOW2 | [2025-12-05-convertire-vmdk-in-qcow2.md](transcripts/2025-12-05-convertire-vmdk-in-qcow2.md) |
| 2025-12-05 | Come posso ottimizzare la risoluzione di una macchina virtuale su KVM/Qemu | [2025-12-05-come-posso-ottimizzare-la-risoluzione-di-una-macchina-virtua.md](transcripts/2025-12-05-come-posso-ottimizzare-la-risoluzione-di-una-macchina-virtua.md) |
| 2025-12-18 | Audio remoto con RDP | [2025-12-18-audio-remoto-con-rdp.md](transcripts/2025-12-18-audio-remoto-con-rdp.md) |
| 2026-01-28 | Configurazione SSH e GPG | [2026-01-28-configurazione-ssh-e-gpg.md](transcripts/2026-01-28-configurazione-ssh-e-gpg.md) |
| 2026-06-02 | Blocco scrittura dischi esterni | [2026-06-02-blocco-scrittura-dischi-esterni.md](transcripts/2026-06-02-blocco-scrittura-dischi-esterni.md) |
| 2026-06-18 | Dual boot con BitLocker | [2026-06-18-dual-boot-con-bitlocker.md](transcripts/2026-06-18-dual-boot-con-bitlocker.md) |
| 2026-09-05 | Risoluzione Nomi Locali AdGuard | [2026-09-05-risoluzione-nomi-locali-adguard.md](transcripts/2026-09-05-risoluzione-nomi-locali-adguard.md) |
| 2026-09-18 | Spiegare passphrase Borg | [2026-09-18-spiegare-passphrase-borg.md](transcripts/2026-09-18-spiegare-passphrase-borg.md) |
| 2026-09-18 | Test di ripristino indipendenti | [2026-09-18-test-di-ripristino-indipendenti.md](transcripts/2026-09-18-test-di-ripristino-indipendenti.md) |
| 2026-09-18 | Monitoraggio protezione dati | [2026-09-18-monitoraggio-protezione-dati.md](transcripts/2026-09-18-monitoraggio-protezione-dati.md) |
| 2026-09-21 | Valutare backup Borg | [2026-09-21-valutare-backup-borg.md](transcripts/2026-09-21-valutare-backup-borg.md) |
| 2026-09-23 | Backup USB offline | [2026-09-23-backup-usb-offline.md](transcripts/2026-09-23-backup-usb-offline.md) |
| 2026-09-24 | Monitoraggio E Alert Atlas | [2026-09-24-monitoraggio-e-alert-atlas.md](transcripts/2026-09-24-monitoraggio-e-alert-atlas.md) |



