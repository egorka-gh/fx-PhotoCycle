/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (LabPrintCode.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;

    [Bindable]
    public class LabPrintCodeBase extends AbstractEntity {

        public function LabPrintCodeBase() {
            super();
        }

        private var _correction:int;
        private var _correction_name:String;
        private var _cutting:int;
        private var _cutting_name:String;
        private var _frame:int;
        private var _frame_name:String;
        private var _height:int;
        private var _id:int;
        private var _is_duplex:Boolean;
        private var _is_pdf:Boolean;
        private var _paper:int;
        private var _paper_name:String;
        private var _prt_code:String;
        private var _roll:int;
        private var _src_id:int;
        private var _src_type:int;
        private var _width:int;

        public function set correction(value:int):void {
            _correction = value;
        }
        public function get correction():int {
            return _correction;
        }

        public function set correction_name(value:String):void {
            _correction_name = value;
        }
        public function get correction_name():String {
            return _correction_name;
        }

        public function set cutting(value:int):void {
            _cutting = value;
        }
        public function get cutting():int {
            return _cutting;
        }

        public function set cutting_name(value:String):void {
            _cutting_name = value;
        }
        public function get cutting_name():String {
            return _cutting_name;
        }

        public function set frame(value:int):void {
            _frame = value;
        }
        public function get frame():int {
            return _frame;
        }

        public function set frame_name(value:String):void {
            _frame_name = value;
        }
        public function get frame_name():String {
            return _frame_name;
        }

        public function set height(value:int):void {
            _height = value;
        }
        public function get height():int {
            return _height;
        }

        public function set id(value:int):void {
            _id = value;
        }
        public function get id():int {
            return _id;
        }

        public function set is_duplex(value:Boolean):void {
            _is_duplex = value;
        }
        public function get is_duplex():Boolean {
            return _is_duplex;
        }

        public function set is_pdf(value:Boolean):void {
            _is_pdf = value;
        }
        public function get is_pdf():Boolean {
            return _is_pdf;
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

        public function set prt_code(value:String):void {
            _prt_code = value;
        }
        public function get prt_code():String {
            return _prt_code;
        }

        public function set roll(value:int):void {
            _roll = value;
        }
        public function get roll():int {
            return _roll;
        }

        public function set src_id(value:int):void {
            _src_id = value;
        }
        public function get src_id():int {
            return _src_id;
        }

        public function set src_type(value:int):void {
            _src_type = value;
        }
        public function get src_type():int {
            return _src_type;
        }

        public function set width(value:int):void {
            _width = value;
        }
        public function get width():int {
            return _width;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _correction = input.readObject() as int;
            _correction_name = input.readObject() as String;
            _cutting = input.readObject() as int;
            _cutting_name = input.readObject() as String;
            _frame = input.readObject() as int;
            _frame_name = input.readObject() as String;
            _height = input.readObject() as int;
            _id = input.readObject() as int;
            _is_duplex = input.readObject() as Boolean;
            _is_pdf = input.readObject() as Boolean;
            _paper = input.readObject() as int;
            _paper_name = input.readObject() as String;
            _prt_code = input.readObject() as String;
            _roll = input.readObject() as int;
            _src_id = input.readObject() as int;
            _src_type = input.readObject() as int;
            _width = input.readObject() as int;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject(_correction);
            output.writeObject(_correction_name);
            output.writeObject(_cutting);
            output.writeObject(_cutting_name);
            output.writeObject(_frame);
            output.writeObject(_frame_name);
            output.writeObject(_height);
            output.writeObject(_id);
            output.writeObject(_is_duplex);
            output.writeObject(_is_pdf);
            output.writeObject(_paper);
            output.writeObject(_paper_name);
            output.writeObject(_prt_code);
            output.writeObject(_roll);
            output.writeObject(_src_id);
            output.writeObject(_src_type);
            output.writeObject(_width);
        }
    }
}