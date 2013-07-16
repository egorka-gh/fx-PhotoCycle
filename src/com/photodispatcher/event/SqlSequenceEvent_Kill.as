package com.photodispatcher.event{
	import flash.data.SQLStatement;
	import flash.events.Event;
	
	public class SqlSequenceEvent_Kill extends Event{
		public static const SQL_SEQUENCE_EVENT:String='sqlSequenceEvent';
		
		public static const RESULT_COMLETED:int=0;
		public static const RESULT_FAULT:int=1;

		public var result:int;
		public var error:String;
		public var statement:SQLStatement;

		public function SqlSequenceEvent_Kill(result:int, statement:SQLStatement=null, error:String=''){
			super(SQL_SEQUENCE_EVENT, false, false);
			this.result=result;
			this.statement=statement;
			this.error=error;
		}
	}
}