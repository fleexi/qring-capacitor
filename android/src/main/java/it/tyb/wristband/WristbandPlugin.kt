package it.tyb.wristband
import android.Manifest
import android.os.Build
import com.getcapacitor.*
import com.getcapacitor.annotation.*
@CapacitorPlugin(name="Wristband",permissions=[Permission(alias="bluetooth",strings=[Manifest.permission.BLUETOOTH_SCAN,Manifest.permission.BLUETOOTH_CONNECT]),Permission(alias="location",strings=[Manifest.permission.ACCESS_FINE_LOCATION])])
class WristbandPlugin : Plugin() {
    private lateinit var session:WristbandSession
    override fun load(){session=WristbandSession(activity.application){name,data->notifyListeners(name,JSObject.fromJSONObject(data))}}
    private fun permissionResult():JSObject=JSObject().apply{
        put("bluetooth",if(Build.VERSION.SDK_INT>=31)getPermissionState("bluetooth").toString()else if(getPermissionState("location")==PermissionState.GRANTED)"granted"else getPermissionState("location").toString())
        if(Build.VERSION.SDK_INT<31)put("location",getPermissionState("location").toString())
    }
    @PluginMethod override fun checkPermissions(call:PluginCall){call.resolve(permissionResult())}
    @PluginMethod override fun requestPermissions(call:PluginCall){requestPermissionForAliases(if(Build.VERSION.SDK_INT>=31)arrayOf("bluetooth")else arrayOf("location"),call,"permissionCallback")}
    @PermissionCallback private fun permissionCallback(call:PluginCall){call.resolve(permissionResult())}
    private fun invoke(method:String,call:PluginCall){session.invoke(method,call.data){data,e->if(e==null)call.resolve(JSObject.fromJSONObject(data?:org.json.JSONObject()))else call.reject(e.optString("message"),e.optString("code"),JSObject.fromJSONObject(e))}}
    override fun handleOnPause(){session.background()}
    override fun handleOnDestroy(){session.dispose()}
    @PluginMethod fun initialize(call:PluginCall){invoke("initialize",call)}
    @PluginMethod fun getState(call:PluginCall){invoke("getState",call)}
    @PluginMethod fun startScan(call:PluginCall){invoke("startScan",call)}
    @PluginMethod fun stopScan(call:PluginCall){invoke("stopScan",call)}
    @PluginMethod fun connect(call:PluginCall){invoke("connect",call)}
    @PluginMethod fun disconnect(call:PluginCall){invoke("disconnect",call)}
    @PluginMethod fun reconnect(call:PluginCall){invoke("reconnect",call)}
    @PluginMethod fun forgetDevice(call:PluginCall){invoke("forgetDevice",call)}
    @PluginMethod fun getDeviceInfo(call:PluginCall){invoke("getDeviceInfo",call)}
    @PluginMethod fun getBattery(call:PluginCall){invoke("getBattery",call)}
    @PluginMethod fun getCapabilities(call:PluginCall){invoke("getCapabilities",call)}
    @PluginMethod fun getHistory(call:PluginCall){invoke("getHistory",call)}
    @PluginMethod fun syncHistory(call:PluginCall){invoke("syncHistory",call)}
    @PluginMethod fun startMeasurement(call:PluginCall){invoke("startMeasurement",call)}
    @PluginMethod fun stopMeasurement(call:PluginCall){invoke("stopMeasurement",call)}
    @PluginMethod fun getMeasurementSettings(call:PluginCall){invoke("getMeasurementSettings",call)}
    @PluginMethod fun setMeasurementSettings(call:PluginCall){invoke("setMeasurementSettings",call)}
}
