package com.photodispatcher.print{
	import com.photodispatcher.model.mysql.entities.Lab;
	import com.photodispatcher.model.mysql.entities.LabPrintCode;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	
	public class LabPlotter extends LabGeneric{
		public function LabPlotter(lab:Lab){
			super(lab);
		}

		override public function orderFolderName(printGroup:PrintGroup):String{
			if(!printGroup || !printGroup.id) return '';
			var arr:Array= printGroup.id.split('_');
			var result:String='';
			if(arr && arr.length==3) result=arr[1]+'-'+arr[2];
			return result;
		}
		
		override public function printChannelCode(printGroup:PrintGroup):String{
			return printChannel(printGroup)?hot:'';
		}
		
		override public function printChannel(printGroup:PrintGroup, rolls:Array = null):LabPrintCode{
			if(!printGroup || printGroup.is_pdf || printGroup.is_duplex) return null;
			//if has correction or frame
			if(printGroup.correction!=0 || printGroup.frame!=0 || printGroup.cutting!=0) return null;
			
			var cm:Object = rolls? channelMapByOnRolls(rolls) : chanelMap;
			if(!cm) return null;
			
			//lookup channel by closest size
			var result:LabPrintCode;
			var ch:LabPrintCode;
			for each (ch in cm){
				//exclude height
				if(ch && ch.paper==printGroup.paper && ch.width==printGroup.width && ch.height>=printGroup.height){
					if(!result){
						result=ch;
					}else if((result.height-printGroup.height)>(ch.height-printGroup.height)){
						result=ch;
					}
				}
			}
			return fillChannelFromPG(result,printGroup);
		}
		
		private function fillChannelFromPG(channel:LabPrintCode, printGroup:PrintGroup):LabPrintCode{
			if(!channel || !printGroup) return null;
			var result:LabPrintCode=channel.clone();
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