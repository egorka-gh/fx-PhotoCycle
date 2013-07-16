package com.photodispatcher.print{
	import com.photodispatcher.model.LabPrintCode;
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.Source;
	import com.photodispatcher.model.dao.LabPrintCodeDAO;
	
	public class LabFuji extends LabBase{
		
		public function LabFuji(s:Source){
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
			if(!printGroup || printGroup.is_pdf) return '';
			return super.printChannel(printGroup);
		}
	}
}