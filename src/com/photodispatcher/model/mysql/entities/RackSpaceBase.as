/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (RackSpace.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;
    import mx.collections.ListCollectionView;

    [Bindable]
    public class RackSpaceBase extends AbstractEntity {

        public function RackSpaceBase() {
            super();
        }

        private var _empty:Boolean;
        private var _height:int;
        private var _id:int;
        private var _name:String;
        private var _orders:ListCollectionView;
        private var _rack:int;
        private var _rack_name:String;
        private var _rack_type_name:String;
        private var _rating:Number;
        private var _unused_weight:Number;
        private var _weight:Number;
        private var _width:int;

        public function set empty(value:Boolean):void {
            _empty = value;
        }
        public function get empty():Boolean {
            return _empty;
        }

        public function set height(value:int):void {
            _height = value;
        }
        public function get height():int {
            return _height;
        }

        public function set id(value:int):void {
            _id = value;
        }
        public function get id():int {
            return _id;
        }

        public function set name(value:String):void {
            _name = value;
        }
        public function get name():String {
            return _name;
        }

        public function set orders(value:ListCollectionView):void {
            _orders = value;
        }
        public function get orders():ListCollectionView {
            return _orders;
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

        public function set rack_type_name(value:String):void {
            _rack_type_name = value;
        }
        public function get rack_type_name():String {
            return _rack_type_name;
        }

        public function set rating(value:Number):void {
            _rating = value;
        }
        public function get rating():Number {
            return _rating;
        }

        public function set unused_weight(value:Number):void {
            _unused_weight = value;
        }
        public function get unused_weight():Number {
            return _unused_weight;
        }

        public function set weight(value:Number):void {
            _weight = value;
        }
        public function get weight():Number {
            return _weight;
        }

        public function set width(value:int):void {
            _width = value;
        }
        public function get width():int {
            return _width;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _empty = input.readObject() as Boolean;
            _height = input.readObject() as int;
            _id = input.readObject() as int;
            _name = input.readObject() as String;
            _orders = input.readObject() as ListCollectionView;
            _rack = input.readObject() as int;
            _rack_name = input.readObject() as String;
            _rack_type_name = input.readObject() as String;
            _rating = function(o:*):Number { return (o is Number ? o as Number : Number.NaN) } (input.readObject());
            _unused_weight = function(o:*):Number { return (o is Number ? o as Number : Number.NaN) } (input.readObject());
            _weight = function(o:*):Number { return (o is Number ? o as Number : Number.NaN) } (input.readObject());
            _width = input.readObject() as int;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject(_empty);
            output.writeObject(_height);
            output.writeObject(_id);
            output.writeObject(_name);
            output.writeObject(_orders);
            output.writeObject(_rack);
            output.writeObject(_rack_name);
            output.writeObject(_rack_type_name);
            output.writeObject(_rating);
            output.writeObject(_unused_weight);
            output.writeObject(_weight);
            output.writeObject(_width);
        }
    }
}