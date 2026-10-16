import Capacitor
import WristbandVendor

@objc(WristbandPlugin)
public class WristbandPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "WristbandPlugin"
    public let jsName = "Wristband"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "initialize", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "checkPermissions", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "requestPermissions", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getState", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "startScan", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stopScan", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "connect", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "disconnect", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "reconnect", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "forgetDevice", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getDeviceInfo", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getBattery", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getCapabilities", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getHistory", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "syncHistory", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "startMeasurement", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stopMeasurement", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getMeasurementSettings", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setMeasurementSettings", returnType: CAPPluginReturnPromise)
    ]
    private let session = WBSession()
    public override func load() {
        session.event = { [weak self] name, data in self?.notifyListeners(name, data: data as? [String: Any] ?? [:]) }
        NotificationCenter.default.addObserver(self, selector: #selector(background), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    @objc private func background() { session.background() }
    deinit { NotificationCenter.default.removeObserver(self); session.dispose() }
    private func invoke(_ method: String, _ call: CAPPluginCall) {
        DispatchQueue.main.async { [self] in
            session.invoke(method, options: call.options) { result, error in
                if let error = error {
                    call.reject(error["message"] as? String ?? "SDK error", error["code"] as? String ?? "SDK_ERROR", nil, error as? [String: Any])
                } else { call.resolve(result as? [String: Any] ?? [:]) }
            }
        }
    }
    @objc func initialize(_ call: CAPPluginCall) { invoke("initialize", call) }
    @objc public override func checkPermissions(_ call: CAPPluginCall) { invoke("checkPermissions", call) }
    @objc public override func requestPermissions(_ call: CAPPluginCall) { invoke("requestPermissions", call) }
    @objc func getState(_ call: CAPPluginCall) { invoke("getState", call) }
    @objc func startScan(_ call: CAPPluginCall) { invoke("startScan", call) }
    @objc func stopScan(_ call: CAPPluginCall) { invoke("stopScan", call) }
    @objc func connect(_ call: CAPPluginCall) { invoke("connect", call) }
    @objc func disconnect(_ call: CAPPluginCall) { invoke("disconnect", call) }
    @objc func reconnect(_ call: CAPPluginCall) { invoke("reconnect", call) }
    @objc func forgetDevice(_ call: CAPPluginCall) { invoke("forgetDevice", call) }
    @objc func getDeviceInfo(_ call: CAPPluginCall) { invoke("getDeviceInfo", call) }
    @objc func getBattery(_ call: CAPPluginCall) { invoke("getBattery", call) }
    @objc func getCapabilities(_ call: CAPPluginCall) { invoke("getCapabilities", call) }
    @objc func getHistory(_ call: CAPPluginCall) { invoke("getHistory", call) }
    @objc func syncHistory(_ call: CAPPluginCall) { invoke("syncHistory", call) }
    @objc func startMeasurement(_ call: CAPPluginCall) { invoke("startMeasurement", call) }
    @objc func stopMeasurement(_ call: CAPPluginCall) { invoke("stopMeasurement", call) }
    @objc func getMeasurementSettings(_ call: CAPPluginCall) { invoke("getMeasurementSettings", call) }
    @objc func setMeasurementSettings(_ call: CAPPluginCall) { invoke("setMeasurementSettings", call) }
}
