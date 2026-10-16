# capacitor-wristband

Plugin Capacitor 8 per le SDK QRing fornite: iOS 1.0.0 (20260920), Android 1.0.0.78. Contratto TypeScript unico, adattatori nativi, un dispositivo per volta.

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
npm install ../../tyb-wirstband/capacitor-wristband/capacitor-wristband-0.1.0.tgz
npm run sync-dev
```

Usare `sync-demo` o `sync-prod` quando appropriato: questi script preservano APP_FLAVOUR. Non modificare il Package.swift generato dalla CLI. Il pacchetto SPM esporta il prodotto `CapacitorWristband`.

In `ios/App/App/Info.plist` aggiungere `NSBluetoothAlwaysUsageDescription` con una spiegazione adeguata all'app. L'esempio la include già. Il framework vendor consegnato contiene **solo iOS device arm64**: il simulatore non è supportato. Non è una XCFramework universale; non contiene una slice simulatore inventata.

OnActive non ha ancora la piattaforma Android. Quando si aggiungerà, usare `@capacitor/android` della stessa versione dell'app e impostare `minSdkVersion=26` in `android/variables.gradle`. I permessi BLE sono dichiarati dal plugin; Android 11 e precedenti richiedono anche il consenso alla posizione per la scansione. Il plugin non richiede la posizione su Android 12+. Il flag neverForLocation può filtrare alcuni beacon; nessun uso di localizzazione è implementato.

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
  metrics: ['heartRate', 'bloodOxygen', 'temperature', 'hrv', 'stress', 'steps', 'sleep'],
  startDay: 0, days: 7,
});
// Controllare status e ogni batch: partial/failed contengono errori per giorno/metrica.
console.log(history.status, history.batches);
const resultListener = await Wristband.addListener('measurementUpdated', console.log);
const session = await Wristband.startMeasurement({ metric: 'heartRate', mode: 'continuous' });
await Wristband.stopMeasurement(session);
await resultListener.remove();
await scan.remove();
await Wristband.disconnect();
```

`deviceId` nell'esempio è una variabile dell'app, non un MAC hardcoded. Connettere un risultato soltanto dopo aver verificato che sia il dispositivo atteso. Entrambe le piattaforme scansionano le periferiche BLE disponibili; non tutte sono compatibili con il protocollo QRing.

## Flussi e impostazioni

- `connect` risolve dopo registrazione SDK, sincronizzazione orario e feature discovery. Il link BLE da solo non equivale a ready.
- `disconnect` conserva il riferimento all'ultimo dispositivo. `reconnect` lo riutilizza; `forgetDevice` lo cancella. Nessuna riconnessione automatica infinita. `forgetDevice` non rimuove pairing del sistema.
- Una sola operazione SDK alla volta: le chiamate concorrenti restituiscono BUSY. Su iOS può comparire BUSY anche durante il completamento della disconnessione precedente.
- Impostazioni: cuore, SpO₂, temperatura, HRV, stress. Read/modify/write/readBack preserva i campi non modificati. Nessuna scrittura batch implicita. Intervalli e abilitazioni hanno capabilities distinte.
- Per iOS temperatura si espone il toggle sui ring; l'intervallo rimane non scrivibile nella v1 perché il getter non ne restituisce il valore e non è verificata una mappatura equivalente per band/watch. HRV espone il toggle, senza intervallo.
- Cuore/SpO₂/stress espongono intervalli solo dopo lettura riuscita; Android temperatura può esporlo dopo lettura. Minimo stress rilevato dal dispositivo; 255 è il limite conservativo di codifica adottato, non la garanzia che il firmware accetti ogni numero.
- Stato corrente solo dal dispositivo. Successo di una scrittura non significa che il parametro sia stato riletto: controllare `verification`. Se la rilettura fallisce dopo ACK, codice WRITE_VERIFICATION_FAILED con `writeAcknowledged: true`. In caso di timeout la connessione viene chiusa perché il flusso SDK potrebbe non essere più allineato.
- Misure singole: metriche supportate dal dispositivo; continuo solo cuore, se disponibile. Nessun dato di fallback. Default singolo 90 s; iOS concede altri 5 s al completamento SDK, oltre al watchdog dello stop. Il timeout non comprende il drenaggio dello stop (massimo 30 s). Continuo senza limite applicativo, con refresh nativo e watchdog. Il refresh fallito termina la sessione.
- Stop mantiene l'esclusione fino alla conferma SDK. Android cancella anche la misura gestita internamente e usa uno stop tracciato come barriera; se il firmware non risponde, il timeout chiude la connessione.
- Background ferma scansione e misure. Nessuna promessa di acquisizione con app sospesa/terminata.

## Storia, eventi e unità

`startDay=0` è oggi. `startDay + days <= 7`, valori interi positivi per days. I giorni sono fissati all'avvio: dopo mezzanotte l'adattatore corregge l'indice relativo passato alla SDK; un giorno uscito dalla retention diventa un errore esplicito.

`historyBatch` e `syncProgress` consentono aggiornamenti incrementali; il risultato Promise contiene anche tutti i batch, inclusi quelli precedenti a un timeout. Non sommare due volte eventi e risultato: usare operationId e batchIndex. Il sync restituisce success/partial/failed; un giorno vuoto riuscito è diverso da un errore.

Cuore bpm, SpO₂ %, temperatura °C, distanza metri, durate secondi. HRV e stress usano unità `vendor`: nessuna equivalenza clinica assunta. Campioni indicizzati conservano sampleIndex/intervalMinutes senza inventare un istante UTC. Gli zeri senza lettura sono omessi mantenendo l'indice originale. Il sonno preserva fasi non mappate come unknown con vendorStage. I tempi locali iOS sono conservati come stringhe se non offrono un offset univoco. Energia omessa fino a verifica della conversione vendor.

Eventi: bluetoothStateChanged, scanResult, scanStopped, connectionStateChanged, historyBatch, syncProgress, measurementUpdated, measurementFinished. Gli eventi di misura hanno sessionId; quelli storici operationId. Ogni sessione misura ha un solo evento terminale.

Il web restituisce UNSUPPORTED; non simula un wristband. Definizioni complete in `src/definitions.ts`.

## Verifica e limiti

```sh
npm run check
npm run test:ios-policy
npm run example:build
```

Nell'esempio: `npx cap sync`, build device iOS senza firma e build Android debug/release. Le prove hardware richiedono un wristband compatibile: vedere `docs/device-validation.md`. Il successo delle build non prova il comportamento del firmware.

Il pacchetto usa binari vendor consegnati localmente. Prima della distribuzione pubblica verificare i termini di redistribuzione del fornitore; nessuna pubblicazione npm è stata eseguita.
