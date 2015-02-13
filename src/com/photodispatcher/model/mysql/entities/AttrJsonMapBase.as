/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (AttrJsonMap.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;
    import org.granite.tide.IPropertyHolder;

    [Bindable]
    public class AttrJsonMapBase extends AbstractEntity {

        public function AttrJsonMapBase() {
            super();
        }

        private var _attr_type:int;
        private var _field:String;
        private var _field_name:String;
        private var _json_key:String;
        private var _list:Boolean;
        private var _persist:Boolean;
        private var _src_type:int;

        public function set attr_type(value:int):void {
            _attr_type = value;
        }
        public function get attr_type():int {
            return _attr_type;
        }

        public function set field(value:String):void {
            _field = value;
        }
        public function get field():String {
            return _field;
        }

        public function set field_name(value:String):void {
            _field_name = value;
        }
        public function get field_name():String {
            return _field_name;
        }

        public function set json_key(value:String):void {
            _json_key = value;
        }
        public function get json_key():String {
            return _json_key;
        }

        public function set list(value:Boolean):void {
            _list = value;
        }
        public function get list():Boolean {
            return _list;
        }

        public function set persist(value:Boolean):void {
            _persist = value;
        }
        public function get persist():Boolean {
            return _persist;
        }

        public function set src_type(value:int):void {
            _src_type = value;
        }
        public function get src_type():int {
            return _src_type;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _attr_type = input.readObject() as int;
            _field = input.readObject() as String;
            _field_name = input.readObject() as String;
            _json_key = input.readObject() as String;
            _list = input.readObject() as Boolean;
            _persist = input.readObject() as Boolean;
            _src_type = input.readObject() as int;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject((_attr_type is IPropertyHolder) ? IPropertyHolder(_attr_type).object : _attr_type);
            output.writeObject((_field is IPropertyHolder) ? IPropertyHolder(_field).object : _field);
            output.writeObject((_field_name is IPropertyHolder) ? IPropertyHolder(_field_name).object : _field_name);
            output.writeObject((_json_key is IPropertyHolder) ? IPropertyHolder(_json_key).object : _json_key);
            output.writeObject((_list is IPropertyHolder) ? IPropertyHolder(_list).object : _list);
            output.writeObject((_persist is IPropertyHolder) ? IPropertyHolder(_persist).object : _persist);
            output.writeObject((_src_type is IPropertyHolder) ? IPropertyHolder(_src_type).object : _src_type);
        }
    }
}