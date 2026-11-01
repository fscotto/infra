# Preset offline `ai-media`

Tutti i preset video accettano un nome MP4 locale oppure un URL HTTP(S).
I file locali vanno in `~/.local/share/ai-media/input/`. I preset avviano un servizio
`systemd --user` e tornano subito; FaceFusion e RVC restano nei container
offline. Il terminale stampa il nome del job e il comando per seguirne i log.

```bash
# 1. Estrae l'audio, separa voce/strumentale, converte tutta la traccia
# vocale con mia_voce e restituisce solo l'audio finale mixato.
ai-media preset audio-convert video1.mp4

# 2. Applica source11.jpg ... source18.jpg al video: conserva l'audio
# originale se presente, altrimenti produce un video senza audio.
ai-media preset video-convert video1.mp4

# 3. Unisce un video in input/ con un audio presente in input/ oppure output/.
ai-media preset merge video1.mp4 audio.wav

# 4. Esegue voce e volti, poi unisce il video modificato con l'audio convertito.
# Se l'input è un URL, scarica prima un singolo video con yt-dlp.
ai-media preset convert 'https://esempio.org/video'

# 5. Separa il video (senza ricodificarlo) dalla prima traccia audio.
ai-media preset split video1.mp4

# 6. Come split, poi separa l'audio in voce e strumentale, senza convertirne la voce.
ai-media preset split-stems video1.mp4

# 7. Sovrappone voce e strumentale in un unico audio (non concatena le tracce).
ai-media preset mix vocals.wav instrumental.wav

# 8. Applica mia_voce direttamente a un audio, senza separazione né remix.
ai-media preset voice-convert voce.wav
```

## Applicare mia_voce a un audio

```bash
ai-media preset voice-convert voce.wav
ai-media preset voice-convert video1-split-stems/vocals.wav --output video1-mia_voce.wav
```

`voice-convert` legge un audio locale in `input/` oppure `output/`, anche in
una sottocartella, e produce `output/<nome-audio>-mia_voce.wav`. `--output`
permette di scegliere un altro nome WAV. Converte prima la traccia in WAV e
applica direttamente il modello RVC `mia_voce` con il relativo indice e RMVPE,
senza BS Roformer e senza aggiungere lo strumentale. Usare preferibilmente
una voce isolata: il preset non rimuove musica né separa parlanti.
Accetta i formati audio decodificabili dal FFmpeg installato. Richiede il
modello e l'indice personali già presenti nello stato RVC, funziona offline
in background, conserva l'originale e rifiuta risultati già esistenti.
Gli intermedi restano nella sottocartella nascosta del job in `output/`.

Per rimettere lo strumentale dopo la conversione:

```bash
ai-media preset mix video1-mia_voce.wav video1-split-stems/instrumental.wav --output video1-mix.wav
```

## Unire voce e strumentale

`mix` usa due audio locali in `input/` o `output/`, anche nelle sottocartelle
create da `split-stems`:

```bash
ai-media preset mix video1-split-stems/vocals.wav video1-split-stems/instrumental.wav --output video1-mix.wav
```

Il risultato è `output/video1-mix.wav`, PCM WAV a 16 bit. Senza `--output`,
il nome è `<nome-vocale>-mix.wav` (per esempio `vocals-mix.wav`). Le tracce
partono insieme da zero e vengono sommate a volume originale, senza
normalizzazione; la durata è quella della traccia più lunga. Livelli troppo
alti possono causare clipping. Il preset non esegue separazione o conversione
vocale, non modifica gli originali e non sovrascrive file esistenti. Parte in
background come gli altri preset e usa solo FFmpeg nel container offline.
Gli audio devono essere univoci tra `input/` e `output/`; percorsi assoluti,
`..`, link simbolici e URL audio non sono accettati.

## Video da URL

Per ogni preset video si può sostituire il nome del video con un URL tra virgolette:

```bash
ai-media preset split 'https://esempio.org/video'
ai-media preset split-stems 'https://esempio.org/video'
ai-media preset audio-convert 'https://esempio.org/video'
ai-media preset video-convert 'https://esempio.org/video'
ai-media preset merge 'https://esempio.org/video' audio.wav
ai-media preset convert 'https://esempio.org/video'
# Anche convert accetta un file locale, senza download:
ai-media preset convert video1.mp4
```

Il download con `yt-dlp` avviene una sola volta nello stesso job in background,
prima dell'elaborazione. Il video scaricato resta in `input/download-<ID>.mp4`;
i risultati usano lo stesso prefisso `download-<ID>` al posto di `video1`.
Serve `yt-dlp` sull'host solo per gli URL. L'audio di `merge` rimane un file
locale in `input/` oppure `output/`. URL locali/privati o contenenti credenziali
non vengono accettati. Se il download fallisce, l'elaborazione non parte.

`split` produce `output/video1-split/video.mp4` (muto) e `audio.wav`.
`split-stems` produce `output/video1-split-stems/` con `video.mp4`, `audio.wav`,
`vocals.wav` e `instrumental.wav`. L'audio estratto è PCM WAV a 16 bit;
la separazione usa BS Roformer offline nel container RVC e non richiede
il modello personale `mia_voce`. Entrambi richiedono un video con audio,
non modificano l'originale e rifiutano una cartella risultato già esistente.
Mantengono gli intermedi nella sottocartella nascosta del job in `output/`;
i risultati pubblicati sono hard link e non duplicano lo spazio dei file.

`video-convert` e il passaggio video di `convert` usano lo stesso profilo
FaceFusion: HyperSwap 1a 256 (pixel boost 256x256, peso 0.5), rilevatore
`yolo_face` 640x640 agli angoli 0/90/180/270, selezione `one` per volto
grande, filtri `female` e `white`, maschere `occlusion region area box` con
`xseg_1` e `bisenet_resnet_34` (blur 0.3), H.264 `libx264` veryfast, qualità
80 e 30 fps. L'audio originale viene ripristinato separatamente quando esiste.

Risultati: `output/video1-mia_voce.wav`, `output/video1-facefusion.mp4` e
`output/video1-unito.mp4`. Il preset `convert` crea
`output/video1-completo.mp4` (o `output/download-<ID>-completo.mp4` da URL),
mantenendo anche l'audio e il video intermedi. Richiede `source11.jpg`–`source18.jpg`
in `input/` e un video che contenga audio. **Solo il download** tramite
`yt-dlp` usa la rete; non usa la configurazione o i cookie personali di
`yt-dlp` e non scarica playlist. I file esistenti non vengono sovrascritti. Il
primo e il secondo preset conservano i passaggi intermedi in una sottocartella
`.video1-...` di `output/`, utile per diagnosi e recupero; non viene rimossa
automaticamente.

Per controllare un job, usare il nome stampato dal comando:

```bash
journalctl --user -fu ai-media-preset-YYYYMMDD-HHMMSS-ID
systemctl --user status ai-media-preset-YYYYMMDD-HHMMSS-ID
```

Il preset `audio-convert` converte l'intero stem vocale: non distingue automaticamente
voci maschili e femminili e non separa parlanti sovrapposti. L'elaborazione è
in background, **non** più rapida della capacità della CPU. I nomi dei video locali
devono essere semplici, senza percorsi; gli audio possono indicare sottocartelle
relative a `input/` o `output/`. Se lo stesso audio
è in `input/` e `output/`, il comando rifiuta l'ambiguità. Tutti i video di
input dei preset devono essere MP4 con un nome diverso dal risultato atteso.
