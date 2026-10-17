# Mapping e packaging vendor

SDK sorgenti conservate nella workspace. iOS QCBandSDK 1.0.0 del 20260920; Android qring_sdk_1.0.0.78.aar.

## iOS

`xcodebuild -create-xcframework` impacchetta il framework statico arm64 consegnato. SPM: prodotto CapacitorWristband, target Swift WristbandPlugin e target Objective-C WristbandVendor, binary target QCBandSDK. Slice ios-arm64 device; build generic/platform=iOS verificata. CoreBluetooth per scansione/connessione; addPeripheral registra la periferica nella SDK; setTime restituisce feature flags.

Capabilities da QCBandFeatureBloodOxygen/HRV/Stress. Cuore, passi e sonno sono protocolli di base. Flag assente resta unknown. Nessuna deduzione dal nome commerciale del dispositivo.

| Metrica | Storico | Impostazioni |
| --- | --- | --- |
| heartRate | getOneMinuHeartRateDataWithIntervalByDayIndex → QCSchedualHeartRateModel, heartRates e secondInterval | getSchedualHeartRateStatusAndInterval, setSchedualHeartRateStatus |
| bloodOxygen | getBloodOxygenDataByDayIndex → QCBloodOxygenModel con data e sourceType=0 (automatico); media max/min come OnWell, soa2 se il range non è disponibile | getSchedualBOInfoWithInterval, setSchedualBOInfoOn |
| hrv | getSchedualHRVDataWithDates → QCHRVModel, come OnWell, con data e secondInterval | getSchedualHRV, setSchedualHRVStatus |
| stress | getSchedualStressDataWithDates → QCStressModel, come OnWell anche su band | getSchedualStressStatusWithInterval, setSchedualStressStatus; minimo restituito dal dispositivo |
| steps | getSportDetailDataByDay → campioni totalStepCount/distance e happenDate | non previsto |
| sleep | getFulldaySleepDetailDataByDay, notturno e sonnellini | non previsto |

Le serie dettagliate cuore, HRV e stress vengono convertite come in OnWell: mezzanotte locale di model.date + sampleIndex × model.secondInterval. L'intervallo proviene dal modello, mai dalle impostazioni attuali. Il plugin conserva indice e intervallo ed esporta timestamp epoch ms, utcOffsetMinutes e timestampSource=reconstructed. NSDate è già un istante e viene esportato con timestampSource=sdk. I passi usano happenDate con timestampSource=reconstructed.

Un modello datato diversamente dal giorno richiesto produce SDK_ERROR con requestedDate/returnedDate. Non si sostituisce una data mancante con quella richiesta. I campioni che ricadono fuori dal giorno richiesto vengono segnalati come errore, senza rinumerarli o spostarli. Non viene applicato un taglio all'ora corrente per nascondere valori sospetti: se la SDK dettagliata continua a restituire campioni futuri, la causa richiede verifica con il dispositivo.

La ricostruzione usa il fuso locale del telefono, come OnWell. Non dimostra il fuso storico del wristband e non garantisce che uno slot corrisponda all'istante fisico esatto della misura. Nei cambi d'ora viene usato il medesimo algoritmo di elapsed seconds di OnWell; dati di una griglia fissa da 24 ore che escono dal giorno locale vengono segnalati, senza correggerli in modo arbitrario. Le fasi enum QCSleepModel.type sono mappate 1=awake/2=light/3=deep/4=rem; CSV dataTypes mantiene vendorStage e unknown finché la codifica per quel protocollo non è verificata. Le stringhe locali happenDate/endTime si preservano senza appiccicare un offset inventato.


## Android

AAR nel repository Maven locale del plugin: it.tyb.vendor:qring:1.0.0.78-tyb.1. Si evita la dipendenza diretta files(AAR) in un modulo libreria, che non è ridistribuibile correttamente attraverso un normale AAR Android.

Il derivato mantiene identici classes.jar, risorse, JAR inclusi e librerie native. Sostituisce solo proguard.txt: l'originale includeva opzioni globali come -ignorewarnings, -printmapping, -flattenpackagehierarchy e -optimizations che non devono governare tutta l'app consumatrice. Il derivato conserva API vendor, classi RealSil, attributi e metodi JNI. `scripts/prepare-android-vendor.py` riproduce la trasformazione dall'originale. Copia originale intatta fuori dal plugin.

SHA256 AAR originale: `77a43999ac8f741eb60276ccfafe9b48399865944285f1d253653b3bbbf0a3bf`.

Le dipendenze del demo UI non sono importate. Il riferimento AndroidNetworking riguarda solo RecordingPcmImportManager per import Wi-Fi di registrazioni, fuori dal contratto: si sopprimono solo i warning di quel namespace opzionale. Il plugin non inizializza né espone registrazione/Wi-Fi/OTA. Anche il JAR opzionale RealSil audio playback incluso dal vendor fa riferimento a nove classi customer-layer non fornite: si sopprimono solo quei nove nomi elencati nello script di preparazione; la funzione audio non viene esposta o inizializzata. Nessun ignorewarnings globale aggiunto.

Sessione con BleOperateManager, autoReconnect disattivato, rimozione pairing automatica disattivata; receiver QCBluetoothCallbackCloneReceiver per link e servizi. Dopo onServiceDiscovered: LargeDataHandler.initEnable, SetTimeReq e DeviceSupportReq. Callback comandate su main thread e protette da token/commandId.

| Metrica | Storico | Impostazioni |
| --- | --- | --- |
| heartRate | getHeartRate → ReadHeartRateRsp.array o unsigned mHeartRateArray | HeartRateSettingReq/Rsp, preserva startInterval, reminder low/high, mainSwitch |
| bloodOxygen | getBloodOxygen → BloodOxygenEntity.array | BloodOxygenSettingReq/Rsp, byte intervallo trattato unsigned |
| hrv | getHrv → HRVRsp.array o unsigned hrvArray | HrvSettingReq / HRVSettingRsp |
| stress | getPressure → PressureRsp.array o unsigned pressureArray | PressureSettingReq/Rsp, isIntervalSettingSupported e minInterval |
| steps | getStepDetail → BleStepDetails, walkSteps e distance | non previsto |
| sleep | getSleep → SleepDisplay, list e napList | non previsto |

La guida dichiara intervalli cuore/SpO₂ in minuti. Le soglie stress provengono dalla risposta. HRV/stress mantengono unità vendor. BleStepDetails timeIndex è uno slot da 15 minuti, distance in metri. SleepDataBean start/end sono Unix secondi (SDK getFallSleepMin usa (end-start)/60); mapSleepProtocolType converte i protocolli in 1=awake, 2=light, 3=non-worn, 4=REM, 5=deep. 3 resta unknown nel contratto.

Le sei librerie native arm64 dell'AAR sono state ispezionate: tutti i segmenti ELF LOAD hanno allineamento almeno 16 KB. La verifica non equivale a un collaudo su dispositivo Android con pagine da 16 KB.

Stress e HRV seguono le API usate da OnWell: il funzionamento su band è confermato dall’integrazione esistente e dall’utente, nonostante le annotazioni ring-only degli header vendor. La API HRV è deprecata nella SDK fornita; si mantiene intenzionalmente il percorso verificato su OnWell.
