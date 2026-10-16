package it.tyb.wristband
import com.oudmon.ble.base.communication.ICommandResponse
import com.oudmon.ble.base.communication.req.*
import com.oudmon.ble.base.communication.rsp.*
internal fun WristbandSession.refreshHeart(token:String) {
    if(!gate.current(token)||measurementStopping)return
    request(RealTimeHeartRate(3)){rsp,e->if(e!=null){finishMeasurement("failed","refreshFailed",e);return@request}
        val r=rsp as RealTimeHeartRateRsp;value("heartRate",r.heart.toDouble(),token)
        keepalive=Runnable{refreshHeart(token)}.also{main.postDelayed(it,2000)}
    }
}
internal fun WristbandSession.measure(m:String,mode:String,timeout:Long) {
    val s=metricCapability(m).getJSONObject(if(mode=="single")"singleMeasurement"else "continuousMeasurement").getString("support")
    if(s!="supported"){complete(null,error(if(s=="unknown")"CAPABILITY_UNKNOWN"else "UNSUPPORTED","Measurement mode unavailable"));return}
    val token=gate.token!!;sessionId=token;measurementMetric=m;measurementMode=mode;measurementStopping=false
    if(mode=="continuous") {
        request(RealTimeHeartRate(1)){_,e->val started=pending;pending=null;if(e!=null){started?.invoke(null,e);finishMeasurement("failed",null,e);return@request};started?.invoke(json("sessionId" to token),null);refreshHeart(token)}
    } else {
        val started=pending;pending=null
        val callback=ICommandResponse<StartHeartRateRsp>{rsp->main.post{
            if(!gate.current(token)||measurementStopping)return@post
            if(rsp.status!=BaseRspCmd.RESULT_OK || rsp.errCode.toInt()!=0){finishMeasurement("failed",null,error("SDK_ERROR","Measurement error ${rsp.errCode}"));return@post}
            val v=when(m){"heartRate"->rsp.value.toDouble();"bloodOxygen"->rsp.value.toDouble();"temperature"->rsp.temperature/10.0;"hrv"->if(rsp.hrv>0)rsp.hrv.toDouble()else rsp.value.toDouble();"stress"->if(rsp.stress>0)rsp.stress.toDouble()else rsp.value.toDouble();else->0.0}
            if(v>0){value(m,v,token);finishMeasurement("completed",null,null)}
        }}
        manual(m,callback,false);started?.invoke(json("sessionId" to token),null)
    }
    if(timeout>0)main.postDelayed({if(gate.current(token))finishMeasurement("failed","timeout",error("TIMEOUT","Measurement session expired"))},timeout)
}
internal fun WristbandSession.value(m:String,v:Double,token:String) {if(!gate.current(token)||sessionId==null||measurementStopping||!v.isFinite()||v<=0)return;emit("measurementUpdated",json("sessionId" to token,"deviceId" to deviceId,"metric" to m,"value" to v,"unit" to Policy.unit(m),"timestamp" to System.currentTimeMillis()))}
internal fun WristbandSession.manual(m:String,cb:ICommandResponse<StartHeartRateRsp>?,stop:Boolean){when(m){"heartRate"->ble.manualModeHeart(cb,stop);"bloodOxygen"->ble.manualModeSpO2(cb,stop);"temperature"->ble.manualTemperature(cb,stop);"hrv"->ble.manualModeHrv(cb,stop);"stress"->ble.manualModePressure(cb,stop)}}
internal fun WristbandSession.finishMeasurement(status:String,reason:String?,e:org.json.JSONObject?){
    if(sessionId==null||measurementStopping)return;measurementStopping=true;keepalive?.let(main::removeCallbacks);keepalive=null
    val m=measurementMetric!!
    val req:BaseReqCmd=if(measurementMode=="continuous")RealTimeHeartRate(2)else {
        // Clear SDK-owned timers/listeners, then send an ACK-tracked stop as a protocol barrier.
        manual(m,null,true)
        when(m){"heartRate"->StopHeartRateReq.stopHeartRate(0);"bloodOxygen"->StopHeartRateReq.stopBloodOxygen(0);"temperature"->StopHeartRateReq.stopTemperatureCheck();"hrv"->StopHeartRateReq.stopHrv(0);else->StopHeartRateReq.stopPressure(0)}
    }
    request(req){_,stopError->finalizeMeasurement(if(stopError==null)status else "failed",reason,stopError?:e);if(stopError!=null)close("stopFailed")}
}
internal fun WristbandSession.finalizeMeasurement(status:String,reason:String?,e:org.json.JSONObject?){
    val id=sessionId?:return;val m=measurementMetric!!;sessionId=null;measurementStopping=false;keepalive?.let(main::removeCallbacks);keepalive=null
    val stop=stopRequest;stopRequest=null
    if(pending!=null)complete(null,e?:error("CANCELLED",reason?:"Measurement cancelled"))else complete()
    emit("measurementFinished",json("sessionId" to id,"deviceId" to deviceId,"metric" to m,"status" to status,"reason" to reason,"error" to e))
    stop?.invoke(if(e==null)json("stopped" to true)else null,e)
}
