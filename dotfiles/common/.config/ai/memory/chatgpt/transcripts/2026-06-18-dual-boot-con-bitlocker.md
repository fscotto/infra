---
conversation_id: "6a342e8f-c59c-83eb-9d0f-82d5dc067a98"
title: "Dual boot con BitLocker"
created: 2026-06-18
updated: 2026-06-18
model: "gpt-5-5"
messages: 8
---

# Dual boot con BitLocker

## Utente — 2026-06-18 19:46

Ho un computer con installato Windows 11 Enterprise Edition, il disco è cifrato con Bitlocker, vorrei fare il dual boot del pc, senza reinstallare Windows o disattivare Bitlocker, con Fedora Linux.
Posso farlo?

## ChatGPT — 2026-06-18 19:46

Sì, è possibile fare dual boot tra Windows 11 Enterprise e Fedora mantenendo **BitLocker attivo**, ma ci sono alcune precauzioni importanti.

## Come funziona

BitLocker cifra la partizione Windows (tipicamente C:). Fedora non ha bisogno di accedere a quella partizione per avviarsi, quindi può convivere con BitLocker senza problemi.

Lo scenario corretto è:

- Windows rimane cifrato con BitLocker.
- Riduci la partizione Windows da Windows stesso.
- Installi Fedora nello spazio libero.
- Fedora usa la stessa partizione EFI già presente.
- Il boot viene gestito tramite UEFI.

## Prima di iniziare

### 1. Verifica il tipo di cifratura

Da Windows apri PowerShell come amministratore:

```powershell
manage-bde -status
```

Controlla che:

- BitLocker sia attivo.
- Il disco sia GPT.
- Il sistema avvii in modalità UEFI.

### 2. Salva la Recovery Key

È fondamentale.

Puoi esportarla con:

```powershell
manage-bde -protectors -get C:
```

Oppure verificarne la presenza nel portale aziendale, in Active Directory o in Microsoft Entra ID, a seconda di come è gestito il PC.

## La parte delicata: sospendere BitLocker

Non è necessario disattivarlo completamente.

Prima di modificare le partizioni:

```powershell
manage-bde -protectors -disable C:
```

oppure da GUI:

**Pannello di controllo → Crittografia unità BitLocker → Sospendi protezione**

Questo evita che BitLocker interpreti le modifiche al boot come un attacco.

Dopo l'installazione di Fedora lo riattivi:

```powershell
manage-bde -protectors -enable C:
```

## Installazione Fedora

1. Da Windows apri Gestione Disco.
2. Riduci la partizione C: lasciando spazio non allocato.
3. Avvia la live di Fedora.
4. Scegli installazione personalizzata.
5. Usa lo spazio libero per:
   - `/`
   - eventualmente `/home`
   - swap (oppure zram, che Fedora usa già).

**Non toccare:**
- EFI System Partition
- Microsoft Reserved Partition
- Partizioni di recovery Windows

Fedora installerà i propri file EFI accanto a quelli di Windows.

## Possibili problemi

### Secure Boot

Fedora supporta Secure Boot nativamente.

Di norma non devi disabilitarlo.

### BitLocker Recovery all'avvio

Può capitare che al primo riavvio BitLocker chieda la Recovery Key.

È normale se rileva modifiche al bootloader.

Per questo conviene avere la chiave a portata di mano.

### PC aziendale

Qui bisogna fare attenzione.

Se il PC è gestito tramite:
- entity["software","Microsoft Intune","Microsoft endpoint management platform"]
- entity["company","Microsoft","Technology company"] Active Directory
- sistemi EDR aziendali

potrebbero esserci policy che:
- impediscono il dual boot;
- richiedono Secure Boot con configurazioni specifiche;
- segnalano modifiche al boot manager.

In questo caso il problema non è BitLocker ma le policy aziendali.

## Quello che farei io

1. Backup dei dati importanti.
2. Recupero e verifica della Recovery Key.
3. Sospensione temporanea di BitLocker.
4. Riduzione della partizione da Windows.
5. Installazione di Fedora nello spazio libero.
6. Riattivazione di BitLocker.
7. Verifica che Windows e Fedora si avviino correttamente.

Se mi dici:
- modello del PC (ThinkPad T480, Dell, HP, ecc.),
- dimensione del disco,
- se è un PC aziendale o personale,
- e l'output di `manage-bde -status`,

posso indicarti esattamente come partizionarlo senza rischiare di compromettere l'installazione Windows esistente.

## Utente — 2026-06-18 19:50

Thinkpad P1 gen7
2TB
Aziendale (sotto dominio IBM)

## ChatGPT — 2026-06-18 19:50

Essendo un **ThinkPad P1 Gen 7 aziendale sotto dominio IBM**, la questione principale non è tecnica ma di **compliance aziendale**.

Dal punto di vista tecnico, Fedora può convivere con BitLocker senza problemi. Il P1 Gen 7 usa UEFI moderno, TPM 2.0 e Secure Boot, quindi il dual boot è perfettamente supportato.

Il rischio è che IBM abbia applicato policy tramite:
- entity["software","Microsoft Intune","Microsoft endpoint management platform"]
- entity["software","Microsoft Entra ID","Cloud identity platform"] (ex Azure AD)
- entity["company","IBM","Technology company"] Endpoint Management
- software EDR/XDR aziendali

che possono considerare una modifica del bootloader o della configurazione disco come un evento di sicurezza.

## Prima cosa da verificare

Apri PowerShell come amministratore:

```powershell
dsregcmd /status
```

e controlla:

- AzureAdJoined / EntraJoined
- DomainJoined

Poi:

```powershell
manage-bde -status
```

e:

```powershell
Get-Tpm
```

Infine:

```powershell
systeminfo
```

per verificare Secure Boot e modalità UEFI.

## Lo scenario migliore

Se hai:
- privilegi amministrativi locali;
- accesso alla Recovery Key di BitLocker;
- nessuna policy che vieta il dual boot;

allora la procedura è abbastanza standard:

1. Backup dati.
2. Sospensione temporanea di BitLocker.
3. Riduzione della partizione Windows.
4. Installazione Fedora nello spazio libero.
5. Riattivazione BitLocker.
6. Eventuale reinserimento della Recovery Key al primo boot.

## Lo scenario che mi preoccuperebbe

Molte aziende, IBM compresa, distribuiscono notebook con:
- Secure Boot obbligatorio;
- BitLocker legato al TPM;
- controlli di integrità del boot;
- agent EDR che monitorano il sistema.

In questi casi il dual boot può:
- far scattare una richiesta di Recovery Key;
- generare alert al SOC aziendale;
- violare le policy interne.

Anche se tecnicamente funziona.

## Quello che farei personalmente sul tuo caso

Dato che:
- è un notebook aziendale;
- ha un SSD da 2 TB;
- è sotto dominio IBM;

eviterei il dual boot e valuterei una delle seguenti opzioni:

### Opzione 1 — WSL2

Per sviluppo Linux è probabilmente la più compatibile con le policy aziendali.

### Opzione 2 — Fedora in VM

Con:
- entity["software","VMware Workstation","Desktop virtualization software"]
- entity["software","VirtualBox","Desktop virtualization software"]
- entity["software","Hyper-V","Microsoft hypervisor"]

Su un P1 Gen 7 hai più che abbastanza CPU e RAM per lavorare comodamente.

### Opzione 3 — Secondo SSD

Se il P1 Gen 7 che hai monta due slot NVMe (molte configurazioni del P1 Gen 7 li supportano), la soluzione più pulita è:

- SSD 1 → Windows aziendale con BitLocker.
- SSD 2 → Fedora.

Senza toccare la partizione Windows.

È la soluzione che consiglierei a un sistemista che vuole evitare problemi con l'IT aziendale.

Se vuoi, posso aiutarti a verificare se la tua specifica configurazione del P1 Gen 7 ha effettivamente il secondo slot NVMe disponibile e come controllarlo senza aprire il portatile.

## Utente — 2026-06-18 19:51

Chiedo all’assistenza IT aziendale faccio prima

## ChatGPT — 2026-06-18 19:51

Sì, nel tuo caso è probabilmente la strada più semplice e sicura.

Su un PC personale ti direi tranquillamente "procedi, fai attenzione a BitLocker e sei a posto". Su un notebook aziendale IBM, invece, ci sono vari aspetti che solo l'IT può confermare:

- se il dual boot è consentito dalle policy aziendali;
- se il bootloader può essere modificato senza generare alert di sicurezza;
- se BitLocker è gestito centralmente;
- se sono presenti controlli EDR/XDR che potrebbero segnalare la modifica;
- se esistono procedure ufficiali per installare Linux.

Tra l'altro molte grandi aziende hanno già una posizione chiara: alcune vietano il dual boot, altre lo consentono, altre ancora forniscono direttamente workstation Linux o immagini approvate.

Potresti scrivere qualcosa di molto semplice:

> Ho un ThinkPad P1 Gen 7 aziendale con Windows 11 Enterprise e BitLocker. Vorrei sapere se è consentita l'installazione di Fedora Linux in dual boot mantenendo l'installazione Windows esistente. Ci sono policy o procedure aziendali da seguire?

In pochi minuti avrai una risposta definitiva e, soprattutto, eviterai di ritrovarti con un ticket di sicurezza aperto perché il SOC ha visto cambiare la configurazione di boot del portatile.

Considerando che usi già Linux a casa e che per il lavoro hai spesso parlato di ambienti Windows + WSL2, non mi stupirei se IBM preferisse indirizzarti verso WSL2 o una VM Fedora piuttosto che un dual boot vero e proprio. Però vale la pena chiedere: alcune divisioni IBM sono storicamente molto aperte all'uso di Linux.

## Utente — 2026-06-18 19:52

Sul portale aziendale sono presenti le istruzioni per installare Fedora

## ChatGPT — 2026-06-18 19:52

Allora la situazione cambia parecchio.

Se sul portale aziendale IBM sono presenti **istruzioni ufficiali per installare Fedora**, è un ottimo segnale: significa che l'azienda supporta almeno in parte l'utilizzo di Linux sui dispositivi aziendali.

A questo punto ti consiglierei comunque di leggere attentamente la documentazione per capire **quale scenario è previsto**:

- installazione Fedora come sistema operativo unico;
- dual boot Windows + Fedora;
- reinstallazione completa con immagine aziendale Fedora;
- Fedora su hardware certificato;
- requisiti specifici per Secure Boot, TPM e cifratura.

Molte aziende che supportano Linux non raccomandano il dual boot, ma forniscono direttamente una build Fedora con:
- agent di sicurezza aziendali;
- VPN;
- certificati;
- strumenti di gestione endpoint.

Se la documentazione parla esplicitamente di **dual boot**, allora probabilmente esiste già una procedura validata per convivere con BitLocker e Windows.

Se invece parla di "conversione a Fedora" o "Linux-managed device", potrebbe essere previsto il passaggio completo a Fedora.

A questo punto farei così:

1. Apri la documentazione.
2. Cerca termini come:
   - Dual Boot
   - BitLocker
   - Secure Boot
   - TPM
   - Windows coexistence
   - Existing Windows installation
3. Verifica se viene richiesto di sospendere BitLocker o recuperare la Recovery Key.

Se vuoi, puoi incollarmi il testo (o gli screenshot) delle istruzioni IBM e ti aiuto a capire esattamente quale modello di installazione stanno proponendo e quali rischi ci sono per il tuo P1 Gen 7.
