/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (TechPoint.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;

    [Bindable]
    public class TechPointBase extends AbstractEntity {

        public function TechPointBase() {
            super();
        }

        private var _id:int;
        private var _name:String;
        private var _tech_book_part:int;
        private var _tech_type:int;
        private var _tech_type_name:String;

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

        public function set tech_book_part(value:int):void {
            _tech_book_part = value;
        }
        public function get tech_book_part():int {
            return _tech_book_part;
        }

        public function set tech_type(value:int):void {
            _tech_type = value;
        }
        public function get tech_type():int {
            return _tech_type;
        }

        public function set tech_type_name(value:String):void {
            _tech_type_name = value;
        }
        public function get tech_type_name():String {
            return _tech_type_name;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _id = input.readObject() as int;
            _name = input.readObject() as String;
            _tech_book_part = input.readObject() as int;
            _tech_type = input.readObject() as int;
            _tech_type_name = input.readObject() as String;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject(_id);
            output.writeObject(_name);
            output.writeObject(_tech_book_part);
            output.writeObject(_tech_type);
            output.writeObject(_tech_type_name);
        }
    }
}