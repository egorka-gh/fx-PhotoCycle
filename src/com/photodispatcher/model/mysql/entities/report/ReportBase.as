/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (Report.as).
 */

package com.photodispatcher.model.mysql.entities.report {

    import com.photodispatcher.model.mysql.entities.AbstractEntity;
    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;
    import org.granite.tide.IPropertyHolder;

    [Bindable]
    public class ReportBase extends AbstractEntity {

        private var _id:String;
        private var _name:String;
        private var _parameters:Array;
        private var _src_type:int;

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

        public function set parameters(value:Array):void {
            _parameters = value;
        }
        public function get parameters():Array {
            return _parameters;
        }

        public function set src_type(value:int):void {
            _src_type = value;
        }
        public function get src_type():int {
            return _src_type;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _id = input.readObject() as String;
            _name = input.readObject() as String;
            _parameters = input.readObject() as Array;
            _src_type = input.readObject() as int;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject((_id is IPropertyHolder) ? IPropertyHolder(_id).object : _id);
            output.writeObject((_name is IPropertyHolder) ? IPropertyHolder(_name).object : _name);
            output.writeObject((_parameters is IPropertyHolder) ? IPropertyHolder(_parameters).object : _parameters);
            output.writeObject((_src_type is IPropertyHolder) ? IPropertyHolder(_src_type).object : _src_type);
        }
    }
}