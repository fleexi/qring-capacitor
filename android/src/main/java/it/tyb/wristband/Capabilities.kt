package it.tyb.wristband
import org.json.JSONObject
internal fun WristbandSession.metricCapability(m:String):JSONObject {
    val ready=connection=="ready";val t=time;val d=support
    val supported=when(m){"heartRate","steps","sleep"->true;"bloodOxygen"->t?.supportsBloodOxygen()==true || d?.supportIntervalBloodOxygen==true;"hrv"->t?.supportsHrv()==true;"stress"->t?.supportsPressure()==true;else->false}
    val state=if(!ready)"unknown" else if(supported)"supported" else "unsupported"
    fun op(s:String)=json("support" to s,"reason" to "SDK and device feature flags")
    val numeric=m !in listOf("steps","sleep")
    val settingsState=if(numeric)state else "unsupported"
    val enabled=json("support" to settingsState,"readable" to numeric,"writable" to numeric)
    val interval=if(!numeric || m=="hrv")json("support" to "unsupported","readable" to false,"writable" to false)else settingMetadata[m]?:json("support" to "unknown","readable" to false,"writable" to false)
    return json("history" to op(state),"settings" to json("enabled" to enabled,"intervalMinutes" to interval))
}
internal fun WristbandSession.capabilities()=json("metrics" to JSONObject().apply{Policy.metrics.forEach{put(it,metricCapability(it))}})
