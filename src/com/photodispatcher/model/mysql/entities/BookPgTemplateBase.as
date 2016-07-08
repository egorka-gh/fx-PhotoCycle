/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (BookPgTemplate.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;
    import mx.collections.ListCollectionView;

    [Bindable]
    public class BookPgTemplateBase extends AbstractEntity {

        public function BookPgTemplateBase() {
            super();
        }

        private var _altPaper:ListCollectionView;
        private var _bar_offset:String;
        private var _bar_size:int;
        private var _book:int;
        private var _book_part:int;
        private var _book_part_name:String;
        private var _correction:int;
        private var _correction_name:String;
        private var _cutting:int;
        private var _cutting_name:String;
        private var _font_offset:String;
        private var _font_size:int;
        private var _fontv_offset:String;
        private var _fontv_size:int;
        private var _frame:int;
        private var _frame_name:String;
        private var _height:int;
        private var _height_add:int;
        private var _id:int;
        private var _is_duplex:Boolean;
        private var _is_pdf:Boolean;
        private var _is_sheet_ready:Boolean;
        private var _is_tech_bot:Boolean;
        private var _is_tech_center:Boolean;
        private var _is_tech_stair_bot:Boolean;
        private var _is_tech_stair_top:Boolean;
        private var _is_tech_top:Boolean;
        private var _lab_type:int;
        private var _lab_type_name:String;
        private var _mark_offset:String;
        private var _mark_size:int;
        private var _notching:int;
        private var _page_hoffset:int;
        private var _page_len:int;
        private var _page_width:int;
        private var _paper:int;
        private var _paper_name:String;
        private var _queue_offset:String;
        private var _queue_size:int;
        private var _reprint_offset:String;
        private var _reprint_size:int;
        private var _revers:Boolean;
        private var _sheet_len:int;
        private var _sheet_width:int;
        private var _stroke:int;
        private var _tech_add:int;
        private var _tech_bar:int;
        private var _tech_bar_boffset:String;
        private var _tech_bar_color:String;
        private var _tech_bar_offset:String;
        private var _tech_bar_step:Number;
        private var _tech_bar_toffset:String;
        private var _tech_stair_add:int;
        private var _tech_stair_step:int;
        private var _width:int;

        public function set altPaper(value:ListCollectionView):void {
            _altPaper = value;
        }
        public function get altPaper():ListCollectionView {
            return _altPaper;
        }

        public function set bar_offset(value:String):void {
            _bar_offset = value;
        }
        public function get bar_offset():String {
            return _bar_offset;
        }

        public function set bar_size(value:int):void {
            _bar_size = value;
        }
        public function get bar_size():int {
            return _bar_size;
        }

        public function set book(value:int):void {
            _book = value;
        }
        public function get book():int {
            return _book;
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

        public function set font_offset(value:String):void {
            _font_offset = value;
        }
        public function get font_offset():String {
            return _font_offset;
        }

        public function set font_size(value:int):void {
            _font_size = value;
        }
        public function get font_size():int {
            return _font_size;
        }

        public function set fontv_offset(value:String):void {
            _fontv_offset = value;
        }
        public function get fontv_offset():String {
            return _fontv_offset;
        }

        public function set fontv_size(value:int):void {
            _fontv_size = value;
        }
        public function get fontv_size():int {
            return _fontv_size;
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

        public function set height_add(value:int):void {
            _height_add = value;
        }
        public function get height_add():int {
            return _height_add;
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

        public function set is_sheet_ready(value:Boolean):void {
            _is_sheet_ready = value;
        }
        public function get is_sheet_ready():Boolean {
            return _is_sheet_ready;
        }

        public function set is_tech_bot(value:Boolean):void {
            _is_tech_bot = value;
        }
        public function get is_tech_bot():Boolean {
            return _is_tech_bot;
        }

        public function set is_tech_center(value:Boolean):void {
            _is_tech_center = value;
        }
        public function get is_tech_center():Boolean {
            return _is_tech_center;
        }

        public function set is_tech_stair_bot(value:Boolean):void {
            _is_tech_stair_bot = value;
        }
        public function get is_tech_stair_bot():Boolean {
            return _is_tech_stair_bot;
        }

        public function set is_tech_stair_top(value:Boolean):void {
            _is_tech_stair_top = value;
        }
        public function get is_tech_stair_top():Boolean {
            return _is_tech_stair_top;
        }

        public function set is_tech_top(value:Boolean):void {
            _is_tech_top = value;
        }
        public function get is_tech_top():Boolean {
            return _is_tech_top;
        }

        public function set lab_type(value:int):void {
            _lab_type = value;
        }
        public function get lab_type():int {
            return _lab_type;
        }

        public function set lab_type_name(value:String):void {
            _lab_type_name = value;
        }
        public function get lab_type_name():String {
            return _lab_type_name;
        }

        public function set mark_offset(value:String):void {
            _mark_offset = value;
        }
        public function get mark_offset():String {
            return _mark_offset;
        }

        public function set mark_size(value:int):void {
            _mark_size = value;
        }
        public function get mark_size():int {
            return _mark_size;
        }

        public function set notching(value:int):void {
            _notching = value;
        }
        public function get notching():int {
            return _notching;
        }

        public function set page_hoffset(value:int):void {
            _page_hoffset = value;
        }
        public function get page_hoffset():int {
            return _page_hoffset;
        }

        public function set page_len(value:int):void {
            _page_len = value;
        }
        public function get page_len():int {
            return _page_len;
        }

        public function set page_width(value:int):void {
            _page_width = value;
        }
        public function get page_width():int {
            return _page_width;
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

        public function set queue_offset(value:String):void {
            _queue_offset = value;
        }
        public function get queue_offset():String {
            return _queue_offset;
        }

        public function set queue_size(value:int):void {
            _queue_size = value;
        }
        public function get queue_size():int {
            return _queue_size;
        }

        public function set reprint_offset(value:String):void {
            _reprint_offset = value;
        }
        public function get reprint_offset():String {
            return _reprint_offset;
        }

        public function set reprint_size(value:int):void {
            _reprint_size = value;
        }
        public function get reprint_size():int {
            return _reprint_size;
        }

        public function set revers(value:Boolean):void {
            _revers = value;
        }
        public function get revers():Boolean {
            return _revers;
        }

        public function set sheet_len(value:int):void {
            _sheet_len = value;
        }
        public function get sheet_len():int {
            return _sheet_len;
        }

        public function set sheet_width(value:int):void {
            _sheet_width = value;
        }
        public function get sheet_width():int {
            return _sheet_width;
        }

        public function set stroke(value:int):void {
            _stroke = value;
        }
        public function get stroke():int {
            return _stroke;
        }

        public function set tech_add(value:int):void {
            _tech_add = value;
        }
        public function get tech_add():int {
            return _tech_add;
        }

        public function set tech_bar(value:int):void {
            _tech_bar = value;
        }
        public function get tech_bar():int {
            return _tech_bar;
        }

        public function set tech_bar_boffset(value:String):void {
            _tech_bar_boffset = value;
        }
        public function get tech_bar_boffset():String {
            return _tech_bar_boffset;
        }

        public function set tech_bar_color(value:String):void {
            _tech_bar_color = value;
        }
        public function get tech_bar_color():String {
            return _tech_bar_color;
        }

        public function set tech_bar_offset(value:String):void {
            _tech_bar_offset = value;
        }
        public function get tech_bar_offset():String {
            return _tech_bar_offset;
        }

        public function set tech_bar_step(value:Number):void {
            _tech_bar_step = value;
        }
        public function get tech_bar_step():Number {
            return _tech_bar_step;
        }

        public function set tech_bar_toffset(value:String):void {
            _tech_bar_toffset = value;
        }
        public function get tech_bar_toffset():String {
            return _tech_bar_toffset;
        }

        public function set tech_stair_add(value:int):void {
            _tech_stair_add = value;
        }
        public function get tech_stair_add():int {
            return _tech_stair_add;
        }

        public function set tech_stair_step(value:int):void {
            _tech_stair_step = value;
        }
        public function get tech_stair_step():int {
            return _tech_stair_step;
        }

        public function set width(value:int):void {
            _width = value;
        }
        public function get width():int {
            return _width;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _altPaper = input.readObject() as ListCollectionView;
            _bar_offset = input.readObject() as String;
            _bar_size = input.readObject() as int;
            _book = input.readObject() as int;
            _book_part = input.readObject() as int;
            _book_part_name = input.readObject() as String;
            _correction = input.readObject() as int;
            _correction_name = input.readObject() as String;
            _cutting = input.readObject() as int;
            _cutting_name = input.readObject() as String;
            _font_offset = input.readObject() as String;
            _font_size = input.readObject() as int;
            _fontv_offset = input.readObject() as String;
            _fontv_size = input.readObject() as int;
            _frame = input.readObject() as int;
            _frame_name = input.readObject() as String;
            _height = input.readObject() as int;
            _height_add = input.readObject() as int;
            _id = input.readObject() as int;
            _is_duplex = input.readObject() as Boolean;
            _is_pdf = input.readObject() as Boolean;
            _is_sheet_ready = input.readObject() as Boolean;
            _is_tech_bot = input.readObject() as Boolean;
            _is_tech_center = input.readObject() as Boolean;
            _is_tech_stair_bot = input.readObject() as Boolean;
            _is_tech_stair_top = input.readObject() as Boolean;
            _is_tech_top = input.readObject() as Boolean;
            _lab_type = input.readObject() as int;
            _lab_type_name = input.readObject() as String;
            _mark_offset = input.readObject() as String;
            _mark_size = input.readObject() as int;
            _notching = input.readObject() as int;
            _page_hoffset = input.readObject() as int;
            _page_len = input.readObject() as int;
            _page_width = input.readObject() as int;
            _paper = input.readObject() as int;
            _paper_name = input.readObject() as String;
            _queue_offset = input.readObject() as String;
            _queue_size = input.readObject() as int;
            _reprint_offset = input.readObject() as String;
            _reprint_size = input.readObject() as int;
            _revers = input.readObject() as Boolean;
            _sheet_len = input.readObject() as int;
            _sheet_width = input.readObject() as int;
            _stroke = input.readObject() as int;
            _tech_add = input.readObject() as int;
            _tech_bar = input.readObject() as int;
            _tech_bar_boffset = input.readObject() as String;
            _tech_bar_color = input.readObject() as String;
            _tech_bar_offset = input.readObject() as String;
            _tech_bar_step = function(o:*):Number { return (o is Number ? o as Number : Number.NaN) } (input.readObject());
            _tech_bar_toffset = input.readObject() as String;
            _tech_stair_add = input.readObject() as int;
            _tech_stair_step = input.readObject() as int;
            _width = input.readObject() as int;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject(_altPaper);
            output.writeObject(_bar_offset);
            output.writeObject(_bar_size);
            output.writeObject(_book);
            output.writeObject(_book_part);
            output.writeObject(_book_part_name);
            output.writeObject(_correction);
            output.writeObject(_correction_name);
            output.writeObject(_cutting);
            output.writeObject(_cutting_name);
            output.writeObject(_font_offset);
            output.writeObject(_font_size);
            output.writeObject(_fontv_offset);
            output.writeObject(_fontv_size);
            output.writeObject(_frame);
            output.writeObject(_frame_name);
            output.writeObject(_height);
            output.writeObject(_height_add);
            output.writeObject(_id);
            output.writeObject(_is_duplex);
            output.writeObject(_is_pdf);
            output.writeObject(_is_sheet_ready);
            output.writeObject(_is_tech_bot);
            output.writeObject(_is_tech_center);
            output.writeObject(_is_tech_stair_bot);
            output.writeObject(_is_tech_stair_top);
            output.writeObject(_is_tech_top);
            output.writeObject(_lab_type);
            output.writeObject(_lab_type_name);
            output.writeObject(_mark_offset);
            output.writeObject(_mark_size);
            output.writeObject(_notching);
            output.writeObject(_page_hoffset);
            output.writeObject(_page_len);
            output.writeObject(_page_width);
            output.writeObject(_paper);
            output.writeObject(_paper_name);
            output.writeObject(_queue_offset);
            output.writeObject(_queue_size);
            output.writeObject(_reprint_offset);
            output.writeObject(_reprint_size);
            output.writeObject(_revers);
            output.writeObject(_sheet_len);
            output.writeObject(_sheet_width);
            output.writeObject(_stroke);
            output.writeObject(_tech_add);
            output.writeObject(_tech_bar);
            output.writeObject(_tech_bar_boffset);
            output.writeObject(_tech_bar_color);
            output.writeObject(_tech_bar_offset);
            output.writeObject(_tech_bar_step);
            output.writeObject(_tech_bar_toffset);
            output.writeObject(_tech_stair_add);
            output.writeObject(_tech_stair_step);
            output.writeObject(_width);
        }
    }
}