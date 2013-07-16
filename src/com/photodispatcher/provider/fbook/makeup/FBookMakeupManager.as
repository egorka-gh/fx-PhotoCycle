package com.photodispatcher.provider.fbook.makeup{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.IMRunerEvent;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.event.OrderBuildProgressEvent;
	import com.photodispatcher.model.Order;
	import com.photodispatcher.model.OrderState;
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.Suborder;
	import com.photodispatcher.model.dao.StateLogDAO;
	import com.photodispatcher.provider.fbook.FBookProject;
	import com.photodispatcher.provider.fbook.data.PageData;
	import com.photodispatcher.shell.IMCommand;
	import com.photodispatcher.shell.IMRuner;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

	[Event(name="complete", type="flash.events.Event")]
	[Event(name="progress", type="com.photodispatcher.event.OrderBuildProgressEvent")]
	public class FBookMakeupManager  extends EventDispatcher{

		public function get hasErr():Boolean{
			return errNum<0;
		}
		
		public var errNum:int=0;
		public var error:String;

		private var order:Order;
		private var sourceFolder:String;
		private var prtFolder:String;
		private var maxThreads:int=0;
		private var logStates:Boolean;
		private var sourceDir:File;

		public function FBookMakeupManager(order:Order, sourceFolder:String, prtFolder:String, logStates:Boolean=true){
			super(null);
			this.order=order;
			this.sourceFolder=sourceFolder;
			this.prtFolder=prtFolder;
			this.logStates=logStates;
		}

		public function run():void{
			errNum=0;
			error='';
			if(!order || !sourceFolder || !prtFolder){
				releaseWithErr(OrderState.ERR_PREPROCESS,'Ошибка инициализации');
				return ;
			}
			if(!order.suborders || order.suborders.length==0){
				dispatchEvent(new Event(Event.COMPLETE));
				return ;
			}
			maxThreads=Context.getAttribute('imThreads');
			if (maxThreads<=0){
				releaseWithErr(OrderState.ERR_PREPROCESS,'Не настроен ImageMagick');
				return;
			}
			sourceDir=new File(sourceFolder);
			if(!sourceDir || !sourceDir.exists || !sourceDir.isDirectory){
				releaseWithErr(OrderState.ERR_FILE_SYSTEM,'Не найдена папка '+sourceFolder);
				return;
			}

			order.state=OrderState.PREPROCESS_PDF;
			if(logStates) StateLogDAO.logState(order.state,order.id,'','Подготовка подзаказов');
			var so:Suborder;
			for each(so in order.suborders){
				if(so) so.state=OrderState.PREPROCESS_WAITE;
			}
			nextSuborder();
		}

		private var currSuborder:Suborder;
		private var textBuilder:TextImageBuilder;
		private function nextSuborder():void{
			currSuborder=null;
			reportProgress();
			var so:Suborder;
			for each(so in order.suborders){
				if(so && so.project && so.state==OrderState.PREPROCESS_WAITE){
					currSuborder=so;
					break;
				}
			}
			if(!currSuborder){
				//complited
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			currSuborder.state=OrderState.PREPROCESS_PDF;
			if(logStates) StateLogDAO.logState(order.state,order.id,'','Подзаказ: '+ currSuborder.src_id);
			var dir:File=sourceDir.resolvePath(currSuborder.ftp_folder+File.separator+FBookProject.SUBDIR_WRK);
			textBuilder=new TextImageBuilder(currSuborder.project);
			textBuilder.addEventListener(Event.COMPLETE, onTxtComplite);
			textBuilder.addEventListener(ProgressEvent.PROGRESS, onTxtProgress);
			textBuilder.addEventListener(ImageProviderEvent.FLOW_ERROR_EVENT, onTxtFlowError);
			textBuilder.build(dir);
		}
		
		private function onTxtProgress(event:ProgressEvent):void{
			reportProgress('Подготовка текстов',event.bytesLoaded,event.bytesTotal);
		}

		private function onTxtFlowError(event:ImageProviderEvent):void{
			textBuilder.removeEventListener(Event.COMPLETE, onTxtComplite);
			textBuilder.removeEventListener(ProgressEvent.PROGRESS, onTxtProgress);
			textBuilder.removeEventListener(ImageProviderEvent.FLOW_ERROR_EVENT, onTxtFlowError);
			releaseWithErr(OrderState.ERR_PREPROCESS,event.error);
		}

		private function onTxtComplite(event:Event):void{
			textBuilder.removeEventListener(Event.COMPLETE, onTxtComplite);
			textBuilder.removeEventListener(ProgressEvent.PROGRESS, onTxtProgress);
			textBuilder.removeEventListener(ImageProviderEvent.FLOW_ERROR_EVENT, onTxtFlowError);
			if(textBuilder.hasError){
				releaseWithErr(textBuilder.error,textBuilder.errorMesage);
			}else{
				buildScripts();
			}
		}
		
		
		private var totalCommads:int;
		private var doneCommads:int;
		private var currPage:int;
		private var pages:Array;
		private function buildScripts():void{
			var outFolder:String=prtFolder+File.separator+currSuborder.ftp_folder+File.separator+PrintGroup.SUBFOLDER_PRINT;
			var scripBuilder:IMScript=new IMScript(currSuborder.project,outFolder);
			scripBuilder.build();
			pages=scripBuilder.pages;
			var p:PageData;

			var dir:File;
			//create print folder
			try{
				dir=new File(outFolder);
				if(dir.exists){
					if(dir.isDirectory){
						dir.deleteDirectory(true);
					}else{
						dir.deleteFile();
					}
				}
				dir.createDirectory();
			} catch(err:Error){
				releaseWithErr(OrderState.ERR_FILE_SYSTEM,err.message);
				return;
			}
			
			//save msl's
			var i:int;
			var file:File;
			dir=sourceDir.resolvePath(currSuborder.ftp_folder+File.separator+FBookProject.SUBDIR_WRK);
			for each (p in pages){
				if(p){
					//save msl script
					for (i=0;i<p.msls.length;i++){
						file=dir.resolvePath(p.scriptFileName(i));
						try{
							var fs:FileStream = new FileStream();
							fs.open(file, FileMode.WRITE);
							fs.writeUTFBytes(p.getMslString(i));
							fs.close();
						} catch(err:Error){
							releaseWithErr(OrderState.ERR_FILE_SYSTEM,err.message);
							return;
						}
					}
				}
			}
			//start page theads
			doneCommads=0;
			currPage=0;
			totalCommads=0;
			for each (p in pages){
				if(p) totalCommads+=p.commands.length;
			}
			for (i=0; i<Math.min(maxThreads,pages.length); i++){
				nextPage();
			}

		}

		private function nextPage():void{
			var pageBuilder:FBookPageBuilder;
			if(currPage<pages.length){
				var wrkFolder:String=sourceDir.nativePath+File.separator+currSuborder.ftp_folder+File.separator+FBookProject.SUBDIR_WRK;
				pageBuilder= new FBookPageBuilder(pages[currPage] as PageData, wrkFolder);
				pageBuilder.addEventListener(Event.COMPLETE, onPageComplete);
				pageBuilder.addEventListener(IMRunerEvent.IM_COMPLETED, onCommandComplete);
				currPage++;
				pageBuilder.build();
			}else{
				//complited
				nextSuborder();
			}
		}

		private function onPageComplete(evt:Event):void{
			var pageBuilder:FBookPageBuilder=evt.target as FBookPageBuilder;
			if(pageBuilder){
				pageBuilder.removeEventListener(Event.COMPLETE, onPageComplete);
				pageBuilder.removeEventListener(IMRunerEvent.IM_COMPLETED, onCommandComplete);
				if(pageBuilder.hasErr){
					trace('FBookMakeupManager. Book makeup error, book:'+currSuborder.src_id+', error: '+pageBuilder.error);
					IMRuner.stopAll();
					releaseWithErr(OrderState.ERR_PREPROCESS,pageBuilder.error);
					return;
				}else{
					nextPage();
				}
			}
		}

		private function onCommandComplete(evt:IMRunerEvent):void{
			doneCommads++;
			reportProgress('Подготовка книги',doneCommads,totalCommads);
		}

		/*
		
		private var sequence:Array;
		private var sequenceNum:int;
		private function runCommands(cmds:Array):void{
			if (maxThreads<=0){
				releaseWithErr(OrderState.ERR_PREPROCESS,'IM не настроен или количество потоков 0.');
				return;
			}
			sequence=cmds;
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
			reportProgress((sequenceNum==0?'Подготовка книги':'Формирование книги'),complited,commands.length);
			//check comleted
			if(!command && minState>=IMCommand.STATE_COMPLITE){
				//complited current sequence
				if(sequenceNum==0){
					//prepare sequence complete
					trace('FBookMakeupManager. Book makeup prepare step complited, book:'+currSuborder.src_id);
					sequenceNum++;
					//run final sequence
					if(finalCommands.length==0){
						trace('FBookMakeupManager. Book makeup complited, book:'+currSuborder.src_id);
						//complited
						nextSuborder();
					}else{
						runCommands(finalCommands);
					}
					return;
				}
				trace('FBookMakeupManager. Book makeup complited, book:'+currSuborder.src_id);
				//complited
				nextSuborder();
				return;
			}
			command.folder=sourceDir.nativePath+File.separator+currSuborder.ftp_folder+File.separator+FBookProject.SUBDIR_WRK;
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
			trace('FBookMakeupManager. Command complite: '+im.currentCommand);
			if(e.hasError){
				trace('FBookMakeupManager. Book makeup error, book:'+currSuborder.src_id+', error: '+e.error);
				IMRuner.stopAll();
				releaseWithErr(OrderState.ERR_PREPROCESS,e.error);
				return;
			}
			runNextCmd();
		}
		*/
		
		private function releaseWithErr(err:int,errMsg:String):void{
			if(err>=0) return;
			errNum=err;
			order.state=err;
			error=errMsg;
			if(logStates) StateLogDAO.logState(order.state,order.id,'',error);
			dispatchEvent(new Event(Event.COMPLETE));
		}

		
		private var progressTotal:int=0;
		private function reportProgress(caption:String='',ready:Number=0, total:Number=0):void{
			dispatchEvent(new OrderBuildProgressEvent(order.id+':'+(currSuborder?currSuborder.src_id:'')+' '+ caption,ready,total));
		}

	}
}