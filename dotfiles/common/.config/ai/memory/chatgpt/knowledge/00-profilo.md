# Profilo — contesto stabile dell'utente

> Primo file da consultare quando serve una conoscenza di fondo su chi è
> l'utente, il suo ambiente e le sue preferenze. Derivato dall'insieme
> delle 74 conversazioni ChatGPT (giugno 2025 – ottobre 2026); i dettagli
> sono nei file tematici in `knowledge/` e nei `transcripts/`.
> Generato da scripts/chatgpt_export_to_memory.py + distillazione AI, 2026-11-08.

## Percorso e obiettivi
- Fabio Scotto di Santolo; percorso principale: system programming in C
  su UNIX/Linux (APUE 3ª ed. di Stevens/Rago + Silberschatz per la teoria).
- Studio parallelo dello sviluppo kernel Linux (Linux Kernel Development
  di Love); test di deepening su xv6.
- Progetto applicativo principale del periodo: fsnap, strumento in C per
  gli esercizi dei capitoli 1-5 di APUE (vedi system-programming.md).

## Ambiente (interamente gestito dal playbook AnsiblePlaybook)
- ikaros: desktop personale Fedora GNOME (host principale).
- nymph: laptop Fedora GNOME.
- deadalus: workstation Windows + Fedora WSL.
- prometheus: server Rocky Linux 9.
- atlas: NAS Rocky 9 con ZFS (dataset `archive` SMB e servizi separati).
- aegis: nodo always-on Fedora IoT su Raspberry Pi 4.
- Dotfiles layered e riproducibili: "If it cannot be rebuilt, it is not owned."
  (dettagli in os-unix.md e dotfiles-wm.md).

## Posizioni stabili (confermate su più conversazioni)
- Filosofia: UNIX philosophy, minimalismo, riproducibilità, controllo
  esplicito (preferisce configurazioni che capisce e ricostruisce).
- Vim è l'editor primario di sviluppo; Emacs è l'ambiente di authoring
  (org-mode, appunti, documenti) con configurazione modulare deployata
  dal playbook (dettagli in editors.md ed emacs.md).
- Fedora è la distro stabile quotidiana; FreeBSD (su ThinkPad T480) e
  Void Linux sono studiati/valutati come strumenti di apprendimento UNIX,
  oltre a NixOS valutato senza adozione (dettagli in os-unix.md).
- Bash per lo scripting; Go secondario; Python di supporto (languages.md).
- Sperimenta dentro VM; dati protetti da una strategia multi-livello: snapshot ZFS,
  Borg criptato, USB offline con test di ripristino (tools-infra.md).

## Come usare questa memoria
- `INDEX.md` — indice datato di tutte le conversazioni con il topic.
- `knowledge/` — un file per argomento (decisions e stati finali).
- Ricerca full-text dei contenuti originali:

      rg -i "<keyword>" ~/.config/ai/memory/chatgpt/transcripts/
