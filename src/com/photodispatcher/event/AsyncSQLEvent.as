package com.photodispatcher.event{
	import flash.events.Event;
	
	public class AsyncSQLEvent extends Event{
		public static const ASYNC_SQL_EVENT:String='asyncSQLEvent';

		public static const RESULT_COMLETED:int=0;
		public static const RESULT_FAULT:int=1;
		public static const RESULT_FAULT_LOCKED:int=2;
		
		public var result:int;
		public var item:Object;
		public var lastID:int;
		public var affected:int;
		public var error:String;
		
		public function AsyncSQLEvent(result:int,lastID:int=0,affected:int=0,item:Object=null,error:String=''){
			super(ASYNC_SQL_EVENT, false, true);
			this.result=result;
			this.lastID=lastID;
			this.affected=affected;
			this.item=item;
			this.error=error;
		}
	}
}