/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (Rack.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;

    [Bindable]
    public class RackBase extends AbstractEntity {

        public function RackBase() {
            super();
        }

        private var _id:int;
        private var _name:String;
        private var _rack_type:int;
        private var _rack_type_name:String;

        public function set id(value:int):void {
            _id = value;
        }
        public function get id():int {
            return _id;
        }

        public function set name(value:String):void {
            _name = value;
        }
        public function get name():String {
            return _name;
        }

        public function set rack_type(value:int):void {
            _rack_type = value;
        }
        public function get rack_type():int {
            return _rack_type;
        }

        public function set rack_type_name(value:String):void {
            _rack_type_name = value;
        }
        public function get rack_type_name():String {
            return _rack_type_name;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _id = input.readObject() as int;
            _name = input.readObject() as String;
            _rack_type = input.readObject() as int;
            _rack_type_name = input.readObject() as String;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject(_id);
            output.writeObject(_name);
            output.writeObject(_rack_type);
            output.writeObject(_rack_type_name);
        }
    }
}