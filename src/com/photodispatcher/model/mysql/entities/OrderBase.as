/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (Order.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;
    import mx.collections.ListCollectionView;
    import org.granite.tide.IPropertyHolder;

    [Bindable]
    public class OrderBase extends AbstractEntity {

        private var _book_type:int;
        private var _data_ts:String;
        private var _extraInfo:OrderExtraInfo;
        private var _fotos_num:int;
        private var _ftp_folder:String;
        private var _id:String;
        private var _is_preload:Boolean;
        private var _local_folder:String;
        private var _printGroups:ListCollectionView;
        private var _source:int;
        private var _source_code:String;
        private var _source_name:String;
        private var _src_date:Date;
        private var _src_id:String;
        private var _state:int;
        private var _state_date:Date;
        private var _state_name:String;
        private var _suborders:ListCollectionView;
        private var _sync:int;

        public function set book_type(value:int):void {
            _book_type = value;
        }
        public function get book_type():int {
            return _book_type;
        }

        public function set data_ts(value:String):void {
            _data_ts = value;
        }
        public function get data_ts():String {
            return _data_ts;
        }

        public function set extraInfo(value:OrderExtraInfo):void {
            _extraInfo = value;
        }
        public function get extraInfo():OrderExtraInfo {
            return _extraInfo;
        }

        public function set fotos_num(value:int):void {
            _fotos_num = value;
        }
        public function get fotos_num():int {
            return _fotos_num;
        }

        public function set ftp_folder(value:String):void {
            _ftp_folder = value;
        }
        public function get ftp_folder():String {
            return _ftp_folder;
        }

        public function set id(value:String):void {
            _id = value;
        }
        public function get id():String {
            return _id;
        }

        public function set is_preload(value:Boolean):void {
            _is_preload = value;
        }
        public function get is_preload():Boolean {
            return _is_preload;
        }

        public function set local_folder(value:String):void {
            _local_folder = value;
        }
        public function get local_folder():String {
            return _local_folder;
        }

        public function set printGroups(value:ListCollectionView):void {
            _printGroups = value;
        }
        public function get printGroups():ListCollectionView {
            return _printGroups;
        }

        public function set source(value:int):void {
            _source = value;
        }
        public function get source():int {
            return _source;
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

        public function set src_date(value:Date):void {
            _src_date = value;
        }
        public function get src_date():Date {
            return _src_date;
        }

        public function set src_id(value:String):void {
            _src_id = value;
        }
        public function get src_id():String {
            return _src_id;
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

        public function set suborders(value:ListCollectionView):void {
            _suborders = value;
        }
        public function get suborders():ListCollectionView {
            return _suborders;
        }

        public function set sync(value:int):void {
            _sync = value;
        }
        public function get sync():int {
            return _sync;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _book_type = input.readObject() as int;
            _data_ts = input.readObject() as String;
            _extraInfo = input.readObject() as OrderExtraInfo;
            _fotos_num = input.readObject() as int;
            _ftp_folder = input.readObject() as String;
            _id = input.readObject() as String;
            _is_preload = input.readObject() as Boolean;
            _local_folder = input.readObject() as String;
            _printGroups = input.readObject() as ListCollectionView;
            _source = input.readObject() as int;
            _source_code = input.readObject() as String;
            _source_name = input.readObject() as String;
            _src_date = input.readObject() as Date;
            _src_id = input.readObject() as String;
            _state = input.readObject() as int;
            _state_date = input.readObject() as Date;
            _state_name = input.readObject() as String;
            _suborders = input.readObject() as ListCollectionView;
            _sync = input.readObject() as int;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject((_book_type is IPropertyHolder) ? IPropertyHolder(_book_type).object : _book_type);
            output.writeObject((_data_ts is IPropertyHolder) ? IPropertyHolder(_data_ts).object : _data_ts);
            output.writeObject((_extraInfo is IPropertyHolder) ? IPropertyHolder(_extraInfo).object : _extraInfo);
            output.writeObject((_fotos_num is IPropertyHolder) ? IPropertyHolder(_fotos_num).object : _fotos_num);
            output.writeObject((_ftp_folder is IPropertyHolder) ? IPropertyHolder(_ftp_folder).object : _ftp_folder);
            output.writeObject((_id is IPropertyHolder) ? IPropertyHolder(_id).object : _id);
            output.writeObject((_is_preload is IPropertyHolder) ? IPropertyHolder(_is_preload).object : _is_preload);
            output.writeObject((_local_folder is IPropertyHolder) ? IPropertyHolder(_local_folder).object : _local_folder);
            output.writeObject((_printGroups is IPropertyHolder) ? IPropertyHolder(_printGroups).object : _printGroups);
            output.writeObject((_source is IPropertyHolder) ? IPropertyHolder(_source).object : _source);
            output.writeObject((_source_code is IPropertyHolder) ? IPropertyHolder(_source_code).object : _source_code);
            output.writeObject((_source_name is IPropertyHolder) ? IPropertyHolder(_source_name).object : _source_name);
            output.writeObject((_src_date is IPropertyHolder) ? IPropertyHolder(_src_date).object : _src_date);
            output.writeObject((_src_id is IPropertyHolder) ? IPropertyHolder(_src_id).object : _src_id);
            output.writeObject((_state is IPropertyHolder) ? IPropertyHolder(_state).object : _state);
            output.writeObject((_state_date is IPropertyHolder) ? IPropertyHolder(_state_date).object : _state_date);
            output.writeObject((_state_name is IPropertyHolder) ? IPropertyHolder(_state_name).object : _state_name);
            output.writeObject((_suborders is IPropertyHolder) ? IPropertyHolder(_suborders).object : _suborders);
            output.writeObject((_sync is IPropertyHolder) ? IPropertyHolder(_sync).object : _sync);
        }
    }
}