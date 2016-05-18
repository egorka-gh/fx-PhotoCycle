/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (CycleStation.as).
 */

package com.photodispatcher.model.mysql.entities.messenger {

    import com.photodispatcher.model.mysql.entities.AbstractEntity;
    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;
    import org.granite.tide.IPropertyHolder;

    [Bindable]
    public class CycleStationBase extends AbstractEntity {

        public function CycleStationBase() {
            super();
        }

        private var _id:String;
        private var _name:String;
        private var _state:int;
        private var _subtype:int;
        private var _type:int;
        private var _type_name:String;

        public function set id(value:String):void {
            _id = value;
        }
        public function get id():String {
            return _id;
        }

        public function set name(value:String):void {
            _name = value;
        }
        public function get name():String {
            return _name;
        }

        public function set state(value:int):void {
            _state = value;
        }
        public function get state():int {
            return _state;
        }

        public function set subtype(value:int):void {
            _subtype = value;
        }
        public function get subtype():int {
            return _subtype;
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

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _id = input.readObject() as String;
            _name = input.readObject() as String;
            _state = input.readObject() as int;
            _subtype = input.readObject() as int;
            _type = input.readObject() as int;
            _type_name = input.readObject() as String;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject((_id is IPropertyHolder) ? IPropertyHolder(_id).object : _id);
            output.writeObject((_name is IPropertyHolder) ? IPropertyHolder(_name).object : _name);
            output.writeObject((_state is IPropertyHolder) ? IPropertyHolder(_state).object : _state);
            output.writeObject((_subtype is IPropertyHolder) ? IPropertyHolder(_subtype).object : _subtype);
            output.writeObject((_type is IPropertyHolder) ? IPropertyHolder(_type).object : _type);
            output.writeObject((_type_name is IPropertyHolder) ? IPropertyHolder(_type_name).object : _type_name);
        }
    }
}