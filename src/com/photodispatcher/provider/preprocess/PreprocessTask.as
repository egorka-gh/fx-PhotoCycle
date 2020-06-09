package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.IMRunerEvent;
	import com.photodispatcher.event.OrderBuildProgressEvent;
	import com.photodispatcher.event.OrderPreprocessEvent;
	import com.photodispatcher.model.mysql.entities.BookSynonymCompo;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrintGroupFile;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.provider.fbook.makeup.FBookMakeupManager;
	import com.photodispatcher.shell.IMCommand;
	import com.photodispatcher.shell.IMMultiSequenceRuner;
	import com.photodispatcher.shell.IMRuner;
	
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.events.AsyncErrorEvent;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.filesystem.File;
	import flash.net.URLRequest;
	
	[Event(name="orderResized", type="com.photodispatcher.event.OrderPreprocessEvent")]
	[Event(name="progress", type="com.photodispatcher.event.OrderBuildProgressEvent")]
	public class PreprocessTask extends EventDispatcher{

		public static const OUT_FILE_DEPTH:String='8';
		public static const OUT_FILE_DENSITY:String='300';
		public static const OUT_FILE_QUALITY:String='100%';

		private var order:Order;
		private var orderFolder:String;
		private var prtFolder:String;
		private var maxThreads:int=0;

		//private var currPGIdx:int=0;
		//private var currFileIdx:int=-1;
		private var hasErr:Boolean=false;
		private var logStates:Boolean;
		private var reprintMode:Boolean=false;
		
		private var forceStop:Boolean;


		public function PreprocessTask(order:Order, orderFolder:String, prtFolder:String, logStates:Boolean=true, reprintMode:Boolean=false){
			super(null);
			this.order=order;
			this.orderFolder=orderFolder;
			this.prtFolder=prtFolder;
			this.logStates=logStates;
			this.reprintMode=reprintMode;
		}

		public function stop():void{
			forceStop=true;
			if(sequencesRuner){
				sequencesRuner.removeEventListener(ProgressEvent.PROGRESS, onCommandsProgress);
				sequencesRuner.removeEventListener(IMRunerEvent.IM_COMPLETED, onSequencesComplite);
				sequencesRuner.stop();
				sequencesRuner=null;
			}
			if(fbookBuilder){
				fbookBuilder.removeEventListener(Event.COMPLETE,onFbComplite);
				fbookBuilder.removeEventListener(ProgressEvent.PROGRESS,onResizeProgress);
				fbookBuilder.stop();
				fbookBuilder=null;
			}
			if(compoBuilder){
				compoBuilder.removeEventListener(Event.COMPLETE,onCompoComplite);
				compoBuilder.removeEventListener(ProgressEvent.PROGRESS,onResizeProgress);
				compoBuilder.stop();
				compoBuilder=null;
			}
			IMRuner.stopAll();
		}
		
		public function run():void{
			var pg:PrintGroup;
			if (!order || !orderFolder || !prtFolder){
				dispatchErr(OrderState.ERR_PREPROCESS,'Не верные параметры запуска заказ № '+order?order.id:'');
				return;
			}
			order.state=OrderState.PREPROCESS_RESIZE;
			maxThreads=reprintMode?1:Context.getAttribute('imThreads');
			if((!order.printGroups || order.printGroups.length==0) && (!order.suborders || order.suborders.length==0)){
				//nothig to process
				dispatchEvent(new OrderPreprocessEvent(order));
				return;
			}
			trace('PreprocessTask. start order: '+order.id);
			if(reprintMode){
				//check create print subfolder
				for each(pg in order.printGroups){
					if (pg && pg.is_pdf && pg.state<OrderState.CANCELED_SYNC && !checkCreateSubfolder(pg,PrintGroup.SUBFOLDER_PRINT,false)){
						return;
					}
				}
				//process pdfs only
				startPdfmakeup();
				return;
			}

			//check create print subfolder
			for each(pg in order.printGroups){
				if (pg && pg.state<OrderState.CANCELED_SYNC && !checkCreateSubfolder(pg,PrintGroup.SUBFOLDER_PRINT,true)){
					return;
				}
			}

			var src:Source = Context.getSource(order.source);
			if(src && src.type == SourceType.SRC_INTERNAL) {
				// build compo
				order.state=OrderState.PREPROCESS_COMPO;
				startCompoMakeup();
				return ;
			}

			//full process sequence
			var resizeTask:ResizeTask= new ResizeTask(order,orderFolder, prtFolder,logStates);
			resizeTask.addEventListener(Event.COMPLETE, onResizeComplite);
			resizeTask.addEventListener(ProgressEvent.PROGRESS, onResizeProgress);
			resizeTask.run();
		}
		
		private function reportProgress(caption:String='',ready:Number=0, total:Number=0):void{
			dispatchEvent(new OrderBuildProgressEvent((caption?(order.id+' '+caption):''),ready,total));
		}
		
		private function onResizeProgress(e:OrderBuildProgressEvent):void{
			dispatchEvent(e.clone());
		}
		
		private function onResizeComplite(e:Event):void{
			var resizeTask:ResizeTask=e.target as ResizeTask;
			resizeTask.removeEventListener(Event.COMPLETE, onResizeComplite);
			resizeTask.removeEventListener(ProgressEvent.PROGRESS, onResizeProgress);
			if(forceStop) return;
			if(resizeTask.hasErr){
				dispatchErr(order.state,resizeTask.error);
				return;
			}
			startFBookMakeup();
			//startPdfmakeup();
		}
		
		//private var pdfItems:Array=[];
		//private var commands:Array;
		//private var sequenceNum:int;
		
		private var sequencesRuner:IMMultiSequenceRuner;
		
		private function startPdfmakeup():void{
			if(forceStop) return;
			var pg:PrintGroup;
			var mg:BookMakeupGroup;
			var pdfItems:Array=[];
			hasErr=false;
			for each(pg in order.printGroups){
				mg=null;
				if(pg && pg.book_type!=0 && pg.state<OrderState.CANCELED_SYNC){
					if(order.state!=OrderState.PREPROCESS_PDF) order.state=OrderState.PREPROCESS_PDF;
					if(pg.is_pdf && pg.compo_type != BookSynonymCompo.COMPO_TYPE_CHILD){
						if(!pg.bookTemplate.is_sheet_ready){
							mg=new PDFmakeupGroup(pg,order.id, orderFolder+File.separator+order.ftp_folder, prtFolder+File.separator+order.ftp_folder);
						}else{
							mg=new PDFsimpleMakeupGroup(pg,order.id, orderFolder+File.separator+order.ftp_folder, prtFolder+File.separator+order.ftp_folder);
						}
						//mg.reprintMode=reprintMode;
					}else{
						mg=new BookMakeupGroup(pg,order.id, orderFolder+File.separator+order.ftp_folder, prtFolder+File.separator+order.ftp_folder);
					}
					if(mg){
						if(reprintMode) mg.buildMode=BookMakeupGroup.MODE_REPRINT;
						try{
							mg.createCommands();
						}catch(err:Error) {
							dispatchErr(OrderState.ERR_PREPROCESS,err.message);
							return;
						}
						if(mg.state==BookMakeupGroup.STATE_ERR){
							//complite vs error
							dispatchErr(mg.err,mg.err_msg);
							return;
						}
						if(mg.hasCommands){
							//check/create print sub dir
							if (!checkCreateSubfolder(pg,PrintGroup.SUBFOLDER_PRINT)) return;
							pdfItems.push(mg);
						}
					}
				}
			}
			if(pdfItems.length==0){
				postProcess();
				return;
			}
			trace('PreprocessTask. Start book makeup threads order: '+order.id);

			if (maxThreads<=0){
				dispatchErr(OrderState.ERR_PREPROCESS,'IM не настроен или количество потоков 0.');
				return;
			}

			var sequences:Array=[];
			for each (mg in pdfItems){
				if(mg){
					sequences=sequences.concat(mg.sequences);
				}
			}
			
			sequencesRuner= new IMMultiSequenceRuner();
			sequencesRuner.addEventListener(ProgressEvent.PROGRESS, onCommandsProgress);
			sequencesRuner.addEventListener(IMRunerEvent.IM_COMPLETED, onSequencesComplite);
			sequencesRuner.start(sequences,maxThreads,false);

			/*
			//create prepare command list
			sequenceNum=0;
			var sequence:Array=[];
			for each (mg in pdfItems){
				if(mg){
					sequence=sequence.concat(mg.commands);
				}
			}
			runCommands(sequence);
			*/
		}
		
		private function onCommandsProgress(evt:ProgressEvent):void{
			if(forceStop) return;
			reportProgress('Подготовка книг',evt.bytesLoaded,evt.bytesTotal);
		}

		private function onSequencesComplite(evt:IMRunerEvent):void{
			if(sequencesRuner){
				sequencesRuner.removeEventListener(ProgressEvent.PROGRESS, onCommandsProgress);
				sequencesRuner.removeEventListener(IMRunerEvent.IM_COMPLETED, onSequencesComplite);
				sequencesRuner=null;
			}
			if(forceStop) return;
			if(evt.hasError){
				trace('PreprocessTask. Book makeup error, order '+order.id+', error: '+evt.error);
				dispatchErr(OrderState.ERR_PREPROCESS,evt.error);
				return;

			}else{
				trace('PreprocessTask. Book makeup complited, order '+order.id);
				postProcess();
				return;
			}
		}

		private function checkCreateSubfolder(printGroup:PrintGroup, subDir:String, clean:Boolean=false):Boolean{
			//check/create print sub dir
			//var printFolderPath:String=orderFolder+File.separator+order.ftp_folder+File.separator+printGroup.path+File.separator+subDir;
			var printFolderPath:String=prtFolder+File.separator+order.ftp_folder+File.separator+printGroup.path+File.separator+subDir;
			var printFolder:File;
			try{
				printFolder= new File(printFolderPath);
			}catch(err:Error) {
				trace('ResizeTask. Ошибка создания папки: '+err.message+'; '+printFolderPath);
				dispatchErr(OrderState.ERR_FILE_SYSTEM,'Ошибка создания папки: '+err.message+'; '+printFolderPath);
				return false;
			}
			if(clean){
				if(printFolder.exists){
					try{
						if(printFolder.isDirectory){
							printFolder.deleteDirectory(true);
						}else{
							printFolder.deleteFile();
						}
					}catch(err:Error) {
						trace('ResizeTask. Ошибка очистки папки: '+err.message+'; '+printFolderPath);
						dispatchErr(OrderState.ERR_FILE_SYSTEM,'Ошибка очистки папки: '+err.message+'; '+printFolderPath);
						return false;
					}
				}
			}
			if(!printFolder.exists){
				try{
					printFolder.createDirectory();
				}catch(err:Error) {
					trace('ResizeTask. Ошибка создания папки: '+err.message+'; '+printFolderPath);
					dispatchErr(OrderState.ERR_FILE_SYSTEM,'Ошибка создания папки: '+err.message+'; '+printFolderPath);
					return false;
				}
			}
			return true;
		}
		
		private function dispatchErr(errState:int,errMsg:String):void{
			hasErr=true;
			if(order.state!=errState) order.state=errState;
			if(logStates) StateLog.log(errState,order.id,'',errMsg); 
			dispatchEvent(new OrderPreprocessEvent(order,errState,errMsg));
			reportProgress();
		}

		private function postProcess():void{
			if(forceStop) return;

			var postProcessTask:PostProcessTask=new PostProcessTask(order,orderFolder, prtFolder, reprintMode);
			postProcessTask.addEventListener(Event.COMPLETE,onPostProcess);
			postProcessTask.addEventListener(ProgressEvent.PROGRESS, onResizeProgress);
			postProcessTask.run();
		}
		private function onPostProcess(e:Event):void{
			var postProcessTask:PostProcessTask=e.target as PostProcessTask;
			
			//StateLogDAO.logState(order.state,order.id,'','Копирование в print завершено'); 
			
			if(postProcessTask){
				postProcessTask.removeEventListener(Event.COMPLETE,onPostProcess);
				postProcessTask.removeEventListener(ProgressEvent.PROGRESS, onResizeProgress);
				if(postProcessTask.hasErr){
					if(!forceStop) dispatchErr(OrderState.ERR_FILE_SYSTEM,'Ошибка PreprocessTask.postProcess: '+postProcessTask.errMsg);
					return;
				}
			}
			trace('PreprocessTask. postProcess complited, order '+order.id);
			if(forceStop) return;
			
			dispatchEvent(new OrderPreprocessEvent(order));
			//startFBookMakeup();
		}
		
		private var fbookBuilder:FBookMakeupManager;
		private function startFBookMakeup():void{
			fbookBuilder= new FBookMakeupManager(order,orderFolder, prtFolder,logStates);
			fbookBuilder.addEventListener(Event.COMPLETE,onFbComplite);
			fbookBuilder.addEventListener(ProgressEvent.PROGRESS,onResizeProgress);
			fbookBuilder.run();
		}
		
		private function onFbComplite(event:Event):void{
			fbookBuilder.removeEventListener(Event.COMPLETE,onFbComplite);
			fbookBuilder.removeEventListener(ProgressEvent.PROGRESS,onResizeProgress);
			if(forceStop) return;
			reportProgress();
			if(fbookBuilder.hasErr){
				dispatchEvent(new OrderPreprocessEvent(order,fbookBuilder.errNum,fbookBuilder.error));
				return;
			}
			startPdfmakeup();
		}

		private var compoBuilder:CompoMakeupManager;
		private function startCompoMakeup():void{
			compoBuilder= new CompoMakeupManager(order,orderFolder);
			compoBuilder.addEventListener(Event.COMPLETE,onCompoComplite);
			compoBuilder.addEventListener(ProgressEvent.PROGRESS,onResizeProgress);
			compoBuilder.run();
		}
		
		private function onCompoComplite(event:Event):void{
			compoBuilder.removeEventListener(Event.COMPLETE,onCompoComplite);
			compoBuilder.removeEventListener(ProgressEvent.PROGRESS,onResizeProgress);
			if(forceStop) return;
			reportProgress();
			if(compoBuilder.hasErr){
				dispatchEvent(new OrderPreprocessEvent(order,compoBuilder.errNum,compoBuilder.error));
				return;
			}
			startPdfmakeup();
		}
		
	}
}