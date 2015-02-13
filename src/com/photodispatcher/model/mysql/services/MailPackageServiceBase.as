/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (MailPackageService.as).
 */

package com.photodispatcher.model.mysql.services {

    import com.photodispatcher.model.mysql.entities.MailPackage;
    import com.photodispatcher.model.mysql.entities.SelectResult;
    import com.photodispatcher.model.mysql.entities.SqlResult;
    import flash.utils.flash_proxy;
    import mx.rpc.AsyncToken;
    import org.granite.tide.BaseContext;
    import org.granite.tide.Component;
    import org.granite.tide.ITideResponder;
    
    use namespace flash_proxy;

    public class MailPackageServiceBase extends Component {

        public function MailPackageServiceBase() {
            super();
        }
    
        
        public function loadReady4Mail(resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("loadReady4Mail", resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("loadReady4Mail", resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("loadReady4Mail") as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function persist(arg0:MailPackage, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("persist", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("persist", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("persist", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }
    }
}
