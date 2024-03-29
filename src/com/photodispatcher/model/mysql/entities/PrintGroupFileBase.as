/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (PrintGroupFile.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;

    [Bindable]
    public class PrintGroupFileBase extends AbstractEntity {

        public function PrintGroupFileBase() {
            super();
        }

        private var _book_num:int;
        private var _book_part:int;
        private var _book_part_name:String;
        private var _caption:String;
        private var _file_name:String;
        private var _id:int;
        private var _page_num:int;
        private var _path:String;
        private var _print_forvard:Boolean;
        private var _print_group:String;
        private var _printed:Boolean;
        private var _prt_qty:int;
        private var _tech_date:String;
        private var _tech_point:int;
        private var _tech_point_name:String;
        private var _tech_state:int;
        private var _tech_state_name:String;

        public function set book_num(value:int):void {
            _book_num = value;
        }
        public function get book_num():int {
            return _book_num;
        }

        public function set book_part(value:int):void {
            _book_part = value;
        }
        public function get book_part():int {
            return _book_part;
        }

        public function set book_part_name(value:String):void {
            _book_part_name = value;
        }
        public function get book_part_name():String {
            return _book_part_name;
        }

        public function set caption(value:String):void {
            _caption = value;
        }
        public function get caption():String {
            return _caption;
        }

        public function set file_name(value:String):void {
            _file_name = value;
        }
        public function get file_name():String {
            return _file_name;
        }

        public function set id(value:int):void {
            _id = value;
        }
        public function get id():int {
            return _id;
        }

        public function set page_num(value:int):void {
            _page_num = value;
        }
        public function get page_num():int {
            return _page_num;
        }

        public function set path(value:String):void {
            _path = value;
        }
        public function get path():String {
            return _path;
        }

        public function set print_forvard(value:Boolean):void {
            _print_forvard = value;
        }
        public function get print_forvard():Boolean {
            return _print_forvard;
        }

        public function set print_group(value:String):void {
            _print_group = value;
        }
        public function get print_group():String {
            return _print_group;
        }

        public function set printed(value:Boolean):void {
            _printed = value;
        }
        public function get printed():Boolean {
            return _printed;
        }

        public function set prt_qty(value:int):void {
            _prt_qty = value;
        }
        public function get prt_qty():int {
            return _prt_qty;
        }

        public function set tech_date(value:String):void {
            _tech_date = value;
        }
        public function get tech_date():String {
            return _tech_date;
        }

        public function set tech_point(value:int):void {
            _tech_point = value;
        }
        public function get tech_point():int {
            return _tech_point;
        }

        public function set tech_point_name(value:String):void {
            _tech_point_name = value;
        }
        public function get tech_point_name():String {
            return _tech_point_name;
        }

        public function set tech_state(value:int):void {
            _tech_state = value;
        }
        public function get tech_state():int {
            return _tech_state;
        }

        public function set tech_state_name(value:String):void {
            _tech_state_name = value;
        }
        public function get tech_state_name():String {
            return _tech_state_name;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _book_num = input.readObject() as int;
            _book_part = input.readObject() as int;
            _book_part_name = input.readObject() as String;
            _caption = input.readObject() as String;
            _file_name = input.readObject() as String;
            _id = input.readObject() as int;
            _page_num = input.readObject() as int;
            _path = input.readObject() as String;
            _print_forvard = input.readObject() as Boolean;
            _print_group = input.readObject() as String;
            _printed = input.readObject() as Boolean;
            _prt_qty = input.readObject() as int;
            _tech_date = input.readObject() as String;
            _tech_point = input.readObject() as int;
            _tech_point_name = input.readObject() as String;
            _tech_state = input.readObject() as int;
            _tech_state_name = input.readObject() as String;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject(_book_num);
            output.writeObject(_book_part);
            output.writeObject(_book_part_name);
            output.writeObject(_caption);
            output.writeObject(_file_name);
            output.writeObject(_id);
            output.writeObject(_page_num);
            output.writeObject(_path);
            output.writeObject(_print_forvard);
            output.writeObject(_print_group);
            output.writeObject(_printed);
            output.writeObject(_prt_qty);
            output.writeObject(_tech_date);
            output.writeObject(_tech_point);
            output.writeObject(_tech_point_name);
            output.writeObject(_tech_state);
            output.writeObject(_tech_state_name);
        }
    }
}