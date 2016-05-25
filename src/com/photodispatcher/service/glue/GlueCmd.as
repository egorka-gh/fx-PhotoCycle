package com.photodispatcher.service.glue{
	public class GlueCmd{
		
		public var command:String;
		public var hasResponce:Boolean;
		
		public function GlueCmd(command:String, hasResponce:Boolean=false){
			this.command=command;
			this.hasResponce=hasResponce;
		}
	}
}