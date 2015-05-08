package com.photodispatcher.service{
	import flash.filesystem.File;

	public class CleanFileHolder{
		
		public var file:File;
		public var orderId:String;
		
		public function CleanFileHolder(file:File, orderId:String=null){
			this.file=file;
			this.orderId=orderId;
		}
	}
}