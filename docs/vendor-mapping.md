# Mapping e packaging vendor

SDK sorgenti conservate nella workspace. iOS QCBandSDK 1.0.0 del 20260920; Android qring_sdk_1.0.0.78.aar.

## iOS

`xcodebuild -create-xcframework` impacchetta il framework statico arm64 consegnato. SPM: prodotto CapacitorWristband, target Swift WristbandPlugin e target Objective-C WristbandVendor, binary target QCBandSDK. Slice ios-arm64 device; build generic/platform=iOS verificata. CoreBluetooth per scansione/connessione; addPeripheral registra la periferica nella SDK; setTime restituisce feature flags.

Capabilities da QCBandFeatureBloodOxygen/Temperature/HRV/Stress e AppManual. Cuore, passi e sonno sono protocolli di base. Flag assente resta unknown. Nessuna deduzione dal nome commerciale del dispositivo.

| Metrica | Storico | Impostazioni |
| --- | --- | --- |
| heartRate | getSchedualHeartRateDataWithDayIndexs → QCSchedualHeartRateModel, heartRates e secondInterval / 60 | getSchedualHeartRateStatusAndInterval, setSchedualHeartRateStatus |
| bloodOxygen | getBloodOxygenDataWithIntervalByDayIndex; array indicizzato oppure QCBloodOxygenModel | getSchedualBOInfoWithInterval, setSchedualBOInfoOn |
| temperature | getSchedualTemperatureDataByDayIndex → QCTemperatureModel, °C e NSDate | get/setSchedualInfoType BodyTemperator, calibrazione preservata; ring-only |
| hrv | getHRVSamplesWithDayIndexes → QCHRVDayModel.samples con valore e istante SDK | getSchedualHRV, setSchedualHRVStatus |
| stress | getOtherDataPressureWithDayIndexes → QCOtherDataPressureModel.values e interval | getSchedualStressStatusWithInterval, setSchedualStressStatus; minimo restituito dal dispositivo |
| steps | getOneDaySportBy → totalStepCount, distance in metri | non previsto |
| sleep | getFulldaySleepDetailDataByDay, notturno e sonnellini | non previsto |

Le serie indicizzate non vengono convertite in istanti assoluti con l'assunzione di 24 ore. NSDate è già un istante e viene esportato in millisecondi con offset locale. Le fasi enum QCSleepModel.type sono mappate 1=awake/2=light/3=deep/4=rem; CSV dataTypes mantiene vendorStage e unknown finché la codifica per quel protocollo non è verificata. Le stringhe locali happenDate/endTime si preservano senza appiccicare un offset inventato.

Misure singole QCSDKManager.startToMeasuring, disableDefaultMeasuringValues=YES; continuo con begin/continue/endRealTimeHeartRate, refresh sequenziale ogni 2 s dopo ACK e watchdog 30 s. Stop prima di liberare il gate.

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
| temperature | getTemperature → IntervalTemperatureEntity.array, Float in °C | SugarLipidsSettingReq / BloodSugarLipidsSettingRsp, preserva value |
| hrv | getHrv → HRVRsp.array o unsigned hrvArray | HrvSettingReq / HRVSettingRsp |
| stress | getPressure → PressureRsp.array o unsigned pressureArray | PressureSettingReq/Rsp, isIntervalSettingSupported e minInterval |
| steps | getStepDetail → BleStepDetails, walkSteps e distance | non previsto |
| sleep | getSleep → SleepDisplay, list e napList | non previsto |

La guida dichiara intervalli cuore/SpO₂/temperatura in minuti. Le soglie stress provengono dalla risposta. HRV/stress mantengono unità vendor. BleStepDetails timeIndex è uno slot da 15 minuti, distance in metri. SleepDataBean start/end sono Unix secondi (SDK getFallSleepMin usa (end-start)/60); mapSleepProtocolType converte i protocolli in 1=awake, 2=light, 3=non-worn, 4=REM, 5=deep. 3 resta unknown nel contratto. Misura temperatura manuale: SDK usa 365 per 36.5 °C, quindi /10; nessun placeholder abilitato.

Le sei librerie native arm64 dell'AAR sono state ispezionate: tutti i segmenti ELF LOAD hanno allineamento almeno 16 KB. La verifica non equivale a un collaudo su dispositivo Android con pagine da 16 KB.
