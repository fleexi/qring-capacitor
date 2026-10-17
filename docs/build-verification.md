# Verifiche eseguite — 16 ottobre 2026

Verifica su macOS, Node 24.16.0, Java 21, Xcode 27.1, Capacitor 8.5.2. Il plugin è stato impacchettato con npm pack, installato da tarball nell'app esempio e riconosciuto da cap sync su entrambe le piattaforme.

| Verifica | Esito |
| --- | --- |
| npm run check | PASS: typecheck, test contratto web, build ESM/CJS e dichiarazioni |
| npm run test:ios-policy | PASS: asserzioni Foundation sulle politiche native |
| :capacitor-wristband:testDebugUnitTest | PASS: 7 test JUnit, 0 errori/fallimenti |
| npm run example:build | PASS: bundle browser dell'esempio |
| cap sync | PASS: rilevato capacitor-wristband 0.1.0 Android/iOS; SPM generato correttamente |
| xcodebuild App, generic/platform=iOS, CODE_SIGNING_ALLOWED=NO | BUILD SUCCEEDED: app device arm64 e framework vendor collegati |
| :app:assembleDebug | BUILD SUCCESSFUL |
| :app:assembleRelease | BUILD SUCCESSFUL: R8 attivo, APK release non firmato |
| AAR derivato rispetto all'originale | Solo proguard.txt differisce; bytecode/risorse/JAR/JNI identici |
| Allineamento ELF delle 6 librerie arm64 | Tutti i segmenti LOAD >= 16 KB |

I test JUnit coprono esclusione e token vecchi/duplicati, patch false/vuote/invalide, retention di sette giorni, risultati precedenti a un timeout, slot mancanti senza timestamp inventati, read-back diverso dalla patch e giorni fissati attraverso il cambio d'ora. L'eseguibile iOS copre le corrispondenti politiche Foundation. Sono test del core: non sostituiscono una prova del bridge/lifecycle su telefono.

È stata svolta una revisione indipendente dei sorgenti e delle evidenze SDK, con correzioni su callback vecchie, errori di inizializzazione, refresh del continuo, stop con barriera ACK, aggregazione dei risultati parziali e distinzione fra durata della misura iOS e deadline esterna.

Le modifiche successive all'ultima build Android riguardano solo l'adattatore iOS e la documentazione. La build iOS è stata ripetuta dopo queste correzioni. Il pacchetto finale viene confrontato con i sorgenti nativi installati nell'esempio per verificare che contenga lo stesso codice compilato.

Restano non eseguiti: test fisici con wristband/firmware reale, runtime su telefono, installazione in OnActive e simulatore iOS (slice vendor assente). OnActive non è stata modificata. Nessuna pubblicazione npm, firma o distribuzione ad altri utenti.

Vedere device-validation.md per la matrice di collaudo e README.md per l'installazione.


## Aggiornamento 0.1.2: letture dettagliate iOS

Cambio richiesto dopo confronto con OnWell: cuore getOneMinuHeartRateDataWithIntervalByDayIndex, SpO₂ getBloodOxygenDataByDayIndex, passi getSportDetailDataByDay. Stress ring usa getSchedualStressDataWithDates; band/watch usano getPressureSamplesWithDayIndexes per rispettare il vincolo ring-only della prima API. HRV resta sulla API dettagliata preferita della SDK.

Il mapper conserva indice/intervallo e aggiunge timestamp e provenienza; rifiuta modelli con giorno diverso dalla richiesta. Nuovi test Foundation verificano intervallo restituito dal modello, buchi negli indici, conversione epoch/offset, giorno errato, data non valida e assenza di taglio arbitrario degli slot futuri. TypeScript e test Foundation passati, pacchetto installato nell'esempio e build device iOS eseguita. Nessuna nuova build Android: il suo codice nativo è invariato. Revisione indipendente completata e corretta la distinzione stress ring/band.

Il cambio di metodo non dimostra che il firmware stesse restituendo ieri: la scomparsa dei campioni futuri dello screenshot deve essere verificata sul dispositivo reale con 0.1.2. Nessuna prova fisica eseguita in questa sessione.

## Aggiornamento 0.1.3: percorso band verificato su OnWell

L’utente conferma che OnWell usa band e che tutte le letture funzionano. Rimossa quindi la distinzione ring/band per stress: getSchedualStressDataWithDates è ora usato per tutti i tipi. Anche HRV è allineato a getSchedualHRVDataWithDates, mantenendo intenzionalmente la API deprecata verificata su OnWell. Entrambe le serie usano il mapper testato con data e secondInterval del modello. La sezione 0.1.2 sopra descrive la versione precedente.

## Aggiornamento 0.1.4: rimozione temperatura

Rimossa la temperatura dal contratto TypeScript, dagli elenchi di metriche e capability iOS/Android, dagli adattatori storico/impostazioni/misurazione e dal selettore dell’esempio. Restano heartRate, bloodOxygen, hrv, stress, steps e sleep. Nessuna modifica alle chiamate delle sei metriche rimaste o ai binari SDK vendor. Le prove fisiche iOS riportate dall’utente confermano battito, SpO₂, HRV, stress e passi; il sonno e la coerenza Android sono ancora da collaudare.

Verifiche 0.1.4: npm run check, test:ios-policy e example:build passati. Pacchetto installato nell’esempio e cap sync iOS/Android completato. Build iOS generic/platform=iOS senza firma riuscita; Android :app:assembleDebug e :capacitor-wristband:testDebugUnitTest riusciti (7 test, zero errori/fallimenti), con Java 21. Nessuna prova fisica aggiuntiva in questa sessione.

## Aggiornamento 0.2.0: solo raccolta automatica

Rimossi startMeasurement/stopMeasurement da contratto TypeScript, fallback web e bridge Swift/Kotlin. Eliminati adattatori di misurazione, callback/eventi, timer di refresh, campi di sessione e capability single/continuous. Rimossi comandi manuali dall’esempio. Restano configurazione automatica e storico delle sei metriche. Il filtro SpO₂ iOS include solo sourceType=0, escludendo le letture manuali e le sorgenti sconosciute dalla risposta mista della SDK. I binari vendor restano intatti. Le sezioni precedenti documentano le versioni storiche.

Regressioni: contratto TypeScript rifiuta avvio/stop, eventi e capability manuali; fallback web non espone acquisizione. Test Foundation controllano esclusione di record SpO₂ manuali/sconosciuti e conservazione dei valori automatici, con media max/min o fallback soa2. Controlli verificati prima in errore e poi passati.

Verifiche 0.2.0: npm run check (typecheck, 2 test web/contratto e build), test:ios-policy e example:build passati; cap sync iOS/Android riuscito. Build device iOS generic/platform=iOS senza firma riuscita; Android testDebugUnitTest (7 test, zero errori/fallimenti), assembleDebug e assembleRelease con R8 riusciti, Java 21. Revisione indipendente in sola lettura: nessun problema concreto rilevato. Il collaudo fisico della nuova versione resta da eseguire.

## Aggiornamento 0.2.1: permessi Bluetooth Android

Riprodotti nel modulo dell’esempio i due errori MissingPermission segnalati nel lint di OnActive: avvio BLE scan e lettura BluetoothDevice.name nel callback di inizializzazione. Aggiunto controllo esplicito dei permessi per versione OS e operazione; avvio scansione con try/catch locale e stato impostato solo dopo il successo; lettura nome e completamento inizializzazione protetti contro SecurityException e revoca, con PERMISSION_DENIED e chiusura. Cleanup tollera la revoca. Nessuna soppressione lint o baseline.

Verifiche: lintDebug plugin riprodotto in errore prima del fix (2 MissingPermission), passato dopo (0 errori, 7 warning non bloccanti). Android testDebugUnitTest: 7 test, zero errori/fallimenti. assembleDebug e assembleRelease con R8 riusciti, Java 21. Modifica solo Android: nessuna nuova build iOS necessaria. OnActive non modificata; serve reinstallare il pacchetto e sincronizzare. La revoca su dispositivo fisico resta da collaudare.

## Aggiornamento 0.2.2: giorni senza sonno Android

La SDK Android può completare getSleep con onSuccess(null) quando non trova dati per il giorno richiesto (verificato nel bytecode del callback vendor). Il mapper Kotlin non nullable causava SDK_ERROR: Malformed history. Il callback del sonno e il mapper ora accettano null e restituiscono records vuoto; onError resta un errore SDK. Mapping di fasi, timestamp e riposini invariato.

Regressione riprodotta prima della correzione: missingSleepDayProducesNoRecords fallisce con NullPointerException. Dopo il fix: 10 test JUnit passati, inclusi giorno nullo, liste assenti e sonno con riposino; lintDebug e assembleDebug riusciti. npm run check passato (typecheck, 2 test contratto, build). Serve il collaudo fisico Android; nessuna prova con wristband eseguita in questa sessione.
