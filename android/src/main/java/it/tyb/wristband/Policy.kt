package it.tyb.wristband
import org.json.JSONObject
internal object Policy {
    val metrics=listOf("heartRate","bloodOxygen","hrv","stress","steps","sleep")
    fun validWindow(start:Int,days:Int)=start>=0 && days>=1 && start<=6 && days<=7-start
    fun patchError(p:JSONObject?):String? {
        if(p==null || p.length()==0)return "Patch must not be empty"
        for(k in p.keys())if(k !in listOf("enabled","intervalMinutes"))return "Unknown setting"
        if(p.has("enabled") && p.opt("enabled") !is Boolean)return "enabled must be boolean"
        if(p.has("intervalMinutes")) {val n=p.opt("intervalMinutes");if(n !is Number || !n.toDouble().isFinite() || n.toDouble()<1 || n.toDouble()%1.0!=0.0)return "intervalMinutes must be a positive integer"}
        return null
    }
    fun failedHistory(jobs:List<Pair<String,String>>,batches:org.json.JSONArray,operation:String,device:String,e:JSONObject):JSONObject {
        val all=org.json.JSONArray(batches.toString())
        for(i in all.length() until jobs.size)all.put(json("operationId" to operation,"deviceId" to device,"batchIndex" to i,"metric" to jobs[i].first,"date" to jobs[i].second,"status" to "error","records" to org.json.JSONArray(),"error" to e))
        val successes=(0 until all.length()).count{all.getJSONObject(it).optString("status")=="success"}
        return json("operationId" to operation,"deviceId" to device,"status" to if(successes>0)"partial"else "failed","batches" to all)
    }
    fun verificationMatches(patch:JSONObject,actual:JSONObject)=patch.keys().asSequence().all{patch.opt(it)==actual.opt(it)}
    fun dayIndex(date:java.time.LocalDate,today:java.time.LocalDate):Int?=java.time.temporal.ChronoUnit.DAYS.between(date,today).toInt().takeIf{it in 0..6}
    fun unit(m:String)=when(m){"heartRate"->"bpm";"bloodOxygen"->"%";else->"vendor"}
}
internal fun json(vararg pairs:Pair<String,Any?>)=JSONObject().apply { for((k,v) in pairs)if(v!=null)put(k,v) }
internal fun error(code:String,message:String)=json("code" to code,"message" to message)
internal typealias Reply=(JSONObject?,JSONObject?)->Unit
