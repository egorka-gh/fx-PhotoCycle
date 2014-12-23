/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (DictionaryService.as).
 */

package com.photodispatcher.model.mysql.services {

    import com.photodispatcher.model.mysql.entities.SelectResult;
    import flash.utils.flash_proxy;
    import mx.rpc.AsyncToken;
    import org.granite.tide.BaseContext;
    import org.granite.tide.Component;
    import org.granite.tide.ITideResponder;
    
    use namespace flash_proxy;

    public class DictionaryServiceBase extends Component {

        public function DictionaryServiceBase() {
            super();
        }
    
        
        public function getBookPartValueList(arg0:Boolean, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("getBookPartValueList", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("getBookPartValueList", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("getBookPartValueList", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function getBookSynonimTypeValueList(resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("getBookSynonimTypeValueList", resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("getBookSynonimTypeValueList", resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("getBookSynonimTypeValueList") as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function getBookTypeValueList(arg0:Boolean, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("getBookTypeValueList", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("getBookTypeValueList", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("getBookTypeValueList", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function getFieldValueList(arg0:int, arg1:Boolean, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("getFieldValueList", arg0, arg1, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("getFieldValueList", arg0, arg1, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("getFieldValueList", arg0, arg1) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function getFieldValueSynonims(resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("getFieldValueSynonims", resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("getFieldValueSynonims", resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("getFieldValueSynonims") as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function getLayerGroupValueList(arg0:Boolean, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("getLayerGroupValueList", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("getLayerGroupValueList", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("getLayerGroupValueList", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function getOrderJsonAttr(arg0:int, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("getOrderJsonAttr", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("getOrderJsonAttr", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("getOrderJsonAttr", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function getPrintAttrs(resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("getPrintAttrs", resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("getPrintAttrs", resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("getPrintAttrs") as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function getRollValueList(arg0:Boolean, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("getRollValueList", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("getRollValueList", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("getRollValueList", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function getSrcTypeValueList(arg0:int, arg1:Boolean, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("getSrcTypeValueList", arg0, arg1, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("getSrcTypeValueList", arg0, arg1, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("getSrcTypeValueList", arg0, arg1) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function getTechLayerValueList(arg0:Boolean, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("getTechLayerValueList", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("getTechLayerValueList", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("getTechLayerValueList", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function getTechPointValueList(arg0:Boolean, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("getTechPointValueList", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("getTechPointValueList", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("getTechPointValueList", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function getTechTypeValueList(resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("getTechTypeValueList", resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("getTechTypeValueList", resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("getTechTypeValueList") as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function getWeekDaysValueList(arg0:Boolean, resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("getWeekDaysValueList", arg0, resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("getWeekDaysValueList", arg0, resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("getWeekDaysValueList", arg0) as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function loadSourceProperties(resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("loadSourceProperties", resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("loadSourceProperties", resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("loadSourceProperties") as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }    
        
        public function loadSubordersTemplate(resultHandler:Object = null, faultHandler:Function = null):AsyncToken {
            if (faultHandler != null)
                return callProperty("loadSubordersTemplate", resultHandler, faultHandler) as AsyncToken;
            else if (resultHandler is Function || resultHandler is ITideResponder)
                return callProperty("loadSubordersTemplate", resultHandler) as AsyncToken;
            else if (resultHandler == null)
                return callProperty("loadSubordersTemplate") as AsyncToken;
            else
                throw new Error("Illegal argument to remote call (last argument should be Function or ITideResponder): " + resultHandler);
        }
    }
}
