/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (LabResize.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;
    import org.granite.tide.IPropertyHolder;

    [Bindable]
    public class LabResizeBase extends AbstractEntity {

        private var _pixels:int;
        private var _width:int;

        public function set pixels(value:int):void {
            _pixels = value;
        }
        public function get pixels():int {
            return _pixels;
        }

        public function set width(value:int):void {
            _width = value;
        }
        public function get width():int {
            return _width;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _pixels = input.readObject() as int;
            _width = input.readObject() as int;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject((_pixels is IPropertyHolder) ? IPropertyHolder(_pixels).object : _pixels);
            output.writeObject((_width is IPropertyHolder) ? IPropertyHolder(_width).object : _width);
        }
    }
}