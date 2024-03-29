/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (StateLog.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;

    [Bindable]
    public class StateLogBase extends AbstractEntity {

        public function StateLogBase() {
            super();
        }

        private var _comment:String;
        private var _id:int;
        private var _order_id:String;
        private var _pg_id:String;
        private var _state:int;
        private var _state_date:Date;
        private var _state_name:String;
        private var _sub_id:String;

        public function set comment(value:String):void {
            _comment = value;
        }
        public function get comment():String {
            return _comment;
        }

        public function set id(value:int):void {
            _id = value;
        }
        public function get id():int {
            return _id;
        }

        public function set order_id(value:String):void {
            _order_id = value;
        }
        public function get order_id():String {
            return _order_id;
        }

        public function set pg_id(value:String):void {
            _pg_id = value;
        }
        public function get pg_id():String {
            return _pg_id;
        }

        public function set state(value:int):void {
            _state = value;
        }
        public function get state():int {
            return _state;
        }

        public function set state_date(value:Date):void {
            _state_date = value;
        }
        public function get state_date():Date {
            return _state_date;
        }

        public function set state_name(value:String):void {
            _state_name = value;
        }
        public function get state_name():String {
            return _state_name;
        }

        public function set sub_id(value:String):void {
            _sub_id = value;
        }
        public function get sub_id():String {
            return _sub_id;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _comment = input.readObject() as String;
            _id = input.readObject() as int;
            _order_id = input.readObject() as String;
            _pg_id = input.readObject() as String;
            _state = input.readObject() as int;
            _state_date = input.readObject() as Date;
            _state_name = input.readObject() as String;
            _sub_id = input.readObject() as String;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject(_comment);
            output.writeObject(_id);
            output.writeObject(_order_id);
            output.writeObject(_pg_id);
            output.writeObject(_state);
            output.writeObject(_state_date);
            output.writeObject(_state_name);
            output.writeObject(_sub_id);
        }
    }
}