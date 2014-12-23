/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (LabRoll.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;
    import org.granite.tide.IPropertyHolder;

    [Bindable]
    public class LabRollBase extends AbstractEntity {

        public function LabRollBase() {
            super();
        }

        private var _is_online:Boolean;
        private var _is_used:Boolean;
        private var _lab_device:int;
        private var _len:int;
        private var _len_std:int;
        private var _paper:int;
        private var _paper_name:String;
        private var _width:int;

        public function set is_online(value:Boolean):void {
            _is_online = value;
        }
        public function get is_online():Boolean {
            return _is_online;
        }

        public function set is_used(value:Boolean):void {
            _is_used = value;
        }
        public function get is_used():Boolean {
            return _is_used;
        }

        public function set lab_device(value:int):void {
            _lab_device = value;
        }
        public function get lab_device():int {
            return _lab_device;
        }

        public function set len(value:int):void {
            _len = value;
        }
        public function get len():int {
            return _len;
        }

        public function set len_std(value:int):void {
            _len_std = value;
        }
        public function get len_std():int {
            return _len_std;
        }

        public function set paper(value:int):void {
            _paper = value;
        }
        public function get paper():int {
            return _paper;
        }

        public function set paper_name(value:String):void {
            _paper_name = value;
        }
        public function get paper_name():String {
            return _paper_name;
        }

        public function set width(value:int):void {
            _width = value;
        }
        public function get width():int {
            return _width;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _is_online = input.readObject() as Boolean;
            _is_used = input.readObject() as Boolean;
            _lab_device = input.readObject() as int;
            _len = input.readObject() as int;
            _len_std = input.readObject() as int;
            _paper = input.readObject() as int;
            _paper_name = input.readObject() as String;
            _width = input.readObject() as int;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject((_is_online is IPropertyHolder) ? IPropertyHolder(_is_online).object : _is_online);
            output.writeObject((_is_used is IPropertyHolder) ? IPropertyHolder(_is_used).object : _is_used);
            output.writeObject((_lab_device is IPropertyHolder) ? IPropertyHolder(_lab_device).object : _lab_device);
            output.writeObject((_len is IPropertyHolder) ? IPropertyHolder(_len).object : _len);
            output.writeObject((_len_std is IPropertyHolder) ? IPropertyHolder(_len_std).object : _len_std);
            output.writeObject((_paper is IPropertyHolder) ? IPropertyHolder(_paper).object : _paper);
            output.writeObject((_paper_name is IPropertyHolder) ? IPropertyHolder(_paper_name).object : _paper_name);
            output.writeObject((_width is IPropertyHolder) ? IPropertyHolder(_width).object : _width);
        }
    }
}