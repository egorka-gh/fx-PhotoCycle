package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.model.PrintGroupFile;
	
	import flash.filesystem.File;

	public class PostProcessItem{
		public var printGroupFile:PrintGroupFile;
		public var file:File;
		public var copyToPath:String;
		
		public function PostProcessItem(printGroupFile:PrintGroupFile, file:File, copyToPath:String){
			this.printGroupFile=printGroupFile;
			this.file=file;
			this.copyToPath=copyToPath;
		}
	}
}