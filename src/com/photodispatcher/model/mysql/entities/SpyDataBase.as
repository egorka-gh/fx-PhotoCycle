/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (SpyData.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;

    [Bindable]
    public class SpyDataBase extends AbstractEntity {

        public function SpyDataBase() {
            super();
        }

        private var _alias:String;
        private var _book_part:int;
        private var _book_type:int;
        private var _bp_name:String;
        private var _bt_name:String;
        private var _delay:int;
        private var _id:String;
        private var _is_reject:Boolean;
        private var _lastDate:Date;
        private var _op_name:String;
        private var _reset:Boolean;
        private var _resetDate:Date;
        private var _start_date:Date;
        private var _state:int;
        private var _state_date:Date;
        private var _sub_id:String;
        private var _transit_date:Date;

        public function set alias(value:String):void {
            _alias = value;
        }
        public function get alias():String {
            return _alias;
        }

        public function set book_part(value:int):void {
            _book_part = value;
        }
        public function get book_part():int {
            return _book_part;
        }

        public function set book_type(value:int):void {
            _book_type = value;
        }
        public function get book_type():int {
            return _book_type;
        }

        public function set bp_name(value:String):void {
            _bp_name = value;
        }
        public function get bp_name():String {
            return _bp_name;
        }

        public function set bt_name(value:String):void {
            _bt_name = value;
        }
        public function get bt_name():String {
            return _bt_name;
        }

        public function set delay(value:int):void {
            _delay = value;
        }
        public function get delay():int {
            return _delay;
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

        public function set lastDate(value:Date):void {
            _lastDate = value;
        }
        public function get lastDate():Date {
            return _lastDate;
        }

        public function set op_name(value:String):void {
            _op_name = value;
        }
        public function get op_name():String {
            return _op_name;
        }

        public function set reset(value:Boolean):void {
            _reset = value;
        }
        public function get reset():Boolean {
            return _reset;
        }

        public function set resetDate(value:Date):void {
            _resetDate = value;
        }
        public function get resetDate():Date {
            return _resetDate;
        }

        public function set start_date(value:Date):void {
            _start_date = value;
        }
        public function get start_date():Date {
            return _start_date;
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
            _alias = input.readObject() as String;
            _book_part = input.readObject() as int;
            _book_type = input.readObject() as int;
            _bp_name = input.readObject() as String;
            _bt_name = input.readObject() as String;
            _delay = input.readObject() as int;
            _id = input.readObject() as String;
            _is_reject = input.readObject() as Boolean;
            _lastDate = input.readObject() as Date;
            _op_name = input.readObject() as String;
            _reset = input.readObject() as Boolean;
            _resetDate = input.readObject() as Date;
            _start_date = input.readObject() as Date;
            _state = input.readObject() as int;
            _state_date = input.readObject() as Date;
            _sub_id = input.readObject() as String;
            _transit_date = input.readObject() as Date;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject(_alias);
            output.writeObject(_book_part);
            output.writeObject(_book_type);
            output.writeObject(_bp_name);
            output.writeObject(_bt_name);
            output.writeObject(_delay);
            output.writeObject(_id);
            output.writeObject(_is_reject);
            output.writeObject(_lastDate);
            output.writeObject(_op_name);
            output.writeObject(_reset);
            output.writeObject(_resetDate);
            output.writeObject(_start_date);
            output.writeObject(_state);
            output.writeObject(_state_date);
            output.writeObject(_sub_id);
            output.writeObject(_transit_date);
        }
    }
}