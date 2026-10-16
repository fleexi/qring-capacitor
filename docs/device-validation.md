# Verifica del plugin

Questa consegna separa verifiche software e interoperabilità con il wristband reale. Nessun dispositivo è stato usato per il collaudo fisico.

## Verifiche software

- TypeScript: typecheck, contratto di input, fallback web UNSUPPORTED, bundle ESM/CJS e dichiarazioni.
- Core iOS: eseguibile Foundation su macOS con asserzioni su token vecchi/duplicati, esclusione, patch false/vuote/non valide, finestre di sette giorni, conservazione di batch su timeout, slot mancanti, readBack diverso dalla patch e cambio d'ora Europe/Rome.
- Core Android: test JVM JUnit delle medesime politiche, eseguiti tramite il modulo plugin nell'app esempio.
- Build app esempio device iOS arm64 con SDK reale, SPM e firma disabilitata.
- Build Android debug e release con R8 abilitato, con libreria vendor risolta dal Maven locale nel pacchetto.
- Ispezione allineamento ELF: sei librerie arm64 vendor, tutti i segmenti LOAD >= 16 KB.
- Le verifiche core non simulano integralmente CoreBluetooth, il bridge WebView, il lifecycle mobile o il protocollo radio. Questi richiedono il collaudo seguente.

I risultati finali e i comandi sono registrati in `docs/build-verification.md`. L'esempio non contiene dati sanitari reali salvati su disco; il log è solo nel DOM.

## Collaudo da eseguire con dispositivo reale

Annotare modello, firmware, tipo band/watch/ring, versione OS e piattaforma. Per ogni riga, registrare esito ed eventuale errore. Stato iniziale di tutte queste prove: **non eseguita**.

| Caso | Risultato atteso |
| --- | --- |
| Permessi negati e poi concessi | Nessun crash; stato e codice PERMISSION_DENIED coerenti |
| Bluetooth spento e acceso | Stato aggiornato; stop scansione, chiusura operazioni |
| Scansione | ID opaco, nome se presente, RSSI; timer e stop funzionanti |
| Connect | connecting → initializing → ready; timeout finito per periferica incompatibile |
| Disconnect e reconnect ravvicinati | Nessuna callback vecchia chiude la nuova sessione; BUSY durante drenaggio |
| Perdita link durante comando | Promise conclusa una volta; connessione invalidata |
| Informazioni e batteria | Versioni lette via SDK, livello reale, nessun valore di esempio |
| Ogni metrica storica supportata | Valori e unità confrontati con demo vendor; giorno vuoto distinto da errore |
| Sync parzialmente fallito | Batch riusciti presenti anche nel risultato Promise senza listener |
| Sync a mezzanotte/cambio ora | Date richieste stabili; indici SDK aggiustati o errore di retention esplicito |
| Toggle automatici true/false | Altri campi preservati; ACK seguito da lettura corrispondente |
| Intervalli automatici | Vincoli capabilities rispettati; nessun valore fuori codifica accettato |
| Misura singola | Risultato reale, nessun fallback; stop/timeout con evento terminale unico |
| Cuore continuo | Refresh sequenziale, nessun nuovo comando prima della risposta; guasto refresh termina la misura |
| Stop seguito da nuovo comando | Gate mantenuto fino a conferma dello stop o chiusura del link |
| Background e ricreazione bridge | Stop, chiusura richieste e timer; stato corretto alla ripresa |
| App installata da tarball | Plugin e librerie presenti senza riferimenti alla workspace |

## Ripetizione delle build

Dalla directory del plugin:

```sh
npm ci
npm run check
npm run test:ios-policy
npm pack
cd example
npm ci
npm install ../capacitor-wristband-0.1.0.tgz
cd ..
npm run example:build
cd example
npx cap sync
xcodebuild -project ios/App/App.xcodeproj -scheme App -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
cd android
./gradlew :capacitor-wristband:testDebugUnitTest :app:assembleDebug :app:assembleRelease --max-workers=2
```

Configurare l'Android SDK tramite ANDROID_HOME o local.properties, non includere percorsi personali nel progetto distribuito. L'esempio richiede Java 21 e Xcode con SDK iOS compatibile. Il simulatore iOS non è supportato dal binario vendor attuale.
