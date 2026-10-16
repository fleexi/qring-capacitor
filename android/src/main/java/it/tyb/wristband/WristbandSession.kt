package it.tyb.wristband
import android.app.Application
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.*
import android.os.*
import androidx.core.content.ContextCompat
import com.oudmon.ble.base.bluetooth.*
import com.oudmon.ble.base.communication.*
import com.oudmon.ble.base.communication.req.*
import com.oudmon.ble.base.communication.rsp.*
import org.json.*
import java.util.UUID
internal class WristbandSession(val app:Application,val emit:(String,JSONObject)->Unit) {
    val main=Handler(Looper.getMainLooper()); val gate=OperationGate()
    var kind:String?=null; var connection="disconnected"; var deviceId:String?=null
    var retiringId:String?=null;var historyFailure:((JSONObject)->JSONObject)?=null;var connectionToken:String?=null;var closing=false;var measurementStopping=false;var stopRequest:Reply?=null;var writeAcknowledged=false;var pending:Reply?=null;var commandId:String?=null;var watchdog:Runnable?=null
    var scanCallback:ScanCallback?=null; var scanTimeout:Runnable?=null
    var sessionId:String?=null;var measurementMetric:String?=null;var measurementMode:String?=null;var keepalive:Runnable?=null
    var time:SetTimeRsp?=null;var support:DeviceSupportFunctionRsp?=null;var receiver:QCBluetoothCallbackCloneReceiver?=null
    var versionReply:Reply?=null;var firmwareRead:String?=null;var hardwareRead:String?=null;var info=JSONObject();val settingMetadata=mutableMapOf<String,JSONObject>()
    val adapter:BluetoothAdapter? get()=(app.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter
    val ble:BleOperateManager get()=BleOperateManager.getInstance()
    val commands:CommandHandle get()=CommandHandle.getInstance()
    val saved=app.getSharedPreferences("Wristband",Context.MODE_PRIVATE)
    fun bluetooth():String= try { if(adapter==null)"unsupported" else if(adapter!!.isEnabled)"on" else "off" } catch(_:SecurityException){"unauthorized"}
    fun state()=json("bluetooth" to bluetooth(),"connection" to connection,"scanning" to (scanCallback!=null),"deviceId" to deviceId,"operationId" to gate.token,"sessionId" to sessionId)
    fun begin(done:Reply):Boolean {if(gate.begin()==null){done(null,error("BUSY","Another operation is active"));return false};pending=done;writeAcknowledged=false;return true}
    fun complete(data:JSONObject?=null,e:JSONObject?=null) {versionReply=null;val failure=historyFailure;historyFailure=null;val aggregate=if(e!=null)failure?.invoke(e)else null;val done=pending;pending=null;gate.invalidate();commandId=null;watchdog?.let(main::removeCallbacks);watchdog=null;done?.invoke(aggregate?:data?:JSONObject(),if(aggregate!=null)null else e)}
    fun once(done:Reply):Reply {
        val token=gate.token;val cmd=UUID.randomUUID().toString();commandId=cmd;watchdog?.let(main::removeCallbacks)
        watchdog=Runnable{if(gate.current(token) && commandId==cmd){val failure=if(writeAcknowledged)error("WRITE_VERIFICATION_FAILED","Write acknowledged; read-back timed out").put("writeAcknowledged",true)else error("TIMEOUT","SDK response timed out");if(sessionId!=null)finalizeMeasurement("failed","timeout",failure)else complete(null,failure);close("timeout")}}.also{main.postDelayed(it,30000)}
        return {d,e->main.post {if(gate.current(token) && commandId==cmd){commandId=null;watchdog?.let(main::removeCallbacks);watchdog=null;done(d,e)}}}
    }
    fun command(req:BaseReqCmd,done:(BaseRspCmd)->Unit) {
        once{_,_->}
        // The callback itself is gated before conversion or mutation of state.
        val token=gate.token;val cmd=commandId
        commands.executeReqCmd(req,ICommandResponse<BaseRspCmd>{rsp-> main.post {
            if(!gate.current(token) || commandId!=cmd)return@post
            commandId=null;watchdog?.let(main::removeCallbacks);watchdog=null
            if(rsp.status!=BaseRspCmd.RESULT_OK){val initializing=connection=="initializing";complete(null,error("SDK_ERROR","SDK status ${rsp.status}"));if(initializing)close("initializationFailed")} else done(rsp)
        }})
    }
    fun request(req:BaseReqCmd,done:(BaseRspCmd?,JSONObject?)->Unit) {
        once{_,_->}; val token=gate.token;val cmd=commandId
        commands.executeReqCmd(req,ICommandResponse<BaseRspCmd>{rsp->main.post {
            if(!gate.current(token)||commandId!=cmd)return@post
            commandId=null;watchdog?.let(main::removeCallbacks);watchdog=null
            if(rsp.status==BaseRspCmd.RESULT_OK)done(rsp,null)else done(null,error("SDK_ERROR","SDK status ${rsp.status}"))
        }})
    }
    fun stopScan(reason:String) { val cb=scanCallback?:return;scanCallback=null;scanTimeout?.let(main::removeCallbacks);scanTimeout=null;try{adapter?.bluetoothLeScanner?.stopScan(cb)}catch(_:SecurityException){};emit("scanStopped",json("reason" to reason)) }
    fun close(reason:String) {
        closing=true;connectionToken=null;finalizeMeasurement("cancelled",reason,null)
        if(pending!=null)complete(null,error("DISCONNECTED",reason))
        val retiringReceiver=receiver
        main.postDelayed({if(receiver===retiringReceiver && retiringId!=null && !ble.isConnected){receiver?.let{app.unregisterReceiver(it)};receiver=null;retiringId=null}},10000)
        if(deviceId!=null && connection!="disconnected")retiringId=deviceId
        if(kind!=null){ble.setAutoReconnectEnabled(false);ble.setNeedConnect(false);ble.cancelCurrentTask();ble.clearPendingTasks();ble.disconnect()}
        connection="disconnected";deviceId=null;time=null;support=null;info=JSONObject();settingMetadata.clear();emit("connectionStateChanged",state());closing=false
    }
    private val bluetoothReceiver=object:BroadcastReceiver(){override fun onReceive(c:Context?,i:Intent?){emit("bluetoothStateChanged",json("bluetooth" to bluetooth()));if(bluetooth()!="on"){stopScan("bluetoothOff");close("bluetoothOff")}}}
    var registered=false
    fun invoke(method:String,o:JSONObject,done:Reply) {main.post{try{dispatch(method,o,done)}catch(e:SecurityException){if(pending===done)complete(null,error("PERMISSION_DENIED","Bluetooth permission missing"))else done(null,error("PERMISSION_DENIED","Bluetooth permission missing"))}catch(e:Exception){if(pending===done)complete(null,error("SDK_ERROR",e.message?:"SDK error"))else done(null,error("SDK_ERROR",e.message?:"SDK error"))}}}
    fun dispatch(method:String,o:JSONObject,done:Reply) {
        if(method=="initialize") {
            val k=o.optString("deviceKind");if(k !in listOf("band","watch","ring")){done(null,error("INVALID_ARGUMENT","Invalid deviceKind"));return}
            if(gate.token!=null || connection!="disconnected"){done(null,error("BUSY","Disconnect before initialize"));return}
            kind=k;BleOperateManager.getInstance(app).init();ble.setBleLogEnabled(o.optBoolean("debug",false));ble.setManualMeasurementDefaultValuesEnabled(false);ble.setAutoReconnectEnabled(false);ble.setReconnectRemoveBond(false);ble.setConnectFailedRemoveBond(false);ble.setReconnectFailedRemoveBond(false)
            if(!registered){ContextCompat.registerReceiver(app,bluetoothReceiver,IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED),ContextCompat.RECEIVER_EXPORTED);registered=true};done(state(),null);return
        }
        if(kind==null){done(null,error("NOT_INITIALIZED","Call initialize first"));return}
        when(method){
            "getState"->{done(state(),null);return}
            "getCapabilities"->{done(capabilities(),null);return}
            "stopScan"->{stopScan("requested");done(JSONObject(),null);return}
            "disconnect","forgetDevice"->{stopScan("requested");close("requested");if(method=="forgetDevice")saved.edit().clear().apply();done(JSONObject(),null);return}
        }
        val timeout=if(o.has("timeoutMs"))o.optDouble("timeoutMs",Double.NaN)else if(method=="startScan")15000.0 else 60000.0
        if(o.has("timeoutMs") && (o.opt("timeoutMs") !is Number || !timeout.isFinite() || timeout%1.0!=0.0 || timeout<1000 || timeout>120000)){done(null,error("INVALID_ARGUMENT","timeoutMs must be an integer from 1000 to 120000"));return}
        if(method in listOf("startScan","connect","reconnect")) {
            if(bluetooth()!="on"){done(null,error(if(bluetooth()=="unauthorized")"PERMISSION_DENIED" else "BLUETOOTH_OFF","Bluetooth unavailable"));return}
            if(retiringId!=null || gate.token!=null || connection!="disconnected"){done(null,error("BUSY","Wait for disconnection before scanning or connecting"));return}
            if(method=="startScan"){
                stopScan("requested")
                val cb=object:ScanCallback(){override fun onScanResult(type:Int,r:ScanResult){main.post{if(scanCallback!==this)return@post;emit("scanResult",json("deviceId" to r.device.address,"name" to r.scanRecord?.deviceName,"rssi" to r.rssi))}};override fun onScanFailed(code:Int){main.post{if(scanCallback===this)stopScan("requested")}}}
                scanCallback=cb;adapter!!.bluetoothLeScanner.startScan(cb);scanTimeout=Runnable{stopScan("timeout")}.also{main.postDelayed(it,timeout.toLong())};done(JSONObject(),null);return
            }
            val id=if(method=="reconnect")saved.getString("deviceId",null) else o.optString("deviceId")
            if(id==null || !BluetoothAdapter.checkBluetoothAddress(id)){done(null,error("DEVICE_NOT_FOUND","No valid device ID"));return}
            if(method=="reconnect" && saved.getString("deviceKind",kind)!=kind){done(null,error("INVALID_ARGUMENT","Initialize with the saved deviceKind"));return}
            stopScan("connecting");begin(done);connectionToken=gate.token;deviceId=id;connection="connecting";emit("connectionStateChanged",state());val token=gate.token
            receiver=object:QCBluetoothCallbackCloneReceiver(){override fun connectStatue(d:BluetoothDevice?,connected:Boolean){main.post{if(!connected && d?.address==retiringId){retiringId=null;receiver?.let{app.unregisterReceiver(it)};receiver=null}else if(connectionToken==token){if(d?.address==id && !connected)close("linkLost")}}};override fun onCharacteristicRead(uuid:String?,data:ByteArray?){main.post{if(connectionToken!=token || versionReply==null || data==null)return@post;val value=data.toString(Charsets.UTF_8).trimEnd('\u0000');when(uuid){Constants.CHAR_FIRMWARE_REVISION.toString()->firmwareRead=value;Constants.CHAR_HW_REVISION.toString()->hardwareRead=value};if(firmwareRead!=null && hardwareRead!=null){val reply=versionReply;versionReply=null;info.put("firmware",firmwareRead).put("hardware",hardwareRead);reply?.invoke(info,null)}}};override fun onServiceDiscovered(){main.post{if(!gate.current(token)||connection!="connecting")return@post;connection="initializing";emit("connectionStateChanged",state());LargeDataHandler.getInstance().initEnable();command(SetTimeReq(0)){rsp->time=rsp as SetTimeRsp;command(DeviceSupportReq.getReadInstance()){r->support=r as DeviceSupportFunctionRsp;connection="ready";info=json("deviceId" to id,"deviceKind" to kind,"name" to ble.curDevice?.name);saved.edit().putString("deviceId",id).putString("deviceKind",kind).apply();complete(info);emit("connectionStateChanged",state())}}}}}
            ContextCompat.registerReceiver(app,receiver,BleAction.getIntentFilter(),ContextCompat.RECEIVER_NOT_EXPORTED)
            main.postDelayed({if(gate.current(token)&&connection!="ready"){complete(null,error("TIMEOUT","Connection timed out"));close("timeout")}},timeout.toLong());ble.connectDirectly(id);return
        }
        if(connection!="ready"){done(null,error("NOT_CONNECTED","Device is not ready"));return}
        if(method=="getDeviceInfo"){if(!begin(done))return;firmwareRead=null;hardwareRead=null;versionReply=once{d,e->complete(d,e)};commands.execReadCmd(commands.getReadHwRequest());commands.execReadCmd(commands.getReadFmRequest());return}
        if(method=="stopMeasurement"){if(sessionId==null){done(json("stopped" to false),null);return};if(sessionId!=o.optString("sessionId")){done(null,error("INVALID_ARGUMENT","Unknown session"));return};if(stopRequest!=null){done(null,error("BUSY","Stop already pending"));return};stopRequest=done;finishMeasurement("cancelled","requested",null);return}
        if(!begin(done))return
        if(method=="getBattery"){command(SimpleKeyReq(Constants.CMD_GET_DEVICE_ELECTRICITY_VALUE)){val r=it as BatteryRsp;complete(json("level" to r.batteryValue,"charging" to r.isCharging))};return}
        val metric=o.optString("metric")
        if(method=="getHistory"||method=="syncHistory"){
            val raw=if(method=="syncHistory")o.optJSONArray("metrics")else JSONArray().put(metric)
            val metrics=if(raw==null) emptyList() else (0 until raw.length()).map{raw.optString(it)}
            val s=o.optDouble("startDay",Double.NaN);val d=o.optDouble("days",Double.NaN)
            if(o.opt("startDay") !is Number || o.opt("days") !is Number || !s.isFinite()||!d.isFinite()||s%1.0!=0.0||d%1.0!=0.0||!Policy.validWindow(s.toInt(),d.toInt())||metrics.isEmpty()||metrics.distinct().size!=metrics.size||metrics.any{it !in Policy.metrics}){complete(null,error("INVALID_ARGUMENT","Invalid metrics or seven-day window"));return}
            history(metrics,s.toInt(),d.toInt());return
        }
        if(metric !in Policy.metrics){complete(null,error("INVALID_ARGUMENT","Unknown metric"));return}
        when(method){
            "getMeasurementSettings"->settings(metric,null){d,e->complete(d,e)}
            "setMeasurementSettings"->{val patch=o.optJSONObject("patch");val err=Policy.patchError(patch);if(err!=null)complete(null,error("INVALID_ARGUMENT",err))else settings(metric,patch){d,e->complete(d,e)}}
            "startMeasurement"->{val mode=o.optString("mode");if(mode !in listOf("single","continuous"))complete(null,error("INVALID_ARGUMENT","Invalid measurement mode"))else measure(metric,mode,if(o.has("timeoutMs"))timeout.toLong()else if(mode=="single")90000 else 0)}
            else->complete(null,error("UNSUPPORTED","Unknown operation"))
        }
    }
    fun background(){main.post{stopScan("requested");finishMeasurement("cancelled","appBackgrounded",null)}}
    fun dispose(){main.post{stopScan("requested");close("disposed");if(registered)app.unregisterReceiver(bluetoothReceiver);registered=false;receiver?.let{app.unregisterReceiver(it)};receiver=null;retiringId=null}}
}
