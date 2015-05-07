/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (AppConfig.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;
    import org.granite.tide.IPropertyHolder;

    [Bindable]
    public class AppConfigBase extends AbstractEntity {

        public function AppConfigBase() {
            super();
        }

        private var _clean_fs:Boolean;
        private var _clean_fs_days:int;
        private var _clean_fs_hour:int;
        private var _clean_fs_limit:int;
        private var _clean_fs_state:int;
        private var _id:int;
        private var _production:int;
        private var _production_name:String;

        public function set clean_fs(value:Boolean):void {
            _clean_fs = value;
        }
        public function get clean_fs():Boolean {
            return _clean_fs;
        }

        public function set clean_fs_days(value:int):void {
            _clean_fs_days = value;
        }
        public function get clean_fs_days():int {
            return _clean_fs_days;
        }

        public function set clean_fs_hour(value:int):void {
            _clean_fs_hour = value;
        }
        public function get clean_fs_hour():int {
            return _clean_fs_hour;
        }

        public function set clean_fs_limit(value:int):void {
            _clean_fs_limit = value;
        }
        public function get clean_fs_limit():int {
            return _clean_fs_limit;
        }

        public function set clean_fs_state(value:int):void {
            _clean_fs_state = value;
        }
        public function get clean_fs_state():int {
            return _clean_fs_state;
        }

        public function set id(value:int):void {
            _id = value;
        }
        public function get id():int {
            return _id;
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

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _clean_fs = input.readObject() as Boolean;
            _clean_fs_days = input.readObject() as int;
            _clean_fs_hour = input.readObject() as int;
            _clean_fs_limit = input.readObject() as int;
            _clean_fs_state = input.readObject() as int;
            _id = input.readObject() as int;
            _production = input.readObject() as int;
            _production_name = input.readObject() as String;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject((_clean_fs is IPropertyHolder) ? IPropertyHolder(_clean_fs).object : _clean_fs);
            output.writeObject((_clean_fs_days is IPropertyHolder) ? IPropertyHolder(_clean_fs_days).object : _clean_fs_days);
            output.writeObject((_clean_fs_hour is IPropertyHolder) ? IPropertyHolder(_clean_fs_hour).object : _clean_fs_hour);
            output.writeObject((_clean_fs_limit is IPropertyHolder) ? IPropertyHolder(_clean_fs_limit).object : _clean_fs_limit);
            output.writeObject((_clean_fs_state is IPropertyHolder) ? IPropertyHolder(_clean_fs_state).object : _clean_fs_state);
            output.writeObject((_id is IPropertyHolder) ? IPropertyHolder(_id).object : _id);
            output.writeObject((_production is IPropertyHolder) ? IPropertyHolder(_production).object : _production);
            output.writeObject((_production_name is IPropertyHolder) ? IPropertyHolder(_production_name).object : _production_name);
        }
    }
}