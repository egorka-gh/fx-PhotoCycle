/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (RackTechPoint.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;

    [Bindable]
    public class RackTechPointBase extends AbstractEntity {

        public function RackTechPointBase() {
            super();
        }

        private var _inuse:Boolean;
        private var _rack:int;
        private var _rack_name:String;
        private var _tech_point:int;
        private var _tech_point_name:String;

        public function set inuse(value:Boolean):void {
            _inuse = value;
        }
        public function get inuse():Boolean {
            return _inuse;
        }

        public function set rack(value:int):void {
            _rack = value;
        }
        public function get rack():int {
            return _rack;
        }

        public function set rack_name(value:String):void {
            _rack_name = value;
        }
        public function get rack_name():String {
            return _rack_name;
        }

        public function set tech_point(value:int):void {
            _tech_point = value;
        }
        public function get tech_point():int {
            return _tech_point;
        }

        public function set tech_point_name(value:String):void {
            _tech_point_name = value;
        }
        public function get tech_point_name():String {
            return _tech_point_name;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _inuse = input.readObject() as Boolean;
            _rack = input.readObject() as int;
            _rack_name = input.readObject() as String;
            _tech_point = input.readObject() as int;
            _tech_point_name = input.readObject() as String;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject(_inuse);
            output.writeObject(_rack);
            output.writeObject(_rack_name);
            output.writeObject(_tech_point);
            output.writeObject(_tech_point_name);
        }
    }
}