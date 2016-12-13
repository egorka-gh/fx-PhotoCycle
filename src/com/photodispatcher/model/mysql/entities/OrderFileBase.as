/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (OrderFile.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;

    [Bindable]
    public class OrderFileBase extends AbstractEntity {

        public function OrderFileBase() {
            super();
        }

        private var _file_name:String;
        private var _hash_local:String;
        private var _hash_remote:String;
        private var _order_id:String;
        private var _previous_state:int;
        private var _previous_state_name:String;
        private var _size:int;
        private var _state:int;
        private var _state_date:Date;
        private var _state_name:String;

        public function set file_name(value:String):void {
            _file_name = value;
        }
        public function get file_name():String {
            return _file_name;
        }

        public function set hash_local(value:String):void {
            _hash_local = value;
        }
        public function get hash_local():String {
            return _hash_local;
        }

        public function set hash_remote(value:String):void {
            _hash_remote = value;
        }
        public function get hash_remote():String {
            return _hash_remote;
        }

        public function set order_id(value:String):void {
            _order_id = value;
        }
        public function get order_id():String {
            return _order_id;
        }

        public function set previous_state(value:int):void {
            _previous_state = value;
        }
        public function get previous_state():int {
            return _previous_state;
        }

        public function set previous_state_name(value:String):void {
            _previous_state_name = value;
        }
        public function get previous_state_name():String {
            return _previous_state_name;
        }

        public function set size(value:int):void {
            _size = value;
        }
        public function get size():int {
            return _size;
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

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _file_name = input.readObject() as String;
            _hash_local = input.readObject() as String;
            _hash_remote = input.readObject() as String;
            _order_id = input.readObject() as String;
            _previous_state = input.readObject() as int;
            _previous_state_name = input.readObject() as String;
            _size = input.readObject() as int;
            _state = input.readObject() as int;
            _state_date = input.readObject() as Date;
            _state_name = input.readObject() as String;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject(_file_name);
            output.writeObject(_hash_local);
            output.writeObject(_hash_remote);
            output.writeObject(_order_id);
            output.writeObject(_previous_state);
            output.writeObject(_previous_state_name);
            output.writeObject(_size);
            output.writeObject(_state);
            output.writeObject(_state_date);
            output.writeObject(_state_name);
        }
    }
}