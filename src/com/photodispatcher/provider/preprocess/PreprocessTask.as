package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.IMRunerEvent;
	import com.photodispatcher.event.OrderBuildProgressEvent;
	import com.photodispatcher.event.OrderPreprocessEvent;
	import com.photodispatcher.model.Order;
	import com.photodispatcher.model.OrderState;
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.PrintGroupFile;
	import com.photodispatcher.model.dao.DictionaryDAO;
	import com.photodispatcher.model.dao.LabResizeDAO;
	import com.photodispatcher.model.dao.StateLogDAO;
	import com.photodispatcher.provider.fbook.makeup.FBookMakeupManager;
	import com.photodispatcher.shell.IMCommand;
	import com.photodispatcher.shell.IMRuner;
	import com.photodispatcher.util.StrUtil;
	
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

		public function PreprocessTask(order:Order, orderFolder:String, prtFolder:String, logStates:Boolean=true){
			super(null);
			this.order=order;
			this.orderFolder=orderFolder;
			this.prtFolder=prtFolder;
			this.logStates=logStates;
		}
		
		public function run():void{
			var pg:PrintGroup;
			if (!order || !orderFolder || !prtFolder){
				dispatchErr(OrderState.ERR_PREPROCESS,'Не верные параметры запуска заказ № '+order?order.id:'');
				return;
			}
			order.state=OrderState.PREPROCESS_RESIZE;
			maxThreads=Context.getAttribute('imThreads');
			if((!order.printGroups || order.printGroups.length==0) && (!order.suborders || order.suborders.length==0)){
				//nothig to process
				dispatchEvent(new OrderPreprocessEvent(order));
				return;
			}
			trace('PreprocessTask. start order: '+order.id);
			//check create print subfolder
			for each(pg in order.printGroups){
				if (pg && !checkCreateSubfolder(pg,PrintGroup.SUBFOLDER_PRINT,true)){
					return;
				}
			}
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
			if(resizeTask.hasErr){
				dispatchErr(order.state,resizeTask.error);
				return;
			}
			startPdfmakeup();
		}
		
		private var pdfItems:Array=[];
		private var commands:Array;
		private var sequenceNum:int;
		
		private function startPdfmakeup():void{
			//TODO refactor 2 IMSequenceRuner
			var pg:PrintGroup;
			var mg:BookMakeupGroup;
			hasErr=false;
			//var path:String=orderFolder+File.separator+order.ftp_folder;
			for each(pg in order.printGroups){
				mg=null;
				if(pg && pg.book_type!=0){
					if(order.state!=OrderState.PREPROCESS_PDF) order.state=OrderState.PREPROCESS_PDF;
					if(pg.is_pdf){
						if(!pg.bookTemplate.is_sheet_ready){
							mg=new PDFmakeupGroup(pg,order.id, orderFolder+File.separator+order.ftp_folder, prtFolder+File.separator+order.ftp_folder);
						}else{
							mg=new PDFsimpleMakeupGroup(pg,order.id, orderFolder+File.separator+order.ftp_folder, prtFolder+File.separator+order.ftp_folder);
						}
					}else{
						mg=new BookMakeupGroup(pg,order.id, orderFolder+File.separator+order.ftp_folder, prtFolder+File.separator+order.ftp_folder);
					}
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
			if(pdfItems.length==0){
				postProcess();
				return;
			}
			trace('PreprocessTask. Start book makeup threads order: '+order.id);
			//create prepare command list
			sequenceNum=0;
			var sequence:Array=[];
			for each (mg in pdfItems){
				if(mg){
					sequence=sequence.concat(mg.commands);
				}
			}
			runCommands(sequence);
		}
		
		private function runCommands(sequence:Array):void{
			if (maxThreads<=0){
				dispatchErr(OrderState.ERR_PREPROCESS,'IM не настроен или количество потоков 0.');
				return;
			}
			commands=sequence;
			//start theads
			for (var i:int=0; i<Math.min(maxThreads,commands.length); i++){
				runNextCmd();
			}
		}
		
		private function runNextCmd():void{
			var cmd:IMCommand;
			var command:IMCommand;
			var minState:int= IMCommand.STATE_COMPLITE;
			var complited:int=0;
			if(hasErr) return;
			//look not statrted
			for each (cmd in commands){
				if(cmd){
					minState=Math.min(minState,cmd.state);
					if(cmd.state==IMCommand.STATE_WAITE){
						if(!command) command=cmd;
						//break;
					}
					if(cmd.state==IMCommand.STATE_COMPLITE) complited++;
				}
			}
			reportProgress((sequenceNum==0?'Подготовка книги':'Сборка PDF'),complited,commands.length);
			//check comleted
			if(!command && minState>=IMCommand.STATE_COMPLITE){
				//complite
				if(sequenceNum==0){
					//prepare sequence complete
					trace('PreprocessTask. Book makeup prepare step complited, order '+order.id);
					sequenceNum++;
					//run final sequence
					var sequence:Array=[];
					var mg:BookMakeupGroup;
					for each (mg in pdfItems){
						if(mg){
							sequence=sequence.concat(mg.finalCommands);
						}
					}
					if(sequence.length==0){
						trace('PreprocessTask. Book makeup complited, order '+order.id);
						postProcess();
					}else{
						runCommands(sequence);
					}
					return;
				}
				trace('PreprocessTask. Book makeup complited, order '+order.id);
				postProcess();
				return;
			}
			runCmd(command);
		}
		private function runCmd(command:IMCommand):void{
			if(!command) return;
			var im:IMRuner=new IMRuner(Context.getAttribute('imPath'),command.folder);
			im.addEventListener(IMRunerEvent.IM_COMPLETED, onCmdComplite);
			im.start(command);
		}
		private function onCmdComplite(e:IMRunerEvent):void{
			var im:IMRuner=e.target as IMRuner;
			im.removeEventListener(IMRunerEvent.IM_COMPLETED, onCmdComplite);
			trace('PreprocessTask. Command complite: '+im.currentCommand);
			if(e.hasError){
				trace('PreprocessTask. Book makeup error, order '+order.id+', error: '+e.error);
				IMRuner.stopAll();
				dispatchErr(OrderState.ERR_PREPROCESS,e.error);
				return;
			}
			runNextCmd();
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
			if(logStates) StateLogDAO.logState(errState,order.id,'',errMsg); 
			dispatchEvent(new OrderPreprocessEvent(order,errState,errMsg));
			reportProgress();
		}

		private function postProcess():void{
			//StateLogDAO.logState(order.state,order.id,'','Копирование в print (postProcess)'); 

			var postProcessTask:PostProcessTask=new PostProcessTask(order,orderFolder, prtFolder);
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
					dispatchErr(OrderState.ERR_FILE_SYSTEM,'Ошибка PreprocessTask.postProcess: '+postProcessTask.errMsg);
					return;
				}
			}
			trace('PreprocessTask. postProcess complited, order '+order.id);
			//dispatchEvent(new OrderPreprocessEvent(order));
			startFBookMakeup();
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
			reportProgress();
			if(fbookBuilder.hasErr){
				dispatchEvent(new OrderPreprocessEvent(order,fbookBuilder.errNum,fbookBuilder.error));
			}else{
				dispatchEvent(new OrderPreprocessEvent(order))
			}
		}
		

	}
}