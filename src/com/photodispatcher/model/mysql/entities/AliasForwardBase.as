/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (AliasForward.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;
    import org.granite.tide.IPropertyHolder;

    [Bindable]
    public class AliasForwardBase extends AbstractEntity {

        public function AliasForwardBase() {
            super();
        }

        private var _alias:String;
        private var _id:int;
        private var _state:int;
        private var _state_name:String;

        public function set alias(value:String):void {
            _alias = value;
        }
        public function get alias():String {
            return _alias;
        }

        public function set id(value:int):void {
            _id = value;
        }
        public function get id():int {
            return _id;
        }

        public function set state(value:int):void {
            _state = value;
        }
        public function get state():int {
            return _state;
        }

        public function set state_name(value:String):void {
            _state_name = value;
        }
        public function get state_name():String {
            return _state_name;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _alias = input.readObject() as String;
            _id = input.readObject() as int;
            _state = input.readObject() as int;
            _state_name = input.readObject() as String;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject((_alias is IPropertyHolder) ? IPropertyHolder(_alias).object : _alias);
            output.writeObject((_id is IPropertyHolder) ? IPropertyHolder(_id).object : _id);
            output.writeObject((_state is IPropertyHolder) ? IPropertyHolder(_state).object : _state);
            output.writeObject((_state_name is IPropertyHolder) ? IPropertyHolder(_state_name).object : _state_name);
        }
    }
}