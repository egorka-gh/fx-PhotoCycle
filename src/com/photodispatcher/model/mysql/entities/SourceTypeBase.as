/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (SourceType.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;

    [Bindable]
    public class SourceTypeBase extends AbstractEntity {

        public function SourceTypeBase() {
            super();
        }

        private var _book_part:int;
        private var _id:int;
        private var _loc_type:int;
        private var _name:String;
        private var _state:int;

        public function set book_part(value:int):void {
            _book_part = value;
        }
        public function get book_part():int {
            return _book_part;
        }

        public function set id(value:int):void {
            _id = value;
        }
        public function get id():int {
            return _id;
        }

        public function set loc_type(value:int):void {
            _loc_type = value;
        }
        public function get loc_type():int {
            return _loc_type;
        }

        public function set name(value:String):void {
            _name = value;
        }
        public function get name():String {
            return _name;
        }

        public function set state(value:int):void {
            _state = value;
        }
        public function get state():int {
            return _state;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _book_part = input.readObject() as int;
            _id = input.readObject() as int;
            _loc_type = input.readObject() as int;
            _name = input.readObject() as String;
            _state = input.readObject() as int;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject(_book_part);
            output.writeObject(_id);
            output.writeObject(_loc_type);
            output.writeObject(_name);
            output.writeObject(_state);
        }
    }
}