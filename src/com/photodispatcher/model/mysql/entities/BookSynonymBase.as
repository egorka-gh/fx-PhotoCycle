/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (BookSynonym.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;
    import mx.collections.ListCollectionView;
    import org.granite.tide.IPropertyHolder;

    [Bindable]
    public class BookSynonymBase extends AbstractEntity {

        public function BookSynonymBase() {
            super();
        }

        private var _book_type:int;
        private var _book_type_name:String;
        private var _id:int;
        private var _is_allow:Boolean;
        private var _is_horizontal:Boolean;
        private var _lab_type:int;
        private var _lab_type_name:String;
        private var _src_type:int;
        private var _src_type_name:String;
        private var _synonym:String;
        private var _synonym_type:int;
        private var _synonym_type_name:String;
        private var _templates:ListCollectionView;

        public function set book_type(value:int):void {
            _book_type = value;
        }
        public function get book_type():int {
            return _book_type;
        }

        public function set book_type_name(value:String):void {
            _book_type_name = value;
        }
        public function get book_type_name():String {
            return _book_type_name;
        }

        public function set id(value:int):void {
            _id = value;
        }
        public function get id():int {
            return _id;
        }

        public function set is_allow(value:Boolean):void {
            _is_allow = value;
        }
        public function get is_allow():Boolean {
            return _is_allow;
        }

        public function set is_horizontal(value:Boolean):void {
            _is_horizontal = value;
        }
        public function get is_horizontal():Boolean {
            return _is_horizontal;
        }

        public function set lab_type(value:int):void {
            _lab_type = value;
        }
        public function get lab_type():int {
            return _lab_type;
        }

        public function set lab_type_name(value:String):void {
            _lab_type_name = value;
        }
        public function get lab_type_name():String {
            return _lab_type_name;
        }

        public function set src_type(value:int):void {
            _src_type = value;
        }
        public function get src_type():int {
            return _src_type;
        }

        public function set src_type_name(value:String):void {
            _src_type_name = value;
        }
        public function get src_type_name():String {
            return _src_type_name;
        }

        public function set synonym(value:String):void {
            _synonym = value;
        }
        public function get synonym():String {
            return _synonym;
        }

        public function set synonym_type(value:int):void {
            _synonym_type = value;
        }
        public function get synonym_type():int {
            return _synonym_type;
        }

        public function set synonym_type_name(value:String):void {
            _synonym_type_name = value;
        }
        public function get synonym_type_name():String {
            return _synonym_type_name;
        }

        public function set templates(value:ListCollectionView):void {
            _templates = value;
        }
        public function get templates():ListCollectionView {
            return _templates;
        }

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _book_type = input.readObject() as int;
            _book_type_name = input.readObject() as String;
            _id = input.readObject() as int;
            _is_allow = input.readObject() as Boolean;
            _is_horizontal = input.readObject() as Boolean;
            _lab_type = input.readObject() as int;
            _lab_type_name = input.readObject() as String;
            _src_type = input.readObject() as int;
            _src_type_name = input.readObject() as String;
            _synonym = input.readObject() as String;
            _synonym_type = input.readObject() as int;
            _synonym_type_name = input.readObject() as String;
            _templates = input.readObject() as ListCollectionView;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject((_book_type is IPropertyHolder) ? IPropertyHolder(_book_type).object : _book_type);
            output.writeObject((_book_type_name is IPropertyHolder) ? IPropertyHolder(_book_type_name).object : _book_type_name);
            output.writeObject((_id is IPropertyHolder) ? IPropertyHolder(_id).object : _id);
            output.writeObject((_is_allow is IPropertyHolder) ? IPropertyHolder(_is_allow).object : _is_allow);
            output.writeObject((_is_horizontal is IPropertyHolder) ? IPropertyHolder(_is_horizontal).object : _is_horizontal);
            output.writeObject((_lab_type is IPropertyHolder) ? IPropertyHolder(_lab_type).object : _lab_type);
            output.writeObject((_lab_type_name is IPropertyHolder) ? IPropertyHolder(_lab_type_name).object : _lab_type_name);
            output.writeObject((_src_type is IPropertyHolder) ? IPropertyHolder(_src_type).object : _src_type);
            output.writeObject((_src_type_name is IPropertyHolder) ? IPropertyHolder(_src_type_name).object : _src_type_name);
            output.writeObject((_synonym is IPropertyHolder) ? IPropertyHolder(_synonym).object : _synonym);
            output.writeObject((_synonym_type is IPropertyHolder) ? IPropertyHolder(_synonym_type).object : _synonym_type);
            output.writeObject((_synonym_type_name is IPropertyHolder) ? IPropertyHolder(_synonym_type_name).object : _synonym_type_name);
            output.writeObject((_templates is IPropertyHolder) ? IPropertyHolder(_templates).object : _templates);
        }
    }
}