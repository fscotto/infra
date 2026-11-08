---
conversation_id: "6a1e6bf8-1b8c-8390-9833-994f3db7d912"
title: "Blocco scrittura dischi esterni"
created: 2026-06-02
updated: 2026-06-02
model: "gpt-5-5"
messages: 4
---

# Blocco scrittura dischi esterni

## Utente — 2026-06-02 07:37

È possibile mettere un blocco su Windows per non permettere la scrittura su dischi esterni?

## ChatGPT — 2026-06-02 07:37

Sì, è possibile. Windows offre diversi livelli di blocco della scrittura verso dispositivi USB e dischi esterni.

### Metodo 1: Criteri di gruppo (Windows Pro/Enterprise)
Il metodo più pulito in ambiente aziendale.

1. Apri `gpedit.msc`
2. Vai a:
   ```
   Configurazione Computer
   └─ Modelli Amministrativi
      └─ Sistema
         └─ Accesso all'archiviazione rimovibile
   ```
3. Abilita:
   - **Dischi rimovibili: nega accesso in scrittura**

Da quel momento le chiavette USB e i dischi esterni saranno leggibili ma non scrivibili.

---

### Metodo 2: Registro di sistema
Funziona anche senza Group Policy.

Apri PowerShell o Prompt come amministratore:

```cmd
reg add HKLM\SYSTEM\CurrentControlSet\Control\StorageDevicePolicies ^
/v WriteProtect /t REG_DWORD /d 1 /f
```

Riavvia il sistema.

Per rimuovere il blocco:

```cmd
reg add HKLM\SYSTEM\CurrentControlSet\Control\StorageDevicePolicies ^
/v WriteProtect /t REG_DWORD /d 0 /f
```

---

### Metodo 3: Solo dispositivi autorizzati
In ambiente aziendale puoi usare:
- entity["company","Microsoft Intune","Endpoint management platform"]
- entity["software","Microsoft Defender for Endpoint","Device Control"]

per consentire la scrittura solo a dispositivi USB specifici (basandoti su seriale, VID/PID, certificati, ecc.).

---

### Metodo 4: BitLocker To Go
Se l'obiettivo è evitare la copia di dati aziendali su dispositivi non autorizzati:

- Consentire la scrittura **solo su unità USB cifrate BitLocker**.
- Bloccare tutte le altre.

È una configurazione comune nelle aziende.

---

### Se sei in dominio Active Directory
La soluzione migliore è una GPO applicata agli utenti o ai computer:

- Lettura consentita
- Scrittura negata
- Eccezioni per gruppi specifici (IT, amministratori, ecc.)

In questo modo l'utente non può aggirare il blocco semplicemente modificando il registro.

Se mi dici se si tratta di:
- PC personale,
- PC aziendale in dominio Active Directory,
- oppure gestione tramite Intune,

posso indicarti la soluzione più adatta.

## Utente — 2026-06-02 07:38

Come posso verificare se una di queste opzioni è attiva?

## ChatGPT — 2026-06-02 07:38

Puoi verificare in diversi modi, a seconda del tipo di blocco che sospetti sia stato configurato.

### 1. Controllare i Criteri di Gruppo

Apri un prompt dei comandi e genera un report:

```cmd
gpresult /h report.html
```

Apri il file `report.html` e cerca:

```
Accesso all'archiviazione rimovibile
```

oppure

```
Removable Storage Access
```

Se trovi criteri come **"Dischi rimovibili: nega accesso in scrittura"** abilitati, hai individuato il blocco.

---

### 2. Controllare il Registro di Sistema

Apri PowerShell:

```powershell
Get-ItemProperty `
  -Path "HKLM:\SYSTEM\CurrentControlSet\Control\StorageDevicePolicies" `
  -Name WriteProtect
```

Se ottieni:

```text
WriteProtect : 1
```

la protezione in scrittura è attiva.

Se la chiave non esiste o vale `0`, quel meccanismo non è attivo.

Puoi anche usare:

```cmd
reg query HKLM\SYSTEM\CurrentControlSet\Control\StorageDevicePolicies
```

---

### 3. Verificare con una chiavetta USB

Il test più diretto:

1. Inserisci una chiavetta USB.
2. Crea un file:

```powershell
echo test > E:\test.txt
```

(sostituendo `E:` con la lettera corretta)

Se compare un messaggio tipo:

```text
The disk is write protected
```

o

```text
Access denied
```

allora c'è effettivamente un blocco.

---

### 4. Verificare se il PC è gestito dall'azienda

Apri:

```cmd
dsregcmd /status
```

e cerca:

```text
AzureAdJoined : YES
DomainJoined  : YES
```

Se uno dei due è `YES`, il PC potrebbe ricevere policy da dominio o da urlMicrosoft Intunehttps://intune.microsoft.com.

Puoi anche controllare in:

**Impostazioni → Account → Accesso lavoro o scuola**

se è presente un account aziendale.

---

### 5. Verificare Device Control di Defender

Apri PowerShell come amministratore:

```powershell
Get-MpComputerStatus
```

oppure verifica la presenza di eventi in:

```text
Visualizzatore eventi
└─ Applications and Services Logs
   └─ Microsoft
      └─ Windows
         └─ DeviceManagement
```

Se è in uso il controllo dispositivi avanzato, spesso gli eventi vengono registrati lì o tramite policy di sicurezza aziendali.

---

Se il tuo obiettivo è capire **perché non riesci a scrivere su una specifica chiavetta o disco USB**, dimmi:
- versione di Windows (10/11),
- PC personale o aziendale,
- messaggio di errore esatto che ricevi,

e posso aiutarti a identificare con precisione quale meccanismo sta bloccando la scrittura.
