/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (Source.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;
    import org.granite.tide.IPropertyHolder;

    [Bindable]
    public class SourceBase extends AbstractEntity {

        private var _code:String;
        private var _fbookService:SourceSvc;
        private var _ftpService:SourceSvc;
        private var _hotFolder:SourceSvc;
        private var _id:int;
        private var _loc_type:int;
        private var _name:String;
        private var _online:Boolean;
        private var _sync:int;
        private var _sync_date:Date;
        private var _sync_state:Boolean;
        private var _type:int;
        private var _type_name:String;
        private var _webService:SourceSvc;

        public function set code(value:String):void {
            _code = value;
        }
        public function get code():String {
            return _code;
        }

        public function set fbookService(value:SourceSvc):void {
            _fbookService = value;
        }
        public function get fbookService():SourceSvc {
            return _fbookService;
        }

        public function set ftpService(value:SourceSvc):void {
            _ftpService = value;
        }
        public function get ftpService():SourceSvc {
            return _ftpService;
        }

        public function set hotFolder(value:SourceSvc):void {
            _hotFolder = value;
        }
        public function get hotFolder():SourceSvc {
            return _hotFolder;
        }

        public function set id(value:int):void {
            _id = value;
        }
        public function get id():int {
            return _id;
        }

        public function set loc_type(value:int):void {
            _loc_type = value;
        }
        public function get loc_type():int {
            return _loc_type;
        }

        public function set name(value:String):void {
            _name = value;
        }
        public function get name():String {
            return _name;
        }

        public function set online(value:Boolean):void {
            _online = value;
        }
        public function get online():Boolean {
            return _online;
        }

        public function set sync(value:int):void {
            _sync = value;
        }
        public function get sync():int {
            return _sync;
        }

        public function set sync_date(value:Date):void {
            _sync_date = value;
        }
        public function get sync_date():Date {
            return _sync_date;
        }

        public function set sync_state(value:Boolean):void {
            _sync_state = value;
        }
        public function get sync_state():Boolean {
            return _sync_state;
        }

        public function set type(value:int):void {
            _type = value;
        }
        public function get type():int {
            return _type;
        }

        public function set type_name(value:String):void {
            _type_name = value;
        }
        public function get type_name():String {
            return _type_name;
        }

        public function set webService(value:SourceSvc):void {
            _webService = value;
        }
        public function get webService():SourceSvc {
            return _webService;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _code = input.readObject() as String;
            _fbookService = input.readObject() as SourceSvc;
            _ftpService = input.readObject() as SourceSvc;
            _hotFolder = input.readObject() as SourceSvc;
            _id = input.readObject() as int;
            _loc_type = input.readObject() as int;
            _name = input.readObject() as String;
            _online = input.readObject() as Boolean;
            _sync = input.readObject() as int;
            _sync_date = input.readObject() as Date;
            _sync_state = input.readObject() as Boolean;
            _type = input.readObject() as int;
            _type_name = input.readObject() as String;
            _webService = input.readObject() as SourceSvc;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject((_code is IPropertyHolder) ? IPropertyHolder(_code).object : _code);
            output.writeObject((_fbookService is IPropertyHolder) ? IPropertyHolder(_fbookService).object : _fbookService);
            output.writeObject((_ftpService is IPropertyHolder) ? IPropertyHolder(_ftpService).object : _ftpService);
            output.writeObject((_hotFolder is IPropertyHolder) ? IPropertyHolder(_hotFolder).object : _hotFolder);
            output.writeObject((_id is IPropertyHolder) ? IPropertyHolder(_id).object : _id);
            output.writeObject((_loc_type is IPropertyHolder) ? IPropertyHolder(_loc_type).object : _loc_type);
            output.writeObject((_name is IPropertyHolder) ? IPropertyHolder(_name).object : _name);
            output.writeObject((_online is IPropertyHolder) ? IPropertyHolder(_online).object : _online);
            output.writeObject((_sync is IPropertyHolder) ? IPropertyHolder(_sync).object : _sync);
            output.writeObject((_sync_date is IPropertyHolder) ? IPropertyHolder(_sync_date).object : _sync_date);
            output.writeObject((_sync_state is IPropertyHolder) ? IPropertyHolder(_sync_state).object : _sync_state);
            output.writeObject((_type is IPropertyHolder) ? IPropertyHolder(_type).object : _type);
            output.writeObject((_type_name is IPropertyHolder) ? IPropertyHolder(_type_name).object : _type_name);
            output.writeObject((_webService is IPropertyHolder) ? IPropertyHolder(_webService).object : _webService);
        }
    }
}