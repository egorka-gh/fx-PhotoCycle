/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (PrintGroup.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;
    import mx.collections.ListCollectionView;
    import org.granite.tide.IPropertyHolder;

    [Bindable]
    public class PrintGroupBase extends AbstractEntity {

        public function PrintGroupBase() {
            super();
        }

        private var _book_num:int;
        private var _book_part:int;
        private var _book_part_name:String;
        private var _book_type:int;
        private var _book_type_name:String;
        private var _correction:int;
        private var _correction_name:String;
        private var _cutting:int;
        private var _cutting_name:String;
        private var _destination:int;
        private var _file_num:int;
        private var _files:ListCollectionView;
        private var _frame:int;
        private var _frame_name:String;
        private var _height:int;
        private var _id:String;
        private var _is_duplex:Boolean;
        private var _is_pdf:Boolean;
        private var _is_reprint:Boolean;
        private var _lab_name:String;
        private var _order_folder:String;
        private var _order_id:String;
        private var _paper:int;
        private var _paper_name:String;
        private var _path:String;
        private var _prints:int;
        private var _prints_done:int;
        private var _reprint_id:String;
        private var _sheet_num:int;
        private var _source_id:int;
        private var _source_name:String;
        private var _state:int;
        private var _state_date:Date;
        private var _state_name:String;
        private var _sub_id:String;
        private var _width:int;

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

        public function set book_type(value:int):void {
            _book_type = value;
        }
        public function get book_type():int {
            return _book_type;
        }

        public function set book_type_name(value:String):void {
            _book_type_name = value;
        }
        public function get book_type_name():String {
            return _book_type_name;
        }

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

        public function set destination(value:int):void {
            _destination = value;
        }
        public function get destination():int {
            return _destination;
        }

        public function set file_num(value:int):void {
            _file_num = value;
        }
        public function get file_num():int {
            return _file_num;
        }

        public function set files(value:ListCollectionView):void {
            _files = value;
        }
        public function get files():ListCollectionView {
            return _files;
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

        public function set id(value:String):void {
            _id = value;
        }
        public function get id():String {
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

        public function set is_reprint(value:Boolean):void {
            _is_reprint = value;
        }
        public function get is_reprint():Boolean {
            return _is_reprint;
        }

        public function set lab_name(value:String):void {
            _lab_name = value;
        }
        public function get lab_name():String {
            return _lab_name;
        }

        public function set order_folder(value:String):void {
            _order_folder = value;
        }
        public function get order_folder():String {
            return _order_folder;
        }

        public function set order_id(value:String):void {
            _order_id = value;
        }
        public function get order_id():String {
            return _order_id;
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

        public function set path(value:String):void {
            _path = value;
        }
        public function get path():String {
            return _path;
        }

        public function set prints(value:int):void {
            _prints = value;
        }
        public function get prints():int {
            return _prints;
        }

        public function set prints_done(value:int):void {
            _prints_done = value;
        }
        public function get prints_done():int {
            return _prints_done;
        }

        public function set reprint_id(value:String):void {
            _reprint_id = value;
        }
        public function get reprint_id():String {
            return _reprint_id;
        }

        public function set sheet_num(value:int):void {
            _sheet_num = value;
        }
        public function get sheet_num():int {
            return _sheet_num;
        }

        public function set source_id(value:int):void {
            _source_id = value;
        }
        public function get source_id():int {
            return _source_id;
        }

        public function set source_name(value:String):void {
            _source_name = value;
        }
        public function get source_name():String {
            return _source_name;
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

        public function set width(value:int):void {
            _width = value;
        }
        public function get width():int {
            return _width;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _book_num = input.readObject() as int;
            _book_part = input.readObject() as int;
            _book_part_name = input.readObject() as String;
            _book_type = input.readObject() as int;
            _book_type_name = input.readObject() as String;
            _correction = input.readObject() as int;
            _correction_name = input.readObject() as String;
            _cutting = input.readObject() as int;
            _cutting_name = input.readObject() as String;
            _destination = input.readObject() as int;
            _file_num = input.readObject() as int;
            _files = input.readObject() as ListCollectionView;
            _frame = input.readObject() as int;
            _frame_name = input.readObject() as String;
            _height = input.readObject() as int;
            _id = input.readObject() as String;
            _is_duplex = input.readObject() as Boolean;
            _is_pdf = input.readObject() as Boolean;
            _is_reprint = input.readObject() as Boolean;
            _lab_name = input.readObject() as String;
            _order_folder = input.readObject() as String;
            _order_id = input.readObject() as String;
            _paper = input.readObject() as int;
            _paper_name = input.readObject() as String;
            _path = input.readObject() as String;
            _prints = input.readObject() as int;
            _prints_done = input.readObject() as int;
            _reprint_id = input.readObject() as String;
            _sheet_num = input.readObject() as int;
            _source_id = input.readObject() as int;
            _source_name = input.readObject() as String;
            _state = input.readObject() as int;
            _state_date = input.readObject() as Date;
            _state_name = input.readObject() as String;
            _sub_id = input.readObject() as String;
            _width = input.readObject() as int;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject((_book_num is IPropertyHolder) ? IPropertyHolder(_book_num).object : _book_num);
            output.writeObject((_book_part is IPropertyHolder) ? IPropertyHolder(_book_part).object : _book_part);
            output.writeObject((_book_part_name is IPropertyHolder) ? IPropertyHolder(_book_part_name).object : _book_part_name);
            output.writeObject((_book_type is IPropertyHolder) ? IPropertyHolder(_book_type).object : _book_type);
            output.writeObject((_book_type_name is IPropertyHolder) ? IPropertyHolder(_book_type_name).object : _book_type_name);
            output.writeObject((_correction is IPropertyHolder) ? IPropertyHolder(_correction).object : _correction);
            output.writeObject((_correction_name is IPropertyHolder) ? IPropertyHolder(_correction_name).object : _correction_name);
            output.writeObject((_cutting is IPropertyHolder) ? IPropertyHolder(_cutting).object : _cutting);
            output.writeObject((_cutting_name is IPropertyHolder) ? IPropertyHolder(_cutting_name).object : _cutting_name);
            output.writeObject((_destination is IPropertyHolder) ? IPropertyHolder(_destination).object : _destination);
            output.writeObject((_file_num is IPropertyHolder) ? IPropertyHolder(_file_num).object : _file_num);
            output.writeObject((_files is IPropertyHolder) ? IPropertyHolder(_files).object : _files);
            output.writeObject((_frame is IPropertyHolder) ? IPropertyHolder(_frame).object : _frame);
            output.writeObject((_frame_name is IPropertyHolder) ? IPropertyHolder(_frame_name).object : _frame_name);
            output.writeObject((_height is IPropertyHolder) ? IPropertyHolder(_height).object : _height);
            output.writeObject((_id is IPropertyHolder) ? IPropertyHolder(_id).object : _id);
            output.writeObject((_is_duplex is IPropertyHolder) ? IPropertyHolder(_is_duplex).object : _is_duplex);
            output.writeObject((_is_pdf is IPropertyHolder) ? IPropertyHolder(_is_pdf).object : _is_pdf);
            output.writeObject((_is_reprint is IPropertyHolder) ? IPropertyHolder(_is_reprint).object : _is_reprint);
            output.writeObject((_lab_name is IPropertyHolder) ? IPropertyHolder(_lab_name).object : _lab_name);
            output.writeObject((_order_folder is IPropertyHolder) ? IPropertyHolder(_order_folder).object : _order_folder);
            output.writeObject((_order_id is IPropertyHolder) ? IPropertyHolder(_order_id).object : _order_id);
            output.writeObject((_paper is IPropertyHolder) ? IPropertyHolder(_paper).object : _paper);
            output.writeObject((_paper_name is IPropertyHolder) ? IPropertyHolder(_paper_name).object : _paper_name);
            output.writeObject((_path is IPropertyHolder) ? IPropertyHolder(_path).object : _path);
            output.writeObject((_prints is IPropertyHolder) ? IPropertyHolder(_prints).object : _prints);
            output.writeObject((_prints_done is IPropertyHolder) ? IPropertyHolder(_prints_done).object : _prints_done);
            output.writeObject((_reprint_id is IPropertyHolder) ? IPropertyHolder(_reprint_id).object : _reprint_id);
            output.writeObject((_sheet_num is IPropertyHolder) ? IPropertyHolder(_sheet_num).object : _sheet_num);
            output.writeObject((_source_id is IPropertyHolder) ? IPropertyHolder(_source_id).object : _source_id);
            output.writeObject((_source_name is IPropertyHolder) ? IPropertyHolder(_source_name).object : _source_name);
            output.writeObject((_state is IPropertyHolder) ? IPropertyHolder(_state).object : _state);
            output.writeObject((_state_date is IPropertyHolder) ? IPropertyHolder(_state_date).object : _state_date);
            output.writeObject((_state_name is IPropertyHolder) ? IPropertyHolder(_state_name).object : _state_name);
            output.writeObject((_sub_id is IPropertyHolder) ? IPropertyHolder(_sub_id).object : _sub_id);
            output.writeObject((_width is IPropertyHolder) ? IPropertyHolder(_width).object : _width);
        }
    }
}