/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (SubordersTemplate.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;
    import org.granite.tide.IPropertyHolder;

    [Bindable]
    public class SubordersTemplateBase extends AbstractEntity {

        private var _folder:String;
        private var _id:int;
        private var _src_type:int;
        private var _sub_src_type:int;

        public function set folder(value:String):void {
            _folder = value;
        }
        public function get folder():String {
            return _folder;
        }

        public function set id(value:int):void {
            _id = value;
        }
        public function get id():int {
            return _id;
        }

        public function set src_type(value:int):void {
            _src_type = value;
        }
        public function get src_type():int {
            return _src_type;
        }

        public function set sub_src_type(value:int):void {
            _sub_src_type = value;
        }
        public function get sub_src_type():int {
            return _sub_src_type;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _folder = input.readObject() as String;
            _id = input.readObject() as int;
            _src_type = input.readObject() as int;
            _sub_src_type = input.readObject() as int;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject((_folder is IPropertyHolder) ? IPropertyHolder(_folder).object : _folder);
            output.writeObject((_id is IPropertyHolder) ? IPropertyHolder(_id).object : _id);
            output.writeObject((_src_type is IPropertyHolder) ? IPropertyHolder(_src_type).object : _src_type);
            output.writeObject((_sub_src_type is IPropertyHolder) ? IPropertyHolder(_sub_src_type).object : _sub_src_type);
        }
    }
}