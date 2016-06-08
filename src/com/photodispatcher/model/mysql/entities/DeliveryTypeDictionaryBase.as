/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (DeliveryTypeDictionary.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;

    [Bindable]
    public class DeliveryTypeDictionaryBase extends AbstractEntity {

        public function DeliveryTypeDictionaryBase() {
            super();
        }

        private var _delivery_type:int;
        private var _delivery_type_name:String;
        private var _site_id:int;
        private var _source:int;
        private var _source_name:String;

        public function set delivery_type(value:int):void {
            _delivery_type = value;
        }
        public function get delivery_type():int {
            return _delivery_type;
        }

        public function set delivery_type_name(value:String):void {
            _delivery_type_name = value;
        }
        public function get delivery_type_name():String {
            return _delivery_type_name;
        }

        public function set site_id(value:int):void {
            _site_id = value;
        }
        public function get site_id():int {
            return _site_id;
        }

        public function set source(value:int):void {
            _source = value;
        }
        public function get source():int {
            return _source;
        }

        public function set source_name(value:String):void {
            _source_name = value;
        }
        public function get source_name():String {
            return _source_name;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _delivery_type = input.readObject() as int;
            _delivery_type_name = input.readObject() as String;
            _site_id = input.readObject() as int;
            _source = input.readObject() as int;
            _source_name = input.readObject() as String;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject(_delivery_type);
            output.writeObject(_delivery_type_name);
            output.writeObject(_site_id);
            output.writeObject(_source);
            output.writeObject(_source_name);
        }
    }
}