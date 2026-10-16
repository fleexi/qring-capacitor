package it.tyb.wristband
import java.util.UUID
internal class OperationGate {
    var token:String?=null; private set
    fun begin():String? { if(token!=null)return null;return UUID.randomUUID().toString().also { token=it } }
    fun current(id:String?)= id!=null && token==id
    fun finish(id:String?):Boolean { if(!current(id))return false;token=null;return true }
    fun invalidate() { token=null }
}
