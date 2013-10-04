package com.photodispatcher.print{
	import com.photodispatcher.model.Lab;
	import com.photodispatcher.model.PrintGroup;
	
	public class LabXerox extends LabBase{

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

	}
}