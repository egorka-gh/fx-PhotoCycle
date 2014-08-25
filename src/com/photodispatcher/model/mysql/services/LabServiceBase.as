/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (LabService.as).
 */

package com.photodispatcher.model.mysql.services {

    import com.photodispatcher.model.mysql.entities.Lab;
    import com.photodispatcher.model.mysql.entities.LabDevice;
    import flash.utils.flash_proxy;
    import mx.collections.ListCollectionView;
    import mx.rpc.AsyncToken;
    import org.granite.tide.BaseContext;
    import org.granite.tide.Component;
    import org.granite.tide.ITideResponder;
    
    use namespace flash_proxy;

    public class LabServiceBase extends Component {    
        
        public function loadAll(arg0:Boolean, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("loadAll", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("loadAll", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("loadAll", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function loadList(resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("loadList", resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("loadList", resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("loadList") as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function loadPrintCode(arg0:int, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("loadPrintCode", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("loadPrintCode", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("loadPrintCode", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function persistPrintCodes(arg0:ListCollectionView, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("persistPrintCodes", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("persistPrintCodes", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("persistPrintCodes", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function loadLab(arg0:int, arg1:Boolean, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("loadLab", arg0, arg1, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("loadLab", arg0, arg1, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("loadLab", arg0, arg1) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function persistLab(arg0:Lab, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("persistLab", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("persistLab", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("persistLab", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function addDevice(arg0:LabDevice, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("addDevice", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("addDevice", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("addDevice", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function delDevice(arg0:int, arg1:int, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("delDevice", arg0, arg1, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("delDevice", arg0, arg1, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("delDevice", arg0, arg1) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function getLastPGroupByTPoint(arg0:int, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("getLastPGroupByTPoint", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("getLastPGroupByTPoint", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("getLastPGroupByTPoint", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }
    }
}
