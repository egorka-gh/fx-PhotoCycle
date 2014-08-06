/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (TechPickerService.as).
 */

package com.photodispatcher.model.mysql.services {

    import flash.utils.flash_proxy;
    import mx.collections.ListCollectionView;
    import mx.rpc.AsyncToken;
    import org.granite.tide.BaseContext;
    import org.granite.tide.Component;
    import org.granite.tide.ITideResponder;
    
    use namespace flash_proxy;

    public class TechPickerServiceBase extends Component {    
        
        public function loadLayersetGroups(resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("loadLayersetGroups", resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("loadLayersetGroups", resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("loadLayersetGroups") as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function persistLayersetGroups(arg0:ListCollectionView, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("persistLayersetGroups", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("persistLayersetGroups", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("persistLayersetGroups", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }
    }
}
