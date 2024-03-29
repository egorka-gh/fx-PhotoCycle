/**
 * Generated by Gas3 v3.1.0 (Granite Data Services).
 *
 * WARNING: DO NOT CHANGE THIS FILE. IT MAY BE OVERWRITTEN EACH TIME YOU USE
 * THE GENERATOR. INSTEAD, EDIT THE INHERITED CLASS (BookSynonymGlue.as).
 */

package com.photodispatcher.model.mysql.entities {

    import flash.utils.IDataInput;
    import flash.utils.IDataOutput;

    [Bindable]
    public class BookSynonymGlueBase extends AbstractEntity {

        public function BookSynonymGlueBase() {
            super();
        }

        private var _add_layers:int;
        private var _book_synonym:int;
        private var _glue_cmd:int;
        private var _glue_cmd_name:String;
        private var _id:int;
        private var _interlayer:int;
        private var _interlayer_name:String;
        private var _paper:int;
        private var _paper_name:String;

        public function set add_layers(value:int):void {
            _add_layers = value;
        }
        public function get add_layers():int {
            return _add_layers;
        }

        public function set book_synonym(value:int):void {
            _book_synonym = value;
        }
        public function get book_synonym():int {
            return _book_synonym;
        }

        public function set glue_cmd(value:int):void {
            _glue_cmd = value;
        }
        public function get glue_cmd():int {
            return _glue_cmd;
        }

        public function set glue_cmd_name(value:String):void {
            _glue_cmd_name = value;
        }
        public function get glue_cmd_name():String {
            return _glue_cmd_name;
        }

        public function set id(value:int):void {
            _id = value;
        }
        public function get id():int {
            return _id;
        }

        public function set interlayer(value:int):void {
            _interlayer = value;
        }
        public function get interlayer():int {
            return _interlayer;
        }

        public function set interlayer_name(value:String):void {
            _interlayer_name = value;
        }
        public function get interlayer_name():String {
            return _interlayer_name;
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

        public override function readExternal(input:IDataInput):void {
            super.readExternal(input);
            _add_layers = input.readObject() as int;
            _book_synonym = input.readObject() as int;
            _glue_cmd = input.readObject() as int;
            _glue_cmd_name = input.readObject() as String;
            _id = input.readObject() as int;
            _interlayer = input.readObject() as int;
            _interlayer_name = input.readObject() as String;
            _paper = input.readObject() as int;
            _paper_name = input.readObject() as String;
        }

        public override function writeExternal(output:IDataOutput):void {
            super.writeExternal(output);
            output.writeObject(_add_layers);
            output.writeObject(_book_synonym);
            output.writeObject(_glue_cmd);
            output.writeObject(_glue_cmd_name);
            output.writeObject(_id);
            output.writeObject(_interlayer);
            output.writeObject(_interlayer_name);
            output.writeObject(_paper);
            output.writeObject(_paper_name);
        }
    }
}