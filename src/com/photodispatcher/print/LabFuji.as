package com.photodispatcher.print{
	import com.photodispatcher.model.mysql.entities.Lab;
	import com.photodispatcher.model.mysql.entities.LabPrintCode;
	import com.photodispatcher.model.PrintGroup;
	
	public class LabFuji extends LabGeneric{
		
		public function LabFuji(lab:Lab){
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
			if(!printGroup || printGroup.is_pdf) return '';
			return super.printChannelCode(printGroup);
		}
	}
}