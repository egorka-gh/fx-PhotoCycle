package com.photodispatcher.print{
	import com.photodispatcher.event.PrintEvent;
	import com.photodispatcher.model.BookSynonym;
	import com.photodispatcher.model.Lab;
	import com.photodispatcher.model.LabPrintCode;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.SourceType;

	public class LabNoritsu extends LabBase	{
		//
		//private var chanels:Array;

		private var nhfLab:LabNoritsuNHF;
		
		public function LabNoritsu(lab:Lab){
			super(lab);
			if (lab.hot_nfs){
				nhfLab= new LabNoritsuNHF(lab);
				nhfLab.src_type=SourceType.LAB_NORITSU_NHF;
				nhfLab.hot=lab.hot_nfs;
				nhfLab.addEventListener(PrintEvent.POST_COMPLETE_EVENT,onNhfEvent);
			}
		}
		
		private function onNhfEvent(event:PrintEvent):void{
			dispatchEvent(event.clone());
		}

		override public function orderFolderName(printGroup:PrintGroup):String{
			if(!printGroup || !printGroup.id) return '';
			var arr:Array= printGroup.id.split('_');
			var result:String='';
			if(arr && arr.length==3) result=arr[2]+arr[1];
			return result;
		}

		public function orderFolderNameNHF(printGroup:PrintGroup):String{
			if(!printGroup || !printGroup.id || !nhfLab) return '';
			return nhfLab.orderFolderName(printGroup);
		}

		override public function printChannelCode(printGroup:PrintGroup):String{
			if(!printGroup || printGroup.is_pdf) return '';
			return super.printChannelCode(printGroup);
		}
		
		override public function printChannel(printGroup:PrintGroup):LabPrintCode{
			var result:LabPrintCode=super.printChannel(printGroup);
			if(!result && nhfLab) result=nhfLab.printChannel(printGroup);
			return result;
		}
		
		override protected function canPrint(printGroup:PrintGroup):Boolean{
			//check itself only (nhf not checked), use in post only
			var result:LabPrintCode=super.printChannel(printGroup);
			return result?true:false;
		}
		
		
		override public function post(pg:PrintGroup, revers:Boolean):void{
			if(!pg) return;
			
			//try to post books to nhf first
			if(pg.book_type==BookSynonym.BOOK_TYPE_BOOK || 
				pg.book_type==BookSynonym.BOOK_TYPE_JOURNAL || 
				pg.book_type==BookSynonym.BOOK_TYPE_LEATHER){
				if(nhfLab && nhfLab.printChannel(pg)){
					nhfLab.post(pg,revers);
					return;
				}
			}
			
			if (canPrint(pg)){
				var pt:PrintTask= new PrintTask(pg,this,revers);
				printTasks.push(pt);
				//start post sequence
				stateCaption='Копирование';
				postNext();
				return;
			}
			if(nhfLab){
				nhfLab.post(pg,revers);
			}else{
				pg.state=OrderState.ERR_PRINT_POST;
				dispatchErr(pg,'Группа печати '+pg.id+' не может быть распечатана в '+name+'.');
			}
		}
		
	}
}