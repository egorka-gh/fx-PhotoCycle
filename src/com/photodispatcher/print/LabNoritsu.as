package com.photodispatcher.print{
	import com.photodispatcher.event.PrintEvent;
	import com.photodispatcher.model.Lab;
	import com.photodispatcher.model.OrderState;
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.Source;
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
		
		override public function post(pg:PrintGroup):void{
			if(!pg) return;
			if (canPrint(pg)){
				var pt:PrintTask= new PrintTask(pg,this);
				printTasks.push(pt);
				//start post sequence
				stateCaption='Копирование';
				postNext();
				return;
			}
			if(nhfLab){
				nhfLab.post(pg);
			}else{
				pg.state=OrderState.ERR_PRINT_POST;
				dispatchErr(pg,'Группа печати '+pg.id+' не может быть распечатана в '+name+'.');
			}
		}
		
	}
}