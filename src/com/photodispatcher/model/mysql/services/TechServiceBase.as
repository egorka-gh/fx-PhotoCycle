/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (TechService.as).
 */

package com.photodispatcher.model.mysql.services {

    import com.photodispatcher.model.mysql.entities.DmlResult;
    import com.photodispatcher.model.mysql.entities.SelectResult;
    import com.photodispatcher.model.mysql.entities.SqlResult;
    import com.photodispatcher.model.mysql.entities.TechLog;
    import flash.utils.flash_proxy;
    import mx.rpc.AsyncToken;
    import org.granite.tide.BaseContext;
    import org.granite.tide.Component;
    import org.granite.tide.ITideResponder;
    
    use namespace flash_proxy;

    public class TechServiceBase extends Component {

        public function TechServiceBase() {
            super();
        }
    
        
        public function loadBooks4Otk(arg0:String, arg1:String, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("loadBooks4Otk", arg0, arg1, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("loadBooks4Otk", arg0, arg1, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("loadBooks4Otk", arg0, arg1) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function loadTechPulse(arg0:int, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("loadTechPulse", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("loadTechPulse", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("loadTechPulse", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function log(arg0:TechLog, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("log", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("log", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("log", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function logByPg(arg0:TechLog, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("logByPg", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("logByPg", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("logByPg", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }
    }
}
