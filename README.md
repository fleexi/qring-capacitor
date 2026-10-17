# capacitor-wristband

Plugin Capacitor 8 per le SDK QRing fornite: iOS 1.0.0 (20260920), Android 1.0.0.78. Contratto TypeScript unico per raccolta automatica, adattatori nativi, un dispositivo per volta.

## Installazione in OnActive

Richiede Capacitor 8, iOS 15+ e Swift Package Manager; Android minSdk 26, compileSdk 36 e Java 21. La prima app verificata come configurazione è `../../whesp/onactive-app` rispetto a questa directory. Il plugin non è stato installato automaticamente nell'app.

Dalla directory del plugin:

```sh
npm ci
npm run check
npm pack
```

Dalla directory `onactive-app`:

```sh
npm install ../../tyb-wirstband/capacitor-wristband/capacitor-wristband-0.3.7.tgz
npm run sync-dev
```

Usare `sync-demo` o `sync-prod` quando appropriato: questi script preservano APP_FLAVOUR. Non modificare il Package.swift generato dalla CLI. Il pacchetto SPM esporta il prodotto `CapacitorWristband`.

Il target SPM del plugin propaga `-ObjC` al linker dell'app: il flag è necessario per caricare le categorie Objective-C della SDK, inclusa `NSDateAdditions` usata nella lettura dello storico.

In `ios/App/App/Info.plist` aggiungere `NSBluetoothAlwaysUsageDescription` con una spiegazione adeguata all'app. L'esempio la include già. Il framework vendor consegnato contiene **solo iOS device arm64**: il simulatore non è supportato. Non è una XCFramework universale; non contiene una slice simulatore inventata.

Per Android usare `@capacitor/android` della stessa versione dell'app e impostare `minSdkVersion=26` in `android/variables.gradle`. I permessi BLE sono dichiarati dal plugin; Android 11 e precedenti richiedono anche il consenso alla posizione per la scansione. Il plugin non richiede la posizione su Android 12+. Il flag neverForLocation può filtrare alcuni beacon; nessun uso di localizzazione è implementato.

## Uso

```ts
import { Wristband } from 'capacitor-wristband';

// Scegliere il tipo reale: band, watch o ring. Il nome QRing della SDK non basta.
await Wristband.initialize({ deviceKind: 'band' });
await Wristband.requestPermissions();
const scan = await Wristband.addListener('scanResult', device => {
  console.log(device.deviceId, device.name, device.rssi);
});
await Wristband.startScan({ timeoutMs: 15_000 });
// Usare un deviceId ricevuto da scanResult; l'ID è opaco e specifico della piattaforma.
await Wristband.connect({ deviceId });
const capabilities = await Wristband.getCapabilities();
console.log(capabilities.metrics.heartRate);
const current = await Wristband.getMeasurementSettings({ metric: 'heartRate' });
await Wristband.setMeasurementSettings({
  metric: 'heartRate', patch: { enabled: true },
});
// Inviare intervalMinutes solo se il campo è writable e rispetta i vincoli rilevati.
const history = await Wristband.syncHistory({
  metrics: ['heartRate', 'bloodOxygen', 'hrv', 'stress', 'steps', 'sleep'],
  startDay: 0, days: 7,
});
// Controllare status e ogni batch: partial/failed contengono errori per giorno/metrica.
console.log(history.status, history.batches);
await scan.remove();
await Wristband.disconnect();
```

`deviceId` nell'esempio è una variabile dell'app, non un MAC hardcoded. Connettere un risultato soltanto dopo aver verificato che sia il dispositivo atteso. Entrambe le piattaforme scansionano le periferiche BLE disponibili; non tutte sono compatibili con il protocollo QRing.

## Flussi e impostazioni

Il plugin espone solo raccolta automatica: configurazione, lettura dello storico e sincronizzazione. I record hanno source=scheduled; SpO₂ usa i modelli dettagliati su iOS (solo sourceType=0), gli array giornalieri su Android. Non avvia misure su richiesta.

- `connect` risolve dopo registrazione SDK, sincronizzazione orario e feature discovery. Il link BLE da solo non equivale a ready.
- `disconnect` conserva il riferimento all'ultimo dispositivo. `reconnect` lo riutilizza; `forgetDevice` lo cancella. Nessuna riconnessione automatica infinita. `forgetDevice` non rimuove pairing del sistema.
- Una sola operazione SDK alla volta: le chiamate concorrenti restituiscono BUSY. Su iOS può comparire BUSY anche durante il completamento della disconnessione precedente.
- Impostazioni: cuore, SpO₂, HRV, stress. Read/modify/write/readBack preserva i campi non modificati. Nessuna scrittura batch implicita. Intervalli e abilitazioni hanno capabilities distinte.
- HRV espone il toggle, senza intervallo.
- Cuore/SpO₂/stress espongono intervalli solo dopo lettura riuscita. Minimo stress rilevato dal dispositivo; 255 è il limite conservativo di codifica adottato, non la garanzia che il firmware accetti ogni numero.
- Stato corrente solo dal dispositivo. Successo di una scrittura non significa che il parametro sia stato riletto: controllare `verification`. Se la rilettura fallisce dopo ACK, codice WRITE_VERIFICATION_FAILED con `writeAcknowledged: true`. In caso di timeout la connessione viene chiusa perché il flusso SDK potrebbe non essere più allineato.
- Android verifica i permessi prima di scansione/connessione e gestisce SecurityException nei punti di scansione e lettura nome durante l’inizializzazione: consenso mancante o revocato restituisce PERMISSION_DENIED.
- Background ferma la scansione. La raccolta automatica è eseguita dal dispositivo secondo le proprie impostazioni; la sincronizzazione richiede il collegamento all’app.

## Storia, eventi e unità

`startDay=0` è oggi. `startDay + days <= 7`, valori interi positivi per days. I giorni sono fissati all'avvio: dopo mezzanotte l'adattatore corregge l'indice relativo passato alla SDK; un giorno uscito dalla retention diventa un errore esplicito.

`historyBatch` e `syncProgress` consentono aggiornamenti incrementali; il risultato Promise contiene anche tutti i batch, inclusi quelli precedenti a un timeout. Non sommare due volte eventi e risultato: usare operationId e batchIndex. Il sync restituisce success/partial/failed; un giorno vuoto riuscito è diverso da un errore.

Cuore bpm, SpO₂ %, distanza metri, durate secondi. HRV e stress usano unità `vendor`: nessuna equivalenza clinica assunta. Le misure hanno lo stesso formato su iOS e Android, sia nelle Promise sia negli eventi `historyBatch`:

- Numeriche: `metric`, `date`, `source`, `value`, `unit`, `sampleIndex`. `intervalMinutes` è 30 per HRV e stress (cadenze fisse confermate per il bracciale integrato); per cuore e SpO₂ è incluso se restituito positivo dalla SDK. Gli zeri senza lettura vengono omessi senza spostare gli indici.
- Passi: `metric`, `date`, `source`, `steps`, `distanceMeters`, `intervalMinutes=15`, `sampleIndex` quando disponibile e campi temporali comuni. I campioni senza passi né distanza sono omessi.
- Sonno: `metric`, `date`, `source`, `nap`, `durationSeconds`, `phases`; ogni fase contiene `stage`, `durationSeconds` e `start`/`end` quando disponibili; anche il record può esporre `start`/`end` e i campi temporali comuni. Gli stati non riconosciuti rimangono `unknown`.

Per cuore, SpO₂, HRV e stress il plugin restituisce anche `timestamp` (Unix millisecondi), `utcOffsetMinutes` e `timestampSource: reconstructed` quando l'intervallo storico è positivo. HRV e stress usano sempre 30 minuti, anche se il modello SDK riporta un intervallo diverso o assente. Calcolo: mezzanotte locale del giorno richiesto + `sampleIndex × intervalMinutes` sulla griglia dell'orologio locale. Gli indici originali comprendono i buchi dei valori zero. Si usa il fuso locale del telefono durante la lettura, non un fuso storico registrato dal bracciale. Nei cambi di ora legale si sceglie la prima occorrenza di un orario ripetuto; per un orario inesistente o una posizione fuori dal giorno i campi temporali vengono omessi. I passi usano il tempo locale del modello iOS o timeIndex × 15 minuti su Android. Il sonno conserva inizio/fine anche nel giorno precedente: iOS interpreta realBeginTime/realEndTime (fallback happenDate/endTime) nel fuso locale, Android converte Unix secondi della SDK in millisecondi. La data è il giorno locale richiesto alla SDK; le date dei modelli giornalieri iOS vengono validate. Per SpO₂ iOS si usa `getBloodOxygenDataByDayIndex`: i modelli `QCBloodOxygenModel` forniscono direttamente la data e l’orario della misura (`timestampSource: sdk`). `sampleIndex` è la posizione originale nella risposta, non una griglia temporale; `intervalMinutes` è omesso perché questo metodo non fornisce una cadenza storica. Il valore è la media di minimo e massimo positivi, altrimenti soa2. Campioni manuali, valori non positivi/non finiti e date mancanti o esterne al giorno richiesto sono esclusi senza scartare gli altri campioni validi. Con debug attivo vengono registrate le date escluse, senza i valori delle misure. Il contenuto e il numero di campioni dipendono dalla SDK e dai dati registrati dal dispositivo. Energia omessa fino a verifica della conversione vendor.

Eventi: bluetoothStateChanged, scanResult, scanStopped, connectionStateChanged, historyBatch, syncProgress. Gli eventi storici hanno operationId.

Il web restituisce UNSUPPORTED; non simula un wristband. Definizioni complete in `src/definitions.ts`.

## Verifica e limiti

```sh
npm run check
npm run test:ios-policy
npm run example:build
```

Nell'esempio: `npx cap sync`, build device iOS senza firma e build Android debug/release. Le prove hardware richiedono un wristband compatibile: vedere `docs/device-validation.md`. Il successo delle build non prova il comportamento del firmware.

Il pacchetto usa binari vendor consegnati localmente. Prima della distribuzione pubblica verificare i termini di redistribuzione del fornitore; nessuna pubblicazione npm è stata eseguita.

## Migrazione alla 0.2.0

Rimossi startMeasurement, stopMeasurement, gli eventi measurementUpdated/measurementFinished e i tipi delle sessioni. MetricCapability espone solo history e settings; WristbandState non contiene sessionId. La temperatura era già stata rimossa nella 0.1.4. Le app devono rimuovere import, listener, controlli e pulsanti relativi a queste API. Restano getMeasurementSettings/setMeasurementSettings (configurazione automatica) e getHistory/syncHistory.


## Migrazione alla 0.3.0

Contratto delle misure ridotto ai campi comuni tra Android e iOS. Rimossi `id`, `timestamp`, `utcOffsetMinutes`, `timestampSource`, gli indici/intervalli dei passi, `energyKcal`, la durata dei passi, `startLocal`/`endLocal`, `start`/`end` e `vendorStage` delle fasi. Gli intervalli numerici sono esposti solo per cuore e SpO₂. Rimuovere nelle app la visualizzazione degli orari dei campioni; non ricostruirli da intervalli o impostazioni attuali. I metodi e gli eventi conservano il formato dei batch e degli errori.


## Migrazione alla 0.3.1

Ripristinati gli orari per cuore e SpO₂ su entrambe le piattaforme, calcolati direttamente dal plugin dagli indici e dall'intervallo della lettura storica. L'app visualizza `timestamp` senza eseguire calcoli. I campi temporali sono opzionali e presenti insieme; senza intervallo valido non vengono inventati. Rimane l'API giornaliera SpO₂ iOS introdotta nella 0.3.0.


## Migrazione alla 0.3.2

HRV e stress ora restituiscono intervalMinutes e i campi temporali ricostruiti su entrambe le piattaforme. Cadenze fisse indicate dall'integratore: HRV 30 minuti, stress 60 minuti. Prevalgono sugli intervalli del modello SDK e non modificano le impostazioni di misurazione del dispositivo. Il calcolo conserva gli indici originali e le regole locali/DST della 0.3.1.


## Migrazione alla 0.3.3

Correzione della cadenza confermata dall'integratore: anche stress usa 30 minuti. HRV e stress hanno entrambi intervalMinutes=30 su iOS e Android, con timestamp ricostruiti dagli indici originali. Questa indicazione sostituisce i 60 minuti documentati nella 0.3.2.


## Migrazione alla 0.3.4

Ripristinato il metodo SpO₂ iOS `getBloodOxygenDataByDayIndex:finished:`, già funzionante sul bracciale, al posto della variante WithInterval che non mostrava valori. Timestamp dalla SDK (`timestampSource: sdk`), senza inventare un intervallo. Date fuori dal giorno richiesto filtrate singolarmente, come nel percorso OnWell; non causano più il fallimento dell'intero batch. Formato comune delle misure mantenuto, con intervalMinutes opzionale. Android e le cadenze HRV/stress (30 minuti) invariati.


## Migrazione alla 0.3.5

Normalizzazione degli indici HRV Android: HRVRsp espande i valori su una griglia di 288 slot da 5 minuti (range/5), mentre il contratto del plugin usa 48 slot da 30 minuti. Il plugin converte la griglia prima di filtrare i valori zero e calcolare gli orari: indice SDK 144 → sampleIndex 24 → ore 12:00, come iOS. Gli slot vuoti restano vuoti; un valore positivo fuori dalla griglia da 30 minuti produce SDK_ERROR invece di essere scartato o spostato. Nessuna modifica alla SDK, ai valori o alle altre metriche.


## Migrazione alla 0.3.6

Ripristinati i tempi di passi e sonno. Passi: timestamp/utcOffsetMinutes/timestampSource, intervalMinutes=15 e sampleIndex (0–95) quando ricavabile. iOS usa happenDate del modello, Android la griglia da 15 minuti; dati temporali non validi restano assenti senza eliminare i valori del campione. Sonno: start/end in Unix millisecondi e timestamp=start, con offset e provenienza; attraversare mezzanotte è ammesso. Le fasi Android conservano start/end SDK; su iOS i tempi delle fasi sono ricavati dalle durate solo quando la somma copre esattamente l'intervallo del modello. Non vengono inventati tempi per dati mancanti o incoerenti. L'app visualizza l'intervallo inizio–fine del sonno e il timestamp dei passi. Nessun metodo SDK cambiato.


## Migrazione alla 0.3.7

Sonno raggruppato allo stesso modo su iOS e Android: al massimo una voce notturna (nap=false) e una diurna (nap=true) per giorno, con tutte le fasi in phases. durationSeconds è la somma delle durate delle fasi, comprese quelle awake, come nella rappresentazione Android esistente; non è la sola durata del sonno effettivo. start/end sono il minimo inizio e il massimo termine dei segmenti, se tutti temporizzati; l'intervallo può includere pause. Le fasi mantengono stadio, durata e orari disponibili, ordinate cronologicamente quando tutte temporizzate. Nessuna voce vuota e nessuna fusione tra notte e riposi diurni. Non cambia la SDK usata.
