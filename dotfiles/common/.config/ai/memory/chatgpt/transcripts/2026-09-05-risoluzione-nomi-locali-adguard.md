---
conversation_id: "6a9c77bc-3fe0-83ed-906d-19a089a7ac24"
title: "Risoluzione Nomi Locali AdGuard"
created: 2026-09-05
updated: 2026-09-05
model: "gpt-5-6-thinking"
messages: 6
---

# Risoluzione Nomi Locali AdGuard

## Utente — 2026-09-05 22:12

il router fritz mi risolveva i nomi hosts dei dispositivi collegati, ora che ho spostato il dns da quello del router ad adguard non avviene più la risoluzione.

## ChatGPT — 2026-09-05 22:12

Sì, è il comportamento atteso: prima il FRITZ!Box faceva sia da DNS sia da “rubrica” dei lease DHCP locali; spostando il DNS su AdGuard, AdGuard non conosce automaticamente quei nomi. La soluzione più pulita è far inoltrare **solo le query locali** al FRITZ!Box, lasciando tutto il resto ad AdGuard.

Esatto. Il FRITZ!Box conosce i dispositivi perché gestisce il DHCP e mantiene l'associazione **hostname ↔ IP**. AdGuard Home, diventando il DNS dei client, non conosce quella zona locale a meno che tu non gliela deleghi.

Se il FRITZ!Box è ancora il tuo **server DHCP**, io manterrei proprio questa architettura:

**Client → AdGuard Home → Internet DNS**  
                     ↘ **FRITZ!Box solo per i nomi locali**

In AdGuard Home vai in **Settings → DNS settings → Upstream DNS servers** e aggiungi, assumendo che il FRITZ!Box sia `192.168.178.1`:

```text
[/fritz.box/]192.168.178.1
```

AdGuard Home supporta esplicitamente gli upstream condizionali proprio per questo tipo di rete interna. citeturn359466search0turn359466search2

Quindi, per esempio:

```text
prometheus.fritz.box
nymph.fritz.box
ikaros.fritz.box
```

verranno chiesti al FRITZ!Box, mentre:

```text
google.com
github.com
openai.com
```

continueranno a passare dagli upstream normali di AdGuard.

### Se vuoi continuare a usare anche i nomi corti

Se prima facevi:

```bash
ssh prometheus
ping nymph
```

anziché:

```bash
ssh prometheus.fritz.box
```

normalmente il FRITZ!Box distribuisce tramite DHCP anche le informazioni necessarie perché il resolver possa cercare il nome locale. Ma per rendere AdGuard robusto anche rispetto alle query DNS **senza dominio**, puoi aggiungere:

```text
[//]192.168.178.1
```

In AdGuard Home `//` significa espressamente _unqualified names_, cioè nomi senza punti come `prometheus` o `printer`. citeturn359466search1

Io quindi metterei:

```text
[/fritz.box/]192.168.178.1
[//]192.168.178.1
```

oltre ai tuoi upstream Internet attuali.

### C'è poi il reverse DNS

Questo è un problema separato ma vale la pena sistemarlo. Se vuoi che anche AdGuard mostri:

```text
192.168.178.20 → prometheus
```

invece del solo IP, vai sempre in **DNS settings** e cerca **Private reverse DNS servers**.

Metti:

```text
192.168.178.1
```

e lascia abilitato **Use private reverse DNS resolvers** / risoluzione hostname dei client.

AdGuard Home usa proprio questi server per le query `PTR` degli indirizzi privati e per mostrare nomi leggibili dei client. citeturn359466search0turn359466search2

Quindi la configurazione che ti consiglierei è, grossomodo:

```text
Upstream DNS servers:

https://dns.cloudflare.com/dns-query
https://dns.quad9.net/dns-query

[/fritz.box/]192.168.178.1
[//]192.168.178.1
```

e:

```text
Private reverse DNS servers:

192.168.178.1
```

Naturalmente sostituisci `192.168.178.1` se hai cambiato l'IP del FRITZ!Box.

Puoi verificarlo molto facilmente:

```bash
dig @192.168.178.1 prometheus.fritz.box
```

prima, per vedere se **FRITZ** conosce il nome, e poi:

```bash
dig @IP_ADGUARD prometheus.fritz.box
```

Dopo la configurazione i due dovrebbero restituire lo stesso IP.

Questa secondo me è anche l'architettura migliore nel tuo caso: **lascerei il DHCP al FRITZ!Box** e userei AdGuard esclusivamente come DNS/filter. Non hai bisogno di replicare manualmente tutti gli hostname dentro AdGuard. Il FRITZ rimane autoritativo di fatto per la LAN e AdGuard gli passa soltanto le richieste che gli competono.

## Utente — 2026-09-05 22:29

ok ma non capisco perché non funziona più localhost

## ChatGPT — 2026-09-05 22:30

Ah, questo è diverso: **`localhost` non dovrebbe dipendere né dal FRITZ!Box né da AdGuard**.

Normalmente viene risolto localmente dal sistema tramite `/etc/hosts` — prima ancora di interrogare un DNS.

Su Linux dovresti avere almeno:

```text
127.0.0.1   localhost
::1         localhost
```

Controlla:

```bash
cat /etc/hosts
```

e poi prova:

```bash
getent hosts localhost
```

Dovresti ottenere qualcosa tipo:

```text
::1             localhost
```

oppure:

```text
127.0.0.1       localhost
```

### Se `dig localhost` invece non funziona

Quello può essere perfettamente normale.

`dig` **interroga direttamente il DNS** e non consulta `/etc/hosts`. Quindi:

```bash
dig localhost
```

potrebbe finire su AdGuard, mentre:

```bash
ping localhost
curl http://localhost:8080
getent hosts localhost
```

dovrebbero usare il resolver del sistema e trovare `/etc/hosts`.

Questa distinzione è importante:

```text
getent / ping / curl
        │
        ▼
   NSS resolver
   ├── /etc/hosts
   └── DNS → AdGuard
```

mentre:

```text
dig
 │
 ▼
DNS → AdGuard
```

### Se però anche `ping localhost` fallisce

Allora controllerei `/etc/nsswitch.conf`:

```bash
grep '^hosts:' /etc/nsswitch.conf
```

Su Fedora, per esempio, puoi avere qualcosa simile a:

```text
hosts:      files myhostname resolve [!UNAVAIL=return] dns
```

La cosa fondamentale è che ci sia almeno `files`, perché è quello che fa consultare `/etc/hosts`.

Puoi fare questo test rapido:

```bash
getent hosts localhost
ping -c1 localhost
curl -v http://localhost
```

Se mi incolli l'output di:

```bash
cat /etc/hosts
grep '^hosts:' /etc/nsswitch.conf
getent hosts localhost
```

ti dico subito dove si è rotto.

## Utente — 2026-09-05 22:34

come posso verificare che un servizio su localhost funziona?

## ChatGPT — 2026-09-05 22:34

Dipende dal tipo di servizio, ma su Linux farei questi controlli, in quest’ordine:

1. Verifica che qualcosa stia ascoltando sulla porta:

```bash
ss -ltnp
```

oppure, per una porta specifica, ad esempio `8080`:

```bash
ss -ltnp | grep ':8080'
```

Se vedi qualcosa come:

```text
LISTEN 0 4096 127.0.0.1:8080 ...
```

il servizio è in ascolto **solo in locale**.

Se invece vedi:

```text
LISTEN 0 4096 0.0.0.0:8080 ...
```

sta ascoltando su tutte le interfacce IPv4.

2. Se è HTTP/HTTPS, prova direttamente:

```bash
curl -v http://localhost:8080
```

oppure:

```bash
curl -v http://127.0.0.1:8080
```

Questa seconda prova è utile perché elimina del tutto il problema della risoluzione di `localhost`.

3. Per un servizio TCP generico:

```bash
nc -vz 127.0.0.1 8080
```

Se funziona:

```text
Connection to 127.0.0.1 8080 port [tcp/*] succeeded!
```

4. Se è un servizio gestito da systemd:

```bash
systemctl status nome-servizio
```

e, se serve:

```bash
journalctl -u nome-servizio
```

Nel tuo caso farei soprattutto questo confronto:

```bash
curl http://127.0.0.1:PORTA
curl http://localhost:PORTA
```

Se **il primo funziona e il secondo no**, allora il servizio sta bene e hai davvero un problema di risoluzione di `localhost`.

Se **non funziona nessuno dei due**, il problema è il servizio/porta, non DNS.
