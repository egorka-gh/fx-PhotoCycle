package com.photodispatcher.print{
	import com.photodispatcher.model.mysql.entities.Lab;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	
	import flash.filesystem.File;
	
	public class LabXerox extends LabGeneric{

		public function LabXerox(lab:Lab){
			super(lab);
		}
		
		override public function orderFolderName(printGroup:PrintGroup):String{
			if(!printGroup || !printGroup.id) return '';
			return printChannelCode(printGroup);
		}
		
		override public function printChannelCode(printGroup:PrintGroup):String{
			if(!printGroup || !printGroup.is_pdf) return '';
			return super.printChannelCode(printGroup);
		}
		
		override protected function canPrintInternal(printGroup:PrintGroup):Boolean{
			//check if chenel subfolder exists
			var groupFolderName:String=orderFolderName(printGroup);
			if(!groupFolderName) return false;	
			var dstFolder:File= new File(hot);
			dstFolder=dstFolder.resolvePath(groupFolderName);
			if(!dstFolder.exists  || !dstFolder.isDirectory) return false;
			return true;
		}
		
		
	}
}