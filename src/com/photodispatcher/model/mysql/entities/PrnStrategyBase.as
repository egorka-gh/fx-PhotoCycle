/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (PrnStrategy.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;

    [Bindable]
    public class PrnStrategyBase extends AbstractEntity {

        public function PrnStrategyBase() {
            super();
        }

        private var _id:int;
        private var _is_active:Boolean;
        private var _lab:int;
        private var _lab_name:String;
        private var _last_start:Date;
        private var _limit_done:int;
        private var _limit_type:int;
        private var _limit_type_name:String;
        private var _limit_val:int;
        private var _order_type:int;
        private var _order_type_name:String;
        private var _paper:int;
        private var _paper_name:String;
        private var _priority:int;
        private var _refresh_interval:int;
        private var _strategy_type:int;
        private var _strategy_type_name:String;
        private var _time_end:Date;
        private var _time_start:Date;
        private var _width:int;

        public function set id(value:int):void {
            _id = value;
        }
        public function get id():int {
            return _id;
        }

        public function set is_active(value:Boolean):void {
            _is_active = value;
        }
        public function get is_active():Boolean {
            return _is_active;
        }

        public function set lab(value:int):void {
            _lab = value;
        }
        public function get lab():int {
            return _lab;
        }

        public function set lab_name(value:String):void {
            _lab_name = value;
        }
        public function get lab_name():String {
            return _lab_name;
        }

        public function set last_start(value:Date):void {
            _last_start = value;
        }
        public function get last_start():Date {
            return _last_start;
        }

        public function set limit_done(value:int):void {
            _limit_done = value;
        }
        public function get limit_done():int {
            return _limit_done;
        }

        public function set limit_type(value:int):void {
            _limit_type = value;
        }
        public function get limit_type():int {
            return _limit_type;
        }

        public function set limit_type_name(value:String):void {
            _limit_type_name = value;
        }
        public function get limit_type_name():String {
            return _limit_type_name;
        }

        public function set limit_val(value:int):void {
            _limit_val = value;
        }
        public function get limit_val():int {
            return _limit_val;
        }

        public function set order_type(value:int):void {
            _order_type = value;
        }
        public function get order_type():int {
            return _order_type;
        }

        public function set order_type_name(value:String):void {
            _order_type_name = value;
        }
        public function get order_type_name():String {
            return _order_type_name;
        }

        public function set paper(value:int):void {
            _paper = value;
        }
        public function get paper():int {
            return _paper;
        }

        public function set paper_name(value:String):void {
            _paper_name = value;
        }
        public function get paper_name():String {
            return _paper_name;
        }

        public function set priority(value:int):void {
            _priority = value;
        }
        public function get priority():int {
            return _priority;
        }

        public function set refresh_interval(value:int):void {
            _refresh_interval = value;
        }
        public function get refresh_interval():int {
            return _refresh_interval;
        }

        public function set strategy_type(value:int):void {
            _strategy_type = value;
        }
        public function get strategy_type():int {
            return _strategy_type;
        }

        public function set strategy_type_name(value:String):void {
            _strategy_type_name = value;
        }
        public function get strategy_type_name():String {
            return _strategy_type_name;
        }

        public function set time_end(value:Date):void {
            _time_end = value;
        }
        public function get time_end():Date {
            return _time_end;
        }

        public function set time_start(value:Date):void {
            _time_start = value;
        }
        public function get time_start():Date {
            return _time_start;
        }

        public function set width(value:int):void {
            _width = value;
        }
        public function get width():int {
            return _width;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _id = input.readObject() as int;
            _is_active = input.readObject() as Boolean;
            _lab = input.readObject() as int;
            _lab_name = input.readObject() as String;
            _last_start = input.readObject() as Date;
            _limit_done = input.readObject() as int;
            _limit_type = input.readObject() as int;
            _limit_type_name = input.readObject() as String;
            _limit_val = input.readObject() as int;
            _order_type = input.readObject() as int;
            _order_type_name = input.readObject() as String;
            _paper = input.readObject() as int;
            _paper_name = input.readObject() as String;
            _priority = input.readObject() as int;
            _refresh_interval = input.readObject() as int;
            _strategy_type = input.readObject() as int;
            _strategy_type_name = input.readObject() as String;
            _time_end = input.readObject() as Date;
            _time_start = input.readObject() as Date;
            _width = input.readObject() as int;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject(_id);
            output.writeObject(_is_active);
            output.writeObject(_lab);
            output.writeObject(_lab_name);
            output.writeObject(_last_start);
            output.writeObject(_limit_done);
            output.writeObject(_limit_type);
            output.writeObject(_limit_type_name);
            output.writeObject(_limit_val);
            output.writeObject(_order_type);
            output.writeObject(_order_type_name);
            output.writeObject(_paper);
            output.writeObject(_paper_name);
            output.writeObject(_priority);
            output.writeObject(_refresh_interval);
            output.writeObject(_strategy_type);
            output.writeObject(_strategy_type_name);
            output.writeObject(_time_end);
            output.writeObject(_time_start);
            output.writeObject(_width);
        }
    }
}