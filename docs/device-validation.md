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
| Revoca del permesso Bluetooth durante connessione | Nessun ready dopo revoca; PERMISSION_DENIED e pulizia dello stato |
| Bluetooth spento e acceso | Stato aggiornato; stop scansione, chiusura operazioni |
| Scansione | ID opaco, nome se presente, RSSI; timer e stop funzionanti |
| Connect | connecting → initializing → ready; timeout finito per periferica incompatibile |
| Disconnect e reconnect ravvicinati | Nessuna callback vecchia chiude la nuova sessione; BUSY durante drenaggio |
| Perdita link durante comando | Promise conclusa una volta; connessione invalidata |
| Informazioni e batteria | Versioni lette via SDK, livello reale, nessun valore di esempio |
| Ogni metrica storica supportata | Valori e unità confrontati con demo vendor; giorno vuoto distinto da errore |
| Storico SpO₂ con sorgenti miste | Solo record automatici sourceType=0 inclusi; manuali esclusi |
| Sync parzialmente fallito | Batch riusciti presenti anche nel risultato Promise senza listener |
| Sync a mezzanotte/cambio ora | Date richieste stabili; indici SDK aggiustati o errore di retention esplicito |
| Toggle automatici true/false | Altri campi preservati; ACK seguito da lettura corrispondente |
| Intervalli automatici | Vincoli capabilities rispettati; nessun valore fuori codifica accettato |
| Background e ricreazione bridge | Scansione arrestata; chiusura richieste alla distruzione del bridge; stato corretto alla ripresa |
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
npm install ../capacitor-wristband-0.2.1.tgz
cd ..
npm run example:build
cd example
npx cap sync
xcodebuild -project ios/App/App.xcodeproj -scheme App -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
cd android
./gradlew :capacitor-wristband:testDebugUnitTest :app:assembleDebug :app:assembleRelease --max-workers=2
```

Configurare l'Android SDK tramite ANDROID_HOME o local.properties, non includere percorsi personali nel progetto distribuito. L'esempio richiede Java 21 e Xcode con SDK iOS compatibile. Il simulatore iOS non è supportato dal binario vendor attuale.


## Verifica manuale 0.3.0: parità storico

Collegare lo stesso bracciale prima a iOS, poi ad Android, nello stesso fuso e giorno. Leggere oggi e gli ultimi sette giorni per tutte le sei metriche. Verificare nei dettagli JSON dei batch e negli eventi lo schema comune documentato nel README, l'assenza di timestamp/orari/codici fase vendor e gli stessi campi per metrica. I valori possono differire se il dispositivo registra nel frattempo nuovi campioni.

Per SpO₂ verificare anche i giorni più vecchi che prima davano “SDK sample date does not match the requested day”, i giorni vuoti e gli zeri tra campioni validi: nessuna misura deve essere copiata da un altro giorno e sampleIndex deve mantenere i buchi. Per HRV/stress non deve comparire intervalMinutes; per cuore/SpO₂ compare solo se positivo e fornito dalla lettura SDK. Verificare sonno notturno, nap e fasi unknown, e passi senza dati. Gli errori reali SDK devono restare errori di batch, distinti da letture vuote riuscite.


## Verifica manuale 0.3.1: orari ricostruiti

Su iOS e Android verificare per cuore e SpO₂ timestamp, utcOffsetMinutes e timestampSource=reconstructed: indice 0 alle 00:00 locali; indice 2 con intervallo 60 alle 02:00; i buchi dello zero non spostano gli orari. Includere giorni precedenti, intervallo assente/zero, indici fuori dalle 24 ore, cambio ora legale (ore inesistenti omesse, prima occorrenza delle ore ripetute). Confrontare a parità di fuso locale del telefono. HRV e stress rimangono senza timestamp su entrambe le piattaforme fino a verifica di un intervallo storico comune.


## Verifica manuale 0.3.2: HRV e stress

Verificare su entrambe le piattaforme: HRV intervalMinutes=30, indice 2 alle 01:00; stress intervalMinutes=60, indice 2 alle 02:00. I valori zero omessi non devono compattare gli indici. Confermare la stessa cadenza anche con intervallo SDK diverso o assente. Gli indici HRV >=48 e stress >=24 non devono ricevere timestamp del giorno successivo. Le impostazioni del dispositivo non vengono cambiate.


## Verifica manuale 0.3.3: cadenza stress corretta

L'indicazione aggiornata dell'integratore è 30 minuti anche per stress: sostituisce il valore 60 della 0.3.2. Su entrambe le piattaforme HRV e stress devono avere intervalMinutes=30, indice 2 alle 01:00, indice 47 alle 23:30; indici >=48 senza timestamp del giorno successivo. I campioni zero non compattano gli indici.


## Verifica manuale 0.3.4: ripristino SpO₂ iOS

Leggere oggi e gli ultimi sette giorni con il metodo legacy. Controllare i valori presenti prima della variante WithInterval, la media min/max o il fallback soa2, timestampSource=sdk e assenza di intervalMinutes. Un campione con data fuori dal giorno richiesto non deve eliminare gli altri campioni validi né essere attribuito al giorno sbagliato; un giorno composto solo da campioni esclusi è vuoto. Con debug attivo verificare requestedDate/returnedDate delle esclusioni. Controllare sourceType=0, esclusione manuali/zeri, sampleIndex originale e gestione degli errori SDK reali. Verifica sul bracciale necessaria: la build non dimostra che la SDK restituisca dati per tutti i giorni.


## Verifica manuale 0.3.5: indici HRV Android

Confrontare i quattro valori 72,81,69,48 delle foto fornite: Android normalizza gli indici SDK 144,156,168,180 negli indici comuni 24,26,28,30, con gli orari 12:00,13:00,14:00,15:00 e intervalMinutes=30, come iOS. Nessun valore deve essere duplicato e i buchi restano presenti. Verificare anche un giorno vuoto e gli slot 0/282 (00:00/23:30). Se la SDK restituisce valori fuori dalla griglia attesa di 30 minuti, deve comparire un errore esplicito anziché perdere o spostare dati.


## Verifica manuale 0.3.6: passi e sonno

Passi: confrontare stesso giorno/dispositivo/fuso tra piattaforme; slot 0=00:00,1=00:15,48=12:00,95=23:45. Gli indici non devono compattarsi dopo campioni vuoti; iOS deve rispettare happenDate. Le ore mancanti o fuori giorno non devono ricevere timestamp inventati.
Sonno: controllare inizio/fine notturni a cavallo di mezzanotte, nap, fasi, giorni senza dati, orari assenti e durate non coerenti. Il giorno del batch non deve sovrascrivere la data reale di inizio. Verificare secondi SDK Android convertiti in millisecondi, orari locali iOS e fuso identico. Se la somma delle fasi iOS non copre il periodo, non devono comparire orari di fase ricostruiti; il periodo del record deve restare disponibile. I tempi delle fasi sono consultabili nei dettagli JSON. UI: intervallo inizio–fine per sonno, orario per passi.


## Verifica manuale 0.3.7: raggruppamento sonno

Confrontare il 16/10 delle foto: una voce notturna su entrambe le piattaforme invece delle 18 voci iOS; le fasi devono conservare i propri orari e durate (prima fase light da 36 minuti). Se le SDK restituiscono le stesse fasi, durata totale attesa 473 minuti e periodo 00:31–08:24. Controllare tutte le fasi, inclusi awake, assenza di duplicazioni, somma delle durate, ordinamento, notte separata da nap e giorni vuoti. Verificare anche due nap nello stesso giorno (raggruppati come Android), intervalli a cavallo di mezzanotte, fasi senza tempi e durata di intervallo diversa dalla somma delle fasi in presenza di pause.


## Verifica manuale 0.3.8: etichette delle fasi Android

Ripetere l'export su Android e confrontare con iOS: deep/light/awake/rem devono corrispondere a SleepDataBean 1/2/3/4. Sul dataset fornito: totali deep=387, awake=46, light=1230, rem=211 minuti; nessuna fase unknown precedentemente dovuta al codice 3. Totali giornalieri e start/end devono restare invariati. La diversa divisione di alcune fasi light contigue deve rimanere: non viene fatta alcuna fusione aggiuntiva. Codici SDK non riconosciuti restano unknown.
