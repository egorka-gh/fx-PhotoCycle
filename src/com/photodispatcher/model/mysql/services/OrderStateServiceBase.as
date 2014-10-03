/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (OrderStateService.as).
 */

package com.photodispatcher.model.mysql.services {

    import com.photodispatcher.model.mysql.entities.StateLog;
    import flash.utils.flash_proxy;
    import mx.rpc.AsyncToken;
    import org.granite.tide.BaseContext;
    import org.granite.tide.Component;
    import org.granite.tide.ITideResponder;
    
    use namespace flash_proxy;

    public class OrderStateServiceBase extends Component {    
        
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
        
        public function extraStateProlong(arg0:String, arg1:String, arg2:int, arg3:String, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("extraStateProlong", arg0, arg1, arg2, arg3, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("extraStateProlong", arg0, arg1, arg2, arg3, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("extraStateProlong", arg0, arg1, arg2, arg3) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function logState(arg0:StateLog, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("logState", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("logState", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("logState", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function logStateByPGroup(arg0:String, arg1:int, arg2:String, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("logStateByPGroup", arg0, arg1, arg2, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("logStateByPGroup", arg0, arg1, arg2, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("logStateByPGroup", arg0, arg1, arg2) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function loadStateLogs(arg0:Date, arg1:Boolean, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("loadStateLogs", arg0, arg1, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("loadStateLogs", arg0, arg1, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("loadStateLogs", arg0, arg1) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function extraStateStart(arg0:String, arg1:String, arg2:int, arg3:Date, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("extraStateStart", arg0, arg1, arg2, arg3, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("extraStateStart", arg0, arg1, arg2, arg3, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("extraStateStart", arg0, arg1, arg2, arg3) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function extraStateSet(arg0:String, arg1:String, arg2:int, arg3:Date, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("extraStateSet", arg0, arg1, arg2, arg3, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("extraStateSet", arg0, arg1, arg2, arg3, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("extraStateSet", arg0, arg1, arg2, arg3) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function extraStateReset(arg0:String, arg1:String, arg2:int, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("extraStateReset", arg0, arg1, arg2, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("extraStateReset", arg0, arg1, arg2, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("extraStateReset", arg0, arg1, arg2) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function printPost(arg0:String, arg1:int, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("printPost", arg0, arg1, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("printPost", arg0, arg1, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("printPost", arg0, arg1) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function printEndManual(arg0:Array, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("printEndManual", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("printEndManual", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("printEndManual", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function printCancel(arg0:Array, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("printCancel", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("printCancel", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("printCancel", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function printGroupMarkInPrint(arg0:String, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("printGroupMarkInPrint", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("printGroupMarkInPrint", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("printGroupMarkInPrint", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function loadMonitorEState(arg0:int, arg1:int, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("loadMonitorEState", arg0, arg1, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("loadMonitorEState", arg0, arg1, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("loadMonitorEState", arg0, arg1) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function extraStateStartMonitor(arg0:String, arg1:String, arg2:int, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("extraStateStartMonitor", arg0, arg1, arg2, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("extraStateStartMonitor", arg0, arg1, arg2, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("extraStateStartMonitor", arg0, arg1, arg2) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function extraStateStartOTK(arg0:String, arg1:String, arg2:int, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("extraStateStartOTK", arg0, arg1, arg2, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("extraStateStartOTK", arg0, arg1, arg2, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("extraStateStartOTK", arg0, arg1, arg2) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function loadSpyData(arg0:Date, arg1:int, arg2:int, arg3:int, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("loadSpyData", arg0, arg1, arg2, arg3, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("loadSpyData", arg0, arg1, arg2, arg3, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("loadSpyData", arg0, arg1, arg2, arg3) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }
    }
}
