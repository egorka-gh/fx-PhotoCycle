/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (MailPackageProperty.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;

    [Bindable]
    public class MailPackagePropertyBase extends AbstractEntity {

        public function MailPackagePropertyBase() {
            super();
        }

        private var _id:int;
        private var _property:String;
        private var _property_name:String;
        private var _source:int;
        private var _source_name:String;
        private var _value:String;

        public function set id(value:int):void {
            _id = value;
        }
        public function get id():int {
            return _id;
        }

        public function set property(value:String):void {
            _property = value;
        }
        public function get property():String {
            return _property;
        }

        public function set property_name(value:String):void {
            _property_name = value;
        }
        public function get property_name():String {
            return _property_name;
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

        public function set value(value:String):void {
            _value = value;
        }
        public function get value():String {
            return _value;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _id = input.readObject() as int;
            _property = input.readObject() as String;
            _property_name = input.readObject() as String;
            _source = input.readObject() as int;
            _source_name = input.readObject() as String;
            _value = input.readObject() as String;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject(_id);
            output.writeObject(_property);
            output.writeObject(_property_name);
            output.writeObject(_source);
            output.writeObject(_source_name);
            output.writeObject(_value);
        }
    }
}