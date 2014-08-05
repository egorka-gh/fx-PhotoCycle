/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (LabDevice.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;
    import mx.collections.ListCollectionView;
    import org.granite.tide.IPropertyHolder;

    [Bindable]
    public class LabDeviceBase extends AbstractEntity {

        private var _id:int;
        private var _lab:int;
        private var _name:String;
        private var _rolls:ListCollectionView;
        private var _speed1:Number;
        private var _speed2:Number;
        private var _tech_point:int;
        private var _tech_point_name:String;
        private var _timetable:ListCollectionView;

        public function set id(value:int):void {
            _id = value;
        }
        public function get id():int {
            return _id;
        }

        public function set lab(value:int):void {
            _lab = value;
        }
        public function get lab():int {
            return _lab;
        }

        public function set name(value:String):void {
            _name = value;
        }
        public function get name():String {
            return _name;
        }

        public function set rolls(value:ListCollectionView):void {
            _rolls = value;
        }
        public function get rolls():ListCollectionView {
            return _rolls;
        }

        public function set speed1(value:Number):void {
            _speed1 = value;
        }
        public function get speed1():Number {
            return _speed1;
        }

        public function set speed2(value:Number):void {
            _speed2 = value;
        }
        public function get speed2():Number {
            return _speed2;
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

        public function set timetable(value:ListCollectionView):void {
            _timetable = value;
        }
        public function get timetable():ListCollectionView {
            return _timetable;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _id = input.readObject() as int;
            _lab = input.readObject() as int;
            _name = input.readObject() as String;
            _rolls = input.readObject() as ListCollectionView;
            _speed1 = function(o:*):Number { return (o is Number ? o as Number : Number.NaN) } (input.readObject());
            _speed2 = function(o:*):Number { return (o is Number ? o as Number : Number.NaN) } (input.readObject());
            _tech_point = input.readObject() as int;
            _tech_point_name = input.readObject() as String;
            _timetable = input.readObject() as ListCollectionView;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject((_id is IPropertyHolder) ? IPropertyHolder(_id).object : _id);
            output.writeObject((_lab is IPropertyHolder) ? IPropertyHolder(_lab).object : _lab);
            output.writeObject((_name is IPropertyHolder) ? IPropertyHolder(_name).object : _name);
            output.writeObject((_rolls is IPropertyHolder) ? IPropertyHolder(_rolls).object : _rolls);
            output.writeObject((_speed1 is IPropertyHolder) ? IPropertyHolder(_speed1).object : _speed1);
            output.writeObject((_speed2 is IPropertyHolder) ? IPropertyHolder(_speed2).object : _speed2);
            output.writeObject((_tech_point is IPropertyHolder) ? IPropertyHolder(_tech_point).object : _tech_point);
            output.writeObject((_tech_point_name is IPropertyHolder) ? IPropertyHolder(_tech_point_name).object : _tech_point_name);
            output.writeObject((_timetable is IPropertyHolder) ? IPropertyHolder(_timetable).object : _timetable);
        }
    }
}