/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (LayerSequence.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;
    import org.granite.tide.IPropertyHolder;

    [Bindable]
    public class LayerSequenceBase extends AbstractEntity {

        private var _layer_group:int;
        private var _layerset:int;
        private var _seqlayer:int;
        private var _seqlayer_name:String;
        private var _seqorder:int;

        public function set layer_group(value:int):void {
            _layer_group = value;
        }
        public function get layer_group():int {
            return _layer_group;
        }

        public function set layerset(value:int):void {
            _layerset = value;
        }
        public function get layerset():int {
            return _layerset;
        }

        public function set seqlayer(value:int):void {
            _seqlayer = value;
        }
        public function get seqlayer():int {
            return _seqlayer;
        }

        public function set seqlayer_name(value:String):void {
            _seqlayer_name = value;
        }
        public function get seqlayer_name():String {
            return _seqlayer_name;
        }

        public function set seqorder(value:int):void {
            _seqorder = value;
        }
        public function get seqorder():int {
            return _seqorder;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _layer_group = input.readObject() as int;
            _layerset = input.readObject() as int;
            _seqlayer = input.readObject() as int;
            _seqlayer_name = input.readObject() as String;
            _seqorder = input.readObject() as int;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject((_layer_group is IPropertyHolder) ? IPropertyHolder(_layer_group).object : _layer_group);
            output.writeObject((_layerset is IPropertyHolder) ? IPropertyHolder(_layerset).object : _layerset);
            output.writeObject((_seqlayer is IPropertyHolder) ? IPropertyHolder(_seqlayer).object : _seqlayer);
            output.writeObject((_seqlayer_name is IPropertyHolder) ? IPropertyHolder(_seqlayer_name).object : _seqlayer_name);
            output.writeObject((_seqorder is IPropertyHolder) ? IPropertyHolder(_seqorder).object : _seqorder);
        }
    }
}