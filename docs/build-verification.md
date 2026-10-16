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
