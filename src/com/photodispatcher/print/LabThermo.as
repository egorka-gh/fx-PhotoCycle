package com.photodispatcher.print{
	import com.photodispatcher.model.mysql.entities.Lab;
	import com.photodispatcher.model.mysql.entities.LabPrintCode;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.SourceType;
	
	public class LabThermo extends LabGeneric{
		
		
		public function LabThermo(lab:Lab){
			super(lab);
		}
		
		override public function orderFolderName(printGroup:PrintGroup):String{
			if(!printGroup || !printGroup.id) return '';
			var result:String=printGroup.humanId;
			return result;
		}

		override public function printChannelCode(printGroup:PrintGroup):String{
			return printChannel(printGroup)?hot:'';
		}
		
		override public function printChannel(printGroup:PrintGroup, rolls:Array = null):LabPrintCode {
			if(!printGroup || printGroup.is_pdf || printGroup.is_duplex) return null;

			//check paper only 
			if(printGroup.paper!=LabGeneric.PAPER_THERMO) return null;
			
			return channelFromPG(printGroup);
		}
		
		private function channelFromPG(printGroup:PrintGroup):LabPrintCode{
			if(!printGroup) return null;
			var result:LabPrintCode=new LabPrintCode();
			result.src_type=SourceType.LAB_THERMO;
			result.width=printGroup.width;
			result.roll=printGroup.width;
			result.height=printGroup.height;
			result.paper=printGroup.paper;
			result.frame=printGroup.frame;
			result.correction=printGroup.correction;
			result.cutting=printGroup.cutting;
			result.is_duplex=printGroup.is_duplex;
			result.is_pdf=printGroup.is_pdf;
			return result; 
		}

	}
}