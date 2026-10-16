package it.tyb.wristband
import org.json.*
import com.oudmon.ble.base.bluetooth.BleOperateManager
import com.oudmon.ble.base.communication.rsp.*
import com.oudmon.ble.base.communication.bigData.*
import com.oudmon.ble.base.communication.bigData.bean.IntervalTemperatureEntity
import com.oudmon.ble.base.communication.entity.BleStepDetails
import com.oudmon.ble.base.bean.SleepDisplay
import java.time.LocalDate
internal fun numericRecords(values:List<Number>?,metric:String,date:String,interval:Int=0):JSONArray=JSONArray().apply{
    values?.forEachIndexed{i,v->if(v.toDouble().isFinite()&&v.toDouble()>0)put(json("metric" to metric,"date" to date,"source" to "scheduled","value" to v,"unit" to Policy.unit(metric),"sampleIndex" to i,"intervalMinutes" to interval.takeIf{it>0}))}
}
internal fun WristbandSession.readDay(m:String,day:Int,date:String,done:Reply){
    val state=metricCapability(m).getJSONObject("history").getString("support");if(state!="supported"){done(null,error(if(state=="unknown")"CAPABILITY_UNKNOWN"else "UNSUPPORTED","History support unavailable"));return}
    if(day !in 0..6){done(null,error("INVALID_ARGUMENT","Frozen date outside device retention"));return}
    val reply=once(done)
    fun <T> callback(mapper:(T)->JSONArray)=object:BleOperateManager.HealthDataCallback<T>{
        override fun onSuccess(data:T){main.post{try{reply(json("records" to mapper(data)),null)}catch(e:Exception){reply(null,error("SDK_ERROR","Malformed history: ${e.message}"))}}}
        override fun onError(code:Int,message:String?){reply(null,error("SDK_ERROR",message?:"History failed").put("vendorCode",code.toString()))}
    }
    when(m){
        "heartRate"->ble.getHeartRate(day,callback<ReadHeartRateRsp>{r->numericRecords(r.array?:r.getmHeartRateArray()?.map{it.toInt() and 255},m,date,r.interval)})
        "bloodOxygen"->ble.getBloodOxygen(day,callback<BloodOxygenEntity>{r->numericRecords(r.array,m,date,r.interval)})
        "temperature"->ble.getTemperature(day,callback<IntervalTemperatureEntity>{r->numericRecords(r.array,m,date,r.interval)})
        "hrv"->ble.getHrv(day,callback<HRVRsp>{r->numericRecords(r.array?:r.hrvArray?.map{it.toInt() and 255},m,date)})
        "stress"->ble.getPressure(day,callback<PressureRsp>{r->numericRecords(r.array?:r.pressureArray?.map{it.toInt() and 255},m,date)})
        "steps"->ble.getStepDetail(day,callback<List<BleStepDetails>>{values->JSONArray().apply{values.forEach{r->put(json("metric" to m,"date" to date,"source" to "scheduled","steps" to r.walkSteps,"distanceMeters" to r.distance,"sampleIndex" to r.timeIndex,"intervalMinutes" to 15))}}})
        "sleep"->ble.getSleep(day,callback<SleepDisplay>{r->JSONArray().apply{
            fun add(phases:List<SleepDisplay.SleepDataBean>?,nap:Boolean){if(phases.isNullOrEmpty())return
                val p=JSONArray();for(v in phases){val stage=when(v.type){1->"awake";2->"light";4->"rem";5->"deep";else->"unknown"};p.put(json("stage" to stage,"vendorStage" to v.type,"start" to v.sleepStart*1000,"end" to v.sleepEnd*1000,"durationSeconds" to (v.sleepEnd-v.sleepStart).coerceAtLeast(0)))}
                put(json("metric" to "sleep","date" to date,"source" to "scheduled","nap" to nap,"start" to phases.minOf{it.sleepStart}*1000,"end" to phases.maxOf{it.sleepEnd}*1000,"durationSeconds" to phases.sumOf{(it.sleepEnd-it.sleepStart).coerceAtLeast(0)},"phases" to p))
            };add(r.list,false);add(r.napList,true)
        }})
    }
}
internal fun WristbandSession.history(metrics:List<String>,start:Int,days:Int){
    val anchor=LocalDate.now();val token=gate.token!!;val device=deviceId!!;val batches=JSONArray()
    val jobs=metrics.flatMap{m->(start until start+days).map{d->Triple(m,d,anchor.minusDays(d.toLong()).toString())}}
    historyFailure={e->Policy.failedHistory(jobs.map{it.first to it.third},batches,token,device,e)}
    fun next(index:Int){
        if(!gate.current(token))return
        if(index==jobs.size){val errors=(0 until batches.length()).count{batches.getJSONObject(it).getString("status")=="error"};complete(json("operationId" to token,"deviceId" to device,"status" to if(errors==0)"success"else if(errors==batches.length())"failed"else "partial","batches" to batches));return}
        val(m,day,date)=jobs[index]
        val adjusted=Policy.dayIndex(LocalDate.parse(date),LocalDate.now())?:-1
        readDay(m,adjusted,date){result,e->val b=json("operationId" to token,"deviceId" to device,"batchIndex" to index,"metric" to m,"date" to date,"status" to if(e==null)"success"else "error","records" to (result?.optJSONArray("records")?:JSONArray()),"error" to e)
            batches.put(b);emit("historyBatch",b);emit("syncProgress",json("operationId" to token,"deviceId" to device,"completed" to index+1,"total" to jobs.size));next(index+1)
        }
    };next(0)
}
