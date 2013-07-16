package com.photodispatcher.print{
	import com.photodispatcher.model.LabPrintCode;
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.Source;
	
	public class LabPlotter extends LabBase{
		public function LabPlotter(s:Source){
			super(s);
		}

		override public function orderFolderName(printGroup:PrintGroup):String{
			if(!printGroup || !printGroup.id) return '';
			var arr:Array= printGroup.id.split('_');
			var result:String='';
			if(arr && arr.length==3) result=arr[1]+'-'+arr[2];
			return result;
		}
		
		override public function printChannel(printGroup:PrintGroup):String{
			if(!printGroup || printGroup.is_pdf || printGroup.is_duplex) return '';
			//if has correction or frame
			if(printGroup.correction!=0 || printGroup.frame!=0 || printGroup.cutting!=0) return '';
			
			var cm:Object=chanelMap;
			if(!cm) return '';
			
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
			
			return result?hotFolder.url:'';
		}

	}
}