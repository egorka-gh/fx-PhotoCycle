package com.photodispatcher.event{
	import flash.events.Event;
	
	public class ConnectionsProgressEvent extends Event{
		public static const CONNECTIONS_PROGRESS_EVENT:String="connectionsProgress";

		public var active:int=0;
		public var limit:int=0;
		public var free:int=0;
		public var pending:int=0;

		public function ConnectionsProgressEvent(active:int=0, limit:int=0, free:int=0, pending:int=0){
			super(CONNECTIONS_PROGRESS_EVENT);
			this.active=active;
			this.limit=limit;
			this.free=free;
			this.pending=pending;
		}
		
		override public function clone():Event{
			return new ConnectionsProgressEvent(active, limit, free, pending);
		}

	}
}