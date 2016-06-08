/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (Order.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;
    import mx.collections.ListCollectionView;

    [Bindable]
    public class OrderBase extends AbstractEntity {

        public function OrderBase() {
            super();
        }

        private var _clean_fs:Boolean;
        private var _clientId:int;
        private var _data_ts:String;
        private var _extraInfo:OrderExtraInfo;
        private var _extraState:ListCollectionView;
        private var _extraStateProlong:ListCollectionView;
        private var _forward_state:int;
        private var _fotos_num:int;
        private var _ftp_folder:String;
        private var _groupId:int;
        private var _id:String;
        private var _is_preload:Boolean;
        private var _local_folder:String;
        private var _printGroups:ListCollectionView;
        private var _production:int;
        private var _production_name:String;
        private var _resume_load:Boolean;
        private var _source:int;
        private var _source_code:String;
        private var _source_name:String;
        private var _src_date:Date;
        private var _src_id:String;
        private var _state:int;
        private var _stateLog:ListCollectionView;
        private var _state_date:Date;
        private var _state_name:String;
        private var _suborders:ListCollectionView;
        private var _sync:int;
        private var _tag:String;
        private var _techLog:ListCollectionView;

        public function set clean_fs(value:Boolean):void {
            _clean_fs = value;
        }
        public function get clean_fs():Boolean {
            return _clean_fs;
        }

        public function set clientId(value:int):void {
            _clientId = value;
        }
        public function get clientId():int {
            return _clientId;
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

        public function set extraState(value:ListCollectionView):void {
            _extraState = value;
        }
        public function get extraState():ListCollectionView {
            return _extraState;
        }

        public function set extraStateProlong(value:ListCollectionView):void {
            _extraStateProlong = value;
        }
        public function get extraStateProlong():ListCollectionView {
            return _extraStateProlong;
        }

        public function set forward_state(value:int):void {
            _forward_state = value;
        }
        public function get forward_state():int {
            return _forward_state;
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

        public function set groupId(value:int):void {
            _groupId = value;
        }
        public function get groupId():int {
            return _groupId;
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

        public function set production(value:int):void {
            _production = value;
        }
        public function get production():int {
            return _production;
        }

        public function set production_name(value:String):void {
            _production_name = value;
        }
        public function get production_name():String {
            return _production_name;
        }

        public function set resume_load(value:Boolean):void {
            _resume_load = value;
        }
        public function get resume_load():Boolean {
            return _resume_load;
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

        public function set stateLog(value:ListCollectionView):void {
            _stateLog = value;
        }
        public function get stateLog():ListCollectionView {
            return _stateLog;
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

        public function set tag(value:String):void {
            _tag = value;
        }
        public function get tag():String {
            return _tag;
        }

        public function set techLog(value:ListCollectionView):void {
            _techLog = value;
        }
        public function get techLog():ListCollectionView {
            return _techLog;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _clean_fs = input.readObject() as Boolean;
            _clientId = input.readObject() as int;
            _data_ts = input.readObject() as String;
            _extraInfo = input.readObject() as OrderExtraInfo;
            _extraState = input.readObject() as ListCollectionView;
            _extraStateProlong = input.readObject() as ListCollectionView;
            _forward_state = input.readObject() as int;
            _fotos_num = input.readObject() as int;
            _ftp_folder = input.readObject() as String;
            _groupId = input.readObject() as int;
            _id = input.readObject() as String;
            _is_preload = input.readObject() as Boolean;
            _local_folder = input.readObject() as String;
            _printGroups = input.readObject() as ListCollectionView;
            _production = input.readObject() as int;
            _production_name = input.readObject() as String;
            _resume_load = input.readObject() as Boolean;
            _source = input.readObject() as int;
            _source_code = input.readObject() as String;
            _source_name = input.readObject() as String;
            _src_date = input.readObject() as Date;
            _src_id = input.readObject() as String;
            _state = input.readObject() as int;
            _stateLog = input.readObject() as ListCollectionView;
            _state_date = input.readObject() as Date;
            _state_name = input.readObject() as String;
            _suborders = input.readObject() as ListCollectionView;
            _sync = input.readObject() as int;
            _tag = input.readObject() as String;
            _techLog = input.readObject() as ListCollectionView;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject(_clean_fs);
            output.writeObject(_clientId);
            output.writeObject(_data_ts);
            output.writeObject(_extraInfo);
            output.writeObject(_extraState);
            output.writeObject(_extraStateProlong);
            output.writeObject(_forward_state);
            output.writeObject(_fotos_num);
            output.writeObject(_ftp_folder);
            output.writeObject(_groupId);
            output.writeObject(_id);
            output.writeObject(_is_preload);
            output.writeObject(_local_folder);
            output.writeObject(_printGroups);
            output.writeObject(_production);
            output.writeObject(_production_name);
            output.writeObject(_resume_load);
            output.writeObject(_source);
            output.writeObject(_source_code);
            output.writeObject(_source_name);
            output.writeObject(_src_date);
            output.writeObject(_src_id);
            output.writeObject(_state);
            output.writeObject(_stateLog);
            output.writeObject(_state_date);
            output.writeObject(_state_name);
            output.writeObject(_suborders);
            output.writeObject(_sync);
            output.writeObject(_tag);
            output.writeObject(_techLog);
        }
    }
}