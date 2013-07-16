package com.photodispatcher.print{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.Source;
	import com.photodispatcher.util.ArrayUtil;
	
	import mx.collections.ArrayCollection;
	
	public class LabVirtual extends LabBase{
		
		public function LabVirtual(s:Source){
			super(s);
		}

		override public function orderFolderName(printGroup:PrintGroup):String{
			if(!printGroup || !printGroup.id) return '';
			Context.initAttributeLists();
			var result:String=printGroup.humanId;
			//size
			result+='_'+printGroup.width.toString()+'x'+printGroup.height.toString();
			
			if(printGroup.paper) result+=idToLabel('paper',printGroup.paper);
			if(printGroup.correction) result+='_Коррекция';
			if(printGroup.cutting){
				result+=idToLabel('cutting',printGroup.cutting);
			}else{
				result+='_F-noresize';
			}
			if(printGroup.frame) result+='_Рамка';
			if(printGroup.book_type) result+=idToLabel('book_type',printGroup.book_type);
			if(printGroup.book_part) result+=idToLabel('book_part',printGroup.book_part);
			if(printGroup.is_pdf) result+='_PDF';
			
			return result;
		}
		
		private function idToLabel(field:String, id:int):String{
			if(id==0) return '';
			var ac:ArrayCollection=Context.getAttribute(field+'List');
			if(!ac) return '';
			var arr:Array=ac.source;
			var idx:int=ArrayUtil.searchItemIdx('value',id,arr);
			if(idx==-1) return '';
			return '_'+arr[idx].label;
		}
		
		override public function printChannel(printGroup:PrintGroup):String{
			return 'virtual';
		}
	}
}