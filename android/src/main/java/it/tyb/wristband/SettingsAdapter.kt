package it.tyb.wristband
import org.json.JSONObject
import com.oudmon.ble.base.communication.req.*
import com.oudmon.ble.base.communication.rsp.*
internal fun WristbandSession.readSettings(m:String,done:(JSONObject?,BaseRspCmd?,JSONObject?)->Unit) {
    val req:BaseReqCmd=when(m){"heartRate"->HeartRateSettingReq.getReadInstance();"bloodOxygen"->BloodOxygenSettingReq.getReadInstance();"hrv"->HrvSettingReq.getReadInstance();"stress"->PressureSettingReq.getReadInstance();else->{done(null,null,error("UNSUPPORTED","No settings for metric"));return}}
    request(req){rsp,e->if(e!=null){done(null,null,e);return@request}
        val values=when(rsp){
            is HeartRateSettingRsp->json("enabled" to rsp.isEnable,"intervalMinutes" to rsp.heartInterval)
            is BloodOxygenSettingRsp->json("enabled" to rsp.isEnable,"intervalMinutes" to (rsp.interval.toInt() and 255))
            is HRVSettingRsp->json("enabled" to rsp.isEnable)
            is PressureSettingRsp->json("enabled" to rsp.isEnable).apply{if(rsp.isIntervalSettingSupported){put("intervalMinutes",rsp.interval);put("min",rsp.minInterval)}}
            else->{done(null,null,error("SDK_ERROR","Unexpected setting response"));return@request}
        }
        if(values.optInt("intervalMinutes",0)>0)settingMetadata[m]=json("support" to "supported","readable" to true,"writable" to true,"min" to values.optInt("min",1),"max" to 255,"step" to 1)
        done(values,rsp,null)
    }
}
internal fun WristbandSession.publicSettings(m:String,v:JSONObject)=json("metric" to m,"enabled" to v.opt("enabled"),"intervalMinutes" to v.opt("intervalMinutes"),"source" to "device","readAt" to System.currentTimeMillis(),"capabilities" to metricCapability(m).getJSONObject("settings"))
internal fun WristbandSession.settings(m:String,patch:JSONObject?,done:Reply) {
    val state=metricCapability(m).getJSONObject("settings").getJSONObject("enabled").getString("support")
    if(state!="supported"){done(null,error(if(state=="unknown")"CAPABILITY_UNKNOWN" else "UNSUPPORTED","Automatic measurement support unavailable"));return}
    readSettings(m){values,raw,e->if(e!=null){done(null,e);return@readSettings};val v=values!!
        if(patch==null){done(publicSettings(m,v),null);return@readSettings}
        val invalid=Policy.patchError(patch);if(invalid!=null){done(null,error("INVALID_ARGUMENT",invalid));return@readSettings}
        val enabled=if(patch.has("enabled"))patch.getBoolean("enabled")else v.getBoolean("enabled")
        val interval=if(patch.has("intervalMinutes"))patch.getInt("intervalMinutes")else v.optInt("intervalMinutes",0)
        if(patch.has("intervalMinutes") && (settingMetadata[m]?.optBoolean("writable")!=true || interval<v.optInt("min",1)||interval>255)){done(null,error("INVALID_ARGUMENT","Interval unsupported or outside verified bounds"));return@readSettings}
        val req:BaseReqCmd=when(raw){
            is HeartRateSettingRsp->HeartRateSettingReq.getWriteInstance(enabled,interval,raw.startInterval,raw.tooLowReminder,raw.tooHighReminder,raw.mainSwitch!=0)
            is BloodOxygenSettingRsp->BloodOxygenSettingReq.getWriteInstance(enabled,interval.toByte())
            is HRVSettingRsp->HrvSettingReq.getWriteInstance(enabled)
            is PressureSettingRsp->if(raw.isIntervalSettingSupported)PressureSettingReq.getWriteInstance(enabled,interval)else PressureSettingReq.getWriteInstance(enabled)
            else->{done(null,error("UNSUPPORTED","Cannot preserve vendor fields"));return@readSettings}
        }
        request(req){_,writeError->if(writeError!=null){done(null,writeError);return@request}
            writeAcknowledged=true
            readSettings(m){actual,_,readError->if(readError!=null || actual==null || !Policy.verificationMatches(patch,actual))done(null,error("WRITE_VERIFICATION_FAILED","Write acknowledged; read-back failed or differs from patch").put("writeAcknowledged",true))else done(json("verification" to "readBack","settings" to publicSettings(m,actual!!)),null)}
        }
    }
}
