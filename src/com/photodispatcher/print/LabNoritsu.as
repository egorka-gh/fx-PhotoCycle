package com.photodispatcher.print{
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.Source;

	public class LabNoritsu extends LabBase	{
		//
		//private var chanels:Array;

		public function LabNoritsu(s:Source){
			super(s);
		}

		override public function orderFolderName(printGroup:PrintGroup):String{
			if(!printGroup || !printGroup.id) return '';
			var arr:Array= printGroup.id.split('_');
			var result:String='';
			if(arr && arr.length==3) result=arr[2]+arr[1];
			return result;
		}

		override public function printChannel(printGroup:PrintGroup):String{
			if(!printGroup || printGroup.is_pdf) return '';
			return super.printChannel(printGroup);
		}

	}
}