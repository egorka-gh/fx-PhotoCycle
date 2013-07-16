package com.photodispatcher.print{
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.Source;
	
	public class LabXerox extends LabBase{

		public function LabXerox(s:Source){
			super(s);
		}
		
		override public function orderFolderName(printGroup:PrintGroup):String{
			if(!printGroup || !printGroup.id) return '';
			return printChannel(printGroup);
		}
		
		override public function printChannel(printGroup:PrintGroup):String{
			if(!printGroup || !printGroup.is_pdf) return '';
			return super.printChannel(printGroup);
		}

	}
}