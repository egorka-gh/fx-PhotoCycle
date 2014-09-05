/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.services {
	import com.photodispatcher.model.mysql.entities.StateLog;
	
	import mx.rpc.AsyncToken;

    [RemoteClass(alias="com.photodispatcher.model.mysql.services.OrderStateService")]
    public class OrderStateService extends OrderStateServiceBase {
		
		override public function logState(arg0:StateLog, resultHandler:Object=null, faultHandler:Function=null):AsyncToken{
			if(!arg0) return null;
			if(arg0.comment && arg0.comment.length>250) arg0.comment=arg0.comment.substr(0,250);
			return super.logState(arg0, resultHandler, faultHandler);
		}
		
	}
    
}
