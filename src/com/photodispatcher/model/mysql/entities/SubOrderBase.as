/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
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

        private var _ftp_folder:String;
        private var _order_id:String;
        private var _proj_type:int;
        private var _prt_qty:int;
        private var _src_type:int;
        private var _state:int;
        private var _state_date:Date;
        private var _sub_id:String;

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

        public function set prt_qty(value:int):void {
            _prt_qty = value;
        }
        public function get prt_qty():int {
            return _prt_qty;
        }

        public function set src_type(value:int):void {
            _src_type = value;
        }
        public function get src_type():int {
            return _src_type;
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

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _ftp_folder = input.readObject() as String;
            _order_id = input.readObject() as String;
            _proj_type = input.readObject() as int;
            _prt_qty = input.readObject() as int;
            _src_type = input.readObject() as int;
            _state = input.readObject() as int;
            _state_date = input.readObject() as Date;
            _sub_id = input.readObject() as String;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject((_ftp_folder is IPropertyHolder) ? IPropertyHolder(_ftp_folder).object : _ftp_folder);
            output.writeObject((_order_id is IPropertyHolder) ? IPropertyHolder(_order_id).object : _order_id);
            output.writeObject((_proj_type is IPropertyHolder) ? IPropertyHolder(_proj_type).object : _proj_type);
            output.writeObject((_prt_qty is IPropertyHolder) ? IPropertyHolder(_prt_qty).object : _prt_qty);
            output.writeObject((_src_type is IPropertyHolder) ? IPropertyHolder(_src_type).object : _src_type);
            output.writeObject((_state is IPropertyHolder) ? IPropertyHolder(_state).object : _state);
            output.writeObject((_state_date is IPropertyHolder) ? IPropertyHolder(_state_date).object : _state_date);
            output.writeObject((_sub_id is IPropertyHolder) ? IPropertyHolder(_sub_id).object : _sub_id);
        }
    }
}