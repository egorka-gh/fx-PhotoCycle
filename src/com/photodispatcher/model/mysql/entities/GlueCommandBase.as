/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (GlueCommand.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;
    import org.granite.tide.IPropertyHolder;

    [Bindable]
    public class GlueCommandBase extends AbstractEntity {

        public function GlueCommandBase() {
            super();
        }

        private var _cmd:String;
        private var _id:int;

        public function set cmd(value:String):void {
            _cmd = value;
        }
        public function get cmd():String {
            return _cmd;
        }

        public function set id(value:int):void {
            _id = value;
        }
        public function get id():int {
            return _id;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _cmd = input.readObject() as String;
            _id = input.readObject() as int;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject((_cmd is IPropertyHolder) ? IPropertyHolder(_cmd).object : _cmd);
            output.writeObject((_id is IPropertyHolder) ? IPropertyHolder(_id).object : _id);
        }
    }
}