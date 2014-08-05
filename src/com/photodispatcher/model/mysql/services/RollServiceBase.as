/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (RollService.as).
 */

package com.photodispatcher.model.mysql.services {

    import flash.utils.flash_proxy;
    import mx.collections.ListCollectionView;
    import mx.rpc.AsyncToken;
    import org.granite.tide.BaseContext;
    import org.granite.tide.Component;
    import org.granite.tide.ITideResponder;
    
    use namespace flash_proxy;

    public class RollServiceBase extends Component {    
        
        public function loadAll(resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("loadAll", resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("loadAll", resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("loadAll") as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function persistBatch(arg0:ListCollectionView, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("persistBatch", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("persistBatch", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("persistBatch", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function getByDevice(arg0:int, arg1:Boolean, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("getByDevice", arg0, arg1, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("getByDevice", arg0, arg1, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("getByDevice", arg0, arg1) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function fillByChannels(arg0:int, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("fillByChannels", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("fillByChannels", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("fillByChannels", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }
    }
}
