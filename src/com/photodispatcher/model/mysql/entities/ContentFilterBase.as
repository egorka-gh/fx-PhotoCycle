/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (ContentFilter.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;

    [Bindable]
    public class ContentFilterBase extends AbstractEntity {

        public function ContentFilterBase() {
            super();
        }

        private var _id:int;
        private var _is_alias_filter:Boolean;
        private var _is_photo_allow:Boolean;
        private var _is_pro_allow:Boolean;
        private var _is_retail_allow:Boolean;
        private var _name:String;

        public function set id(value:int):void {
            _id = value;
        }
        public function get id():int {
            return _id;
        }

        public function set is_alias_filter(value:Boolean):void {
            _is_alias_filter = value;
        }
        public function get is_alias_filter():Boolean {
            return _is_alias_filter;
        }

        public function set is_photo_allow(value:Boolean):void {
            _is_photo_allow = value;
        }
        public function get is_photo_allow():Boolean {
            return _is_photo_allow;
        }

        public function set is_pro_allow(value:Boolean):void {
            _is_pro_allow = value;
        }
        public function get is_pro_allow():Boolean {
            return _is_pro_allow;
        }

        public function set is_retail_allow(value:Boolean):void {
            _is_retail_allow = value;
        }
        public function get is_retail_allow():Boolean {
            return _is_retail_allow;
        }

        public function set name(value:String):void {
            _name = value;
        }
        public function get name():String {
            return _name;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _id = input.readObject() as int;
            _is_alias_filter = input.readObject() as Boolean;
            _is_photo_allow = input.readObject() as Boolean;
            _is_pro_allow = input.readObject() as Boolean;
            _is_retail_allow = input.readObject() as Boolean;
            _name = input.readObject() as String;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject(_id);
            output.writeObject(_is_alias_filter);
            output.writeObject(_is_photo_allow);
            output.writeObject(_is_pro_allow);
            output.writeObject(_is_retail_allow);
            output.writeObject(_name);
        }
    }
}