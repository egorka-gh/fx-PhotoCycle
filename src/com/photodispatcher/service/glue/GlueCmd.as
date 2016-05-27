package com.photodispatcher.service.glue{
	import com.photodispatcher.model.mysql.AsyncLatch;

	public class GlueCmd{
		
		public var command:String;
		public var hasResponce:Boolean;
		public var latch:AsyncLatch;
		
		public function GlueCmd(command:String, hasResponce:Boolean=false, latch:AsyncLatch=null){
			this.command=command;
			this.hasResponce=hasResponce;
			this.latch=latch;
		}
	}
}