/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (SubOrder.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;
    import org.granite.tide.IPropertyHolder;

    [Bindable]
    public class SubOrderBase extends AbstractEntity {

        public function SubOrderBase() {
            super();
        }

        private var _alias:String;
        private var _books_done:int;
        private var _color_corr:Boolean;
        private var _extraInfo:OrderExtraInfo;
        private var _ftp_folder:String;
        private var _order_id:String;
        private var _proj_type:int;
        private var _proj_type_name:String;
        private var _prt_qty:int;
        private var _source_code:String;
        private var _source_name:String;
        private var _src_type:int;
        private var _src_type_name:String;
        private var _state:int;
        private var _state_date:Date;
        private var _state_name:String;
        private var _sub_id:String;

        public function set alias(value:String):void {
            _alias = value;
        }
        public function get alias():String {
            return _alias;
        }

        public function set books_done(value:int):void {
            _books_done = value;
        }
        public function get books_done():int {
            return _books_done;
        }

        public function set color_corr(value:Boolean):void {
            _color_corr = value;
        }
        public function get color_corr():Boolean {
            return _color_corr;
        }

        public function set extraInfo(value:OrderExtraInfo):void {
            _extraInfo = value;
        }
        public function get extraInfo():OrderExtraInfo {
            return _extraInfo;
        }

        public function set ftp_folder(value:String):void {
            _ftp_folder = value;
        }
        public function get ftp_folder():String {
            return _ftp_folder;
        }

        public function set order_id(value:String):void {
            _order_id = value;
        }
        public function get order_id():String {
            return _order_id;
        }

        public function set proj_type(value:int):void {
            _proj_type = value;
        }
        public function get proj_type():int {
            return _proj_type;
        }

        public function set proj_type_name(value:String):void {
            _proj_type_name = value;
        }
        public function get proj_type_name():String {
            return _proj_type_name;
        }

        public function set prt_qty(value:int):void {
            _prt_qty = value;
        }
        public function get prt_qty():int {
            return _prt_qty;
        }

        public function set source_code(value:String):void {
            _source_code = value;
        }
        public function get source_code():String {
            return _source_code;
        }

        public function set source_name(value:String):void {
            _source_name = value;
        }
        public function get source_name():String {
            return _source_name;
        }

        public function set src_type(value:int):void {
            _src_type = value;
        }
        public function get src_type():int {
            return _src_type;
        }

        public function set src_type_name(value:String):void {
            _src_type_name = value;
        }
        public function get src_type_name():String {
            return _src_type_name;
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
            _alias = input.readObject() as String;
            _books_done = input.readObject() as int;
            _color_corr = input.readObject() as Boolean;
            _extraInfo = input.readObject() as OrderExtraInfo;
            _ftp_folder = input.readObject() as String;
            _order_id = input.readObject() as String;
            _proj_type = input.readObject() as int;
            _proj_type_name = input.readObject() as String;
            _prt_qty = input.readObject() as int;
            _source_code = input.readObject() as String;
            _source_name = input.readObject() as String;
            _src_type = input.readObject() as int;
            _src_type_name = input.readObject() as String;
            _state = input.readObject() as int;
            _state_date = input.readObject() as Date;
            _state_name = input.readObject() as String;
            _sub_id = input.readObject() as String;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject((_alias is IPropertyHolder) ? IPropertyHolder(_alias).object : _alias);
            output.writeObject((_books_done is IPropertyHolder) ? IPropertyHolder(_books_done).object : _books_done);
            output.writeObject((_color_corr is IPropertyHolder) ? IPropertyHolder(_color_corr).object : _color_corr);
            output.writeObject((_extraInfo is IPropertyHolder) ? IPropertyHolder(_extraInfo).object : _extraInfo);
            output.writeObject((_ftp_folder is IPropertyHolder) ? IPropertyHolder(_ftp_folder).object : _ftp_folder);
            output.writeObject((_order_id is IPropertyHolder) ? IPropertyHolder(_order_id).object : _order_id);
            output.writeObject((_proj_type is IPropertyHolder) ? IPropertyHolder(_proj_type).object : _proj_type);
            output.writeObject((_proj_type_name is IPropertyHolder) ? IPropertyHolder(_proj_type_name).object : _proj_type_name);
            output.writeObject((_prt_qty is IPropertyHolder) ? IPropertyHolder(_prt_qty).object : _prt_qty);
            output.writeObject((_source_code is IPropertyHolder) ? IPropertyHolder(_source_code).object : _source_code);
            output.writeObject((_source_name is IPropertyHolder) ? IPropertyHolder(_source_name).object : _source_name);
            output.writeObject((_src_type is IPropertyHolder) ? IPropertyHolder(_src_type).object : _src_type);
            output.writeObject((_src_type_name is IPropertyHolder) ? IPropertyHolder(_src_type_name).object : _src_type_name);
            output.writeObject((_state is IPropertyHolder) ? IPropertyHolder(_state).object : _state);
            output.writeObject((_state_date is IPropertyHolder) ? IPropertyHolder(_state_date).object : _state_date);
            output.writeObject((_state_name is IPropertyHolder) ? IPropertyHolder(_state_name).object : _state_name);
            output.writeObject((_sub_id is IPropertyHolder) ? IPropertyHolder(_sub_id).object : _sub_id);
        }
    }
}