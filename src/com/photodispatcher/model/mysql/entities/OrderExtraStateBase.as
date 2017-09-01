/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (OrderExtraState.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;

    [Bindable]
    public class OrderExtraStateBase extends AbstractEntity {

        public function OrderExtraStateBase() {
            super();
        }

        private var _books:int;
        private var _books_done:int;
        private var _id:String;
        private var _is_reject:Boolean;
        private var _reported:Boolean;
        private var _start_date:Date;
        private var _start_date2:Date;
        private var _state:int;
        private var _state2:int;
        private var _state_date:Date;
        private var _state_date2:Date;
        private var _state_name:String;
        private var _state_name2:String;
        private var _sub_id:String;
        private var _transit_date:Date;

        public function set books(value:int):void {
            _books = value;
        }
        public function get books():int {
            return _books;
        }

        public function set books_done(value:int):void {
            _books_done = value;
        }
        public function get books_done():int {
            return _books_done;
        }

        public function set id(value:String):void {
            _id = value;
        }
        public function get id():String {
            return _id;
        }

        public function set is_reject(value:Boolean):void {
            _is_reject = value;
        }
        public function get is_reject():Boolean {
            return _is_reject;
        }

        public function set reported(value:Boolean):void {
            _reported = value;
        }
        public function get reported():Boolean {
            return _reported;
        }

        public function set start_date(value:Date):void {
            _start_date = value;
        }
        public function get start_date():Date {
            return _start_date;
        }

        public function set start_date2(value:Date):void {
            _start_date2 = value;
        }
        public function get start_date2():Date {
            return _start_date2;
        }

        public function set state(value:int):void {
            _state = value;
        }
        public function get state():int {
            return _state;
        }

        public function set state2(value:int):void {
            _state2 = value;
        }
        public function get state2():int {
            return _state2;
        }

        public function set state_date(value:Date):void {
            _state_date = value;
        }
        public function get state_date():Date {
            return _state_date;
        }

        public function set state_date2(value:Date):void {
            _state_date2 = value;
        }
        public function get state_date2():Date {
            return _state_date2;
        }

        public function set state_name(value:String):void {
            _state_name = value;
        }
        public function get state_name():String {
            return _state_name;
        }

        public function set state_name2(value:String):void {
            _state_name2 = value;
        }
        public function get state_name2():String {
            return _state_name2;
        }

        public function set sub_id(value:String):void {
            _sub_id = value;
        }
        public function get sub_id():String {
            return _sub_id;
        }

        public function set transit_date(value:Date):void {
            _transit_date = value;
        }
        public function get transit_date():Date {
            return _transit_date;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _books = input.readObject() as int;
            _books_done = input.readObject() as int;
            _id = input.readObject() as String;
            _is_reject = input.readObject() as Boolean;
            _reported = input.readObject() as Boolean;
            _start_date = input.readObject() as Date;
            _start_date2 = input.readObject() as Date;
            _state = input.readObject() as int;
            _state2 = input.readObject() as int;
            _state_date = input.readObject() as Date;
            _state_date2 = input.readObject() as Date;
            _state_name = input.readObject() as String;
            _state_name2 = input.readObject() as String;
            _sub_id = input.readObject() as String;
            _transit_date = input.readObject() as Date;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject(_books);
            output.writeObject(_books_done);
            output.writeObject(_id);
            output.writeObject(_is_reject);
            output.writeObject(_reported);
            output.writeObject(_start_date);
            output.writeObject(_start_date2);
            output.writeObject(_state);
            output.writeObject(_state2);
            output.writeObject(_state_date);
            output.writeObject(_state_date2);
            output.writeObject(_state_name);
            output.writeObject(_state_name2);
            output.writeObject(_sub_id);
            output.writeObject(_transit_date);
        }
    }
}