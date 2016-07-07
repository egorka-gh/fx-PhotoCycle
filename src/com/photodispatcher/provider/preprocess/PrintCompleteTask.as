package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrintGroupFile;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.services.PrintGroupService;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.filesystem.File;
	
	import mx.collections.ArrayCollection;
	
	import org.granite.tide.Tide;
	
	[Event(name="complete", type="flash.events.Event")]
	public class PrintCompleteTask extends EventDispatcher{
		
		private var printGroup:PrintGroup;
		private var source:Source;
		
		public var hasError:Boolean;
		public var err_msg:String;
		
		public function PrintCompleteTask(printGroup:PrintGroup){
			super(null);
			this.printGroup=printGroup;
		}
		
		public function run():void{
			if(!printGroup){
				hasError=true;
				err_msg='Не задана группа печати';
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			if(printGroup.state!=OrderState.PRN_INPRINT){
				hasError=true;
				err_msg='Не верный статус группы печати';
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			var svc:PrintGroupService=Tide.getInstance().getContext().byType(PrintGroupService,true) as PrintGroupService;
			var latch:DbLatch= new DbLatch(true);
			latch.addEventListener(Event.COMPLETE,onPrepare);
			latch.addLatch(svc.printComplitePrepare(printGroup.id));
			latch.start();
		}
		
		private function onPrepare(e:Event):void{
			var latch:DbLatch=e.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onPrepare);
				if(!latch.complite){
					hasError=true;
					err_msg=latch.error;
					dispatchEvent(new Event(Event.COMPLETE));
					return;
				}
				printGroup=latch.lastDataItem as PrintGroup;
				if(!printGroup){
					dispatchEvent(new Event(Event.COMPLETE));
					return;
				}

				if(!printGroup.is_pdf){
					//photo print, files has printed mark, update state
					printGroup.files=null; //avoid files update, just set state
					complite();
					return;
				}
				
				if(printGroup.is_reprint){
					/*
					hasError=true;
					err_msg='Пдф перепечатка';
					dispatchEvent(new Event(Event.COMPLETE));
					*/
					//print all (can't resolve pdf pages)
					printGroup.files=null; //avoid files update, just set state
					complite();
					return;
				}
				
				if(printGroup.min_sheet==0 || printGroup.max_sheet==0){
					hasError=true;
					err_msg='Нет данных печати';
					dispatchEvent(new Event(Event.COMPLETE));
					return;
				}
				if(printGroup.sheets_per_file==0){
					hasError=true;
					err_msg='Не определено количество листов в пдф';
					dispatchEvent(new Event(Event.COMPLETE));
					return;
				}
				//get original files
				if(!printGroup.files || printGroup.files.length==0){
					hasError=true;
					err_msg='Ошибка структуры группы печати';
					dispatchEvent(new Event(Event.COMPLETE));
					return;
				}
				var files:Array=[];
				var pgf:PrintGroupFile;
				for each(pgf in printGroup.files){
					if(!pgf.print_forvard) files.push(pgf);
				}
				if(files.length==0){
					hasError=true;
					err_msg='Ошибка структуры группы печати';
					dispatchEvent(new Event(Event.COMPLETE));
					return;
				}
				
				//TODO blockcover bug
				var page:int;
				if(printGroup.is_revers){
					page=printGroup.min_sheet;
				}else{
					page=printGroup.max_sheet;
				}
				//calc page 
				page=(Math.floor(page/100)-1)*printGroup.sheet_num + page % 100;
				if(printGroup.is_revers) page=printGroup.prints-page+1;
				
				var fileIdx:int=Math.floor(page/printGroup.sheets_per_file);
				if(fileIdx>files.length){
					hasError=true;
					err_msg='Ошибка структуры группы печати';
					dispatchEvent(new Event(Event.COMPLETE));
					return;
				}
				//chek if is last page
				if(page==printGroup.prints){
					fileIdx=files.length;
					page=0;
				}else{
					//get page in file
					page=page % printGroup.sheets_per_file;
				}
				//mark printed
				var i:int;
				for (i= 0; i < fileIdx; i++){
					pgf=files[i] as PrintGroupFile;
					if(pgf) pgf.printed=true;
				}
				if(page==0){
					//very last in file, not necessary to split pdf
					printGroup.files=new ArrayCollection(files);
					complite();
					return;
				}
				
				//split pdf
				if((fileIdx+1)>files.length){
					hasError=true;
					err_msg='Ошибка структуры группы печати';
					dispatchEvent(new Event(Event.COMPLETE));
					return;
				}
				pgf=files[fileIdx] as PrintGroupFile;
				//build file path
				var filePath:String;
				if(pgf) filePath=pgf.file_name;
				if(!filePath){
					hasError=true;
					err_msg='Не определено имя файла';
					dispatchEvent(new Event(Event.COMPLETE));
					return;
				}
				
				source=Context.getSource(printGroup.source_id);
				if(!source){
					hasError=true;
					err_msg='Internal error. Null source.';
					dispatchEvent(new Event(Event.COMPLETE));
					return;
				}
				printGroup.files=new ArrayCollection(files);
				filePath=source.getPrtFolder()+File.separator+printGroup.order_folder+File.separator+printGroup.path+File.separator+filePath;
				var pdfTask:PdfTask= new PdfTask(filePath);
				pdfTask.addEventListener(Event.COMPLETE, onPdfTask);
				pdfTask.catFrom(page+1);
			}
		}
		private function onPdfTask(e:Event):void{
			var pdfTask:PdfTask=e.target as PdfTask;
			if(pdfTask){
				pdfTask.removeEventListener(Event.COMPLETE, onPdfTask);
				if(pdfTask.hasError){
					hasError=true;
					err_msg=pdfTask.err_msg;
					dispatchEvent(new Event(Event.COMPLETE));
					return;
				}
				var pgf:PrintGroupFile= new PrintGroupFile();
				var relativePath:String=pdfTask.resultFileName;
				var pgPath:String=source.getPrtFolder()+File.separator+printGroup.order_folder+File.separator+printGroup.path+File.separator;
				relativePath=relativePath.substring(pgPath.length);
				
				pgf.file_name=relativePath;
				pgf.print_group=printGroup.id;
				pgf.prt_qty=1;
				pgf.print_forvard=true;
				printGroup.files.addItem(pgf);
				complite();
			}
		}

		private function complite():void{
			if(!printGroup) return;
			var svc:PrintGroupService=Tide.getInstance().getContext().byType(PrintGroupService,true) as PrintGroupService;
			var latch:DbLatch= new DbLatch(true);
			latch.addEventListener(Event.COMPLETE,onComplite);
			latch.addLatch(svc.printComplite(printGroup));
			latch.start();
		}
		private function onComplite(e:Event):void{
			var latch:DbLatch=e.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onComplite);
				if(!latch.complite){
					hasError=true;
					err_msg=latch.error;
				}
			}
			dispatchEvent(new Event(Event.COMPLETE));
		}

	}
}