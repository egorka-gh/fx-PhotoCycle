/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (SqlResult.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;
    import flash.utils.IExternalizable;
    import org.granite.tide.IPropertyHolder;

    [Bindable]
    public class SqlResultBase implements IExternalizable {

        private var _complete:Boolean;
        private var _errCode:int;
        private var _errMesage:String;
        private var _resultCode:int;
        private var _sql:String;

        public function set complete(value:Boolean):void {
            _complete = value;
        }
        public function get complete():Boolean {
            return _complete;
        }

        public function set errCode(value:int):void {
            _errCode = value;
        }
        public function get errCode():int {
            return _errCode;
        }

        public function set errMesage(value:String):void {
            _errMesage = value;
        }
        public function get errMesage():String {
            return _errMesage;
        }

        public function set resultCode(value:int):void {
            _resultCode = value;
        }
        public function get resultCode():int {
            return _resultCode;
        }

        public function set sql(value:String):void {
            _sql = value;
        }
        public function get sql():String {
            return _sql;
        }

        public function readExternal(input:IDataInput):void {
            _complete = input.readObject() as Boolean;
            _errCode = input.readObject() as int;
            _errMesage = input.readObject() as String;
            _resultCode = input.readObject() as int;
            _sql = input.readObject() as String;
        }

        public function writeExternal(output:IDataOutput):void {
            output.writeObject((_complete is IPropertyHolder) ? IPropertyHolder(_complete).object : _complete);
            output.writeObject((_errCode is IPropertyHolder) ? IPropertyHolder(_errCode).object : _errCode);
            output.writeObject((_errMesage is IPropertyHolder) ? IPropertyHolder(_errMesage).object : _errMesage);
            output.writeObject((_resultCode is IPropertyHolder) ? IPropertyHolder(_resultCode).object : _resultCode);
            output.writeObject((_sql is IPropertyHolder) ? IPropertyHolder(_sql).object : _sql);
        }
    }
}