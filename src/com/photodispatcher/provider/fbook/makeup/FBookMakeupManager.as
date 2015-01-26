package com.photodispatcher.provider.fbook.makeup{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.IMRunerEvent;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.event.OrderBuildProgressEvent;
	import com.photodispatcher.factory.PrintGroupBuilder;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.entities.SubOrder;
	import com.photodispatcher.provider.fbook.FBookProject;
	import com.photodispatcher.provider.fbook.model.PageData;
	import com.photodispatcher.provider.preprocess.BookMakeupGroup;
	import com.photodispatcher.shell.IMCommand;
	import com.photodispatcher.shell.IMMultiSequenceRuner;
	import com.photodispatcher.shell.IMRuner;
	import com.photodispatcher.shell.IMSequenceRuner;
	
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
			if(logStates) StateLog.log(order.state,order.id,'','Подготовка подзаказов');
			var so:SubOrder;
			for each(so in order.suborders){
				if(so && so.state<OrderState.CANCELED) so.state=OrderState.PREPROCESS_WAITE;
			}
			nextSuborder();
		}

		private var currSuborder:SubOrder;
		private var textBuilder:TextImageBuilder;
		private function nextSuborder():void{
			currSuborder=null;
			reportProgress();
			var so:SubOrder;
			for each(so in order.suborders){
				if(so && so.projects && so.projects.length>0 && so.state==OrderState.PREPROCESS_WAITE){
					currSuborder=so;
					break;
				}
			}
			if(!currSuborder){
				//complited
				//build print groups
				var builder:PrintGroupBuilder= new PrintGroupBuilder();
				var pgArr:Array;
				try{
					pgArr=builder.buildFromSuborders(order);
				}catch (e:Error){
					trace('FBookMakeupManager error while build print group'+order.id+', error: '+e.message);
					releaseWithErr(OrderState.ERR_READ_LOCK,'Блокировка чтения или ошибка шаблона (FBookMakeupManager).');
					return;
				}
				//run post process
				if(pgArr && pgArr.length>0){
					postProcess(pgArr);
				}else{
					dispatchEvent(new Event(Event.COMPLETE));
				}
				return;
			}
			currSuborder.state=OrderState.PREPROCESS_PDF;
			currSuborder.resetlog();
			if(currSuborder.isMultibook){
				//numerate books
				var project:FBookProject;
				var book:int=0;
				for each (project in currSuborder.projects){
					book++;
					project.bookNumber=book;
				}
			}

			if(logStates) StateLog.log(currSuborder.state,order.id,currSuborder.sub_id,'');
			var dir:File=sourceDir.resolvePath(order.ftp_folder+File.separator+currSuborder.ftp_folder+File.separator+FBookProject.SUBDIR_WRK);
			textBuilder=new TextImageBuilder(currSuborder);
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
		
		private function buildScripts():void{
			var outFolder:String=prtFolder+File.separator+order.ftp_folder+File.separator+currSuborder.ftp_folder+File.separator+PrintGroup.SUBFOLDER_PRINT;
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
			
			var project:FBookProject;
			var scripBuilder:IMScriptL;//=new IMScriptL(currSuborder.project,sourceDir.nativePath+File.separator+order.ftp_folder+File.separator+currSuborder.ftp_folder); //use suborder folder (currSuborder.ftp_folder)
			var pages:Array;
			var p:PageData;
			var sequences:Array=[];
			var txt:String=currSuborder.log+'\n';
			currSuborder.resetlog();
			for each (var obj:Object in currSuborder.projects){
				project=obj as FBookProject;
				if(project){
					scripBuilder=new IMScriptL(project,sourceDir.nativePath+File.separator+order.ftp_folder+File.separator+currSuborder.ftp_folder); 
					scripBuilder.build();
					pages=scripBuilder.pages;

					//save msl's
					var i:int;
					var file:File;
					var fs:FileStream;
					var msl:IMMsl;
					dir=sourceDir.resolvePath(order.ftp_folder+File.separator+currSuborder.ftp_folder+File.separator+FBookProject.SUBDIR_WRK);
					for each (p in pages){
						if(p){
							//save msl script
							for (i=0;i<p.rootLayer.msls.length;i++){
								msl=p.rootLayer.msls[i] as IMMsl;
								file=dir.resolvePath(msl.fileName);
								try{
									fs = new FileStream();
									fs.open(file, FileMode.WRITE);
									fs.writeUTFBytes(msl.getMslString());
									fs.close();
								} catch(err:Error){
									releaseWithErr(OrderState.ERR_FILE_SYSTEM,err.message);
									return;
								}
							}
						}
					}
					
					//add sripts 2 sequences
					txt=txt+'-----------------------------------'+'\n';
					txt=txt+'Project id:'+project.id +' scripts'+'\n';
					var cmd:IMCommand;
					for each (p in pages){
						txt=txt+'Page #'+p.pageNum.toString()+'\n';
						//set commands work folder
						for each(cmd in p.rootLayer.commands){
							cmd.folder=dir.nativePath;
							txt=txt+cmd.toString()+'\n';
						}
						sequences.push(p.rootLayer.commands);
					}

				}
			}

			//save log
			txt=txt.replace(/\n/g,String.fromCharCode(13, 10));
			file=dir.resolvePath('log.txt');
			fs= new FileStream();
			try{
				fs = new FileStream();
				fs.open(file, FileMode.APPEND);
				fs.writeUTFBytes(txt);
				fs.close();
			} catch(err:Error){}

			var runner:IMMultiSequenceRuner= new IMMultiSequenceRuner();
			runner.addEventListener(ProgressEvent.PROGRESS, onCommandsProgress);
			runner.addEventListener(IMRunerEvent.IM_COMPLETED, onPagesComplite);
			runner.start(sequences,maxThreads);

		}
		private function onPagesComplite(evt:IMRunerEvent):void{
			var runner:IMMultiSequenceRuner=evt.target as IMMultiSequenceRuner;
			runner.removeEventListener(ProgressEvent.PROGRESS, onCommandsProgress);
			runner.removeEventListener(IMRunerEvent.IM_COMPLETED, onPagesComplite);
			if(evt.hasError){
				releaseWithErr(OrderState.ERR_PREPROCESS,evt.error);
			}else{
				nextSuborder();
			}
		}
		private function onCommandsProgress(evt:ProgressEvent):void{
			reportProgress('Подготовка книги',evt.bytesLoaded,evt.bytesTotal);
		}

		private function postProcess(printGroups:Array):void{
			var pg:PrintGroup;
			var mg:BookMakeupGroup;
			var mgs:Array=[];
			//hasErr=false;
			for each(pg in printGroups){
				if(pg){
					mg=new BookMakeupGroup(pg,order.id, sourceDir.nativePath+File.separator+order.ftp_folder, prtFolder+File.separator+order.ftp_folder);
					try{
						mg.createCommands();
					}catch(err:Error) {
						releaseWithErr(OrderState.ERR_PREPROCESS,err.message);
						return;
					}
					if(mg.state==BookMakeupGroup.STATE_ERR){
						//complite vs error
						releaseWithErr(mg.err,mg.err_msg);
						return;
					}
					if(mg.hasCommands){
						mgs.push(mg);
					}
				}
			}
			if(mgs.length==0){
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			var sequence:Array=[];
			for each (mg in mgs){
				if(mg){
					sequence=sequence.concat(mg.commands);
				}
			}
			//run sequence
			var runer:IMSequenceRuner= new IMSequenceRuner();
			runer.addEventListener(IMRunerEvent.IM_COMPLETED, onPostProcess);
			runer.addEventListener(ProgressEvent.PROGRESS, onPostProcessProgress);
			runer.start(sequence,maxThreads);
		}

		private function onPostProcessProgress(evt:ProgressEvent):void{
			reportProgress('Обработка книг',evt.bytesLoaded,evt.bytesTotal);
		}

		private function onPostProcess(evt:IMRunerEvent):void{
			var runer:IMSequenceRuner=evt.target as IMSequenceRuner;
			if(runer){
				runer.removeEventListener(IMRunerEvent.IM_COMPLETED, onPostProcess);
				runer.removeEventListener(ProgressEvent.PROGRESS, onCommandsProgress);
			}
			if(evt.hasError){
				releaseWithErr(OrderState.ERR_PREPROCESS,evt.error);
			}else{
				dispatchEvent(new Event(Event.COMPLETE));
			}
		}
		
		private function releaseWithErr(err:int,errMsg:String):void{
			if(err>=0) return;
			errNum=err;
			order.state=err;
			error=errMsg;
			if(logStates) StateLog.log(order.state,order.id,'',error);
			dispatchEvent(new Event(Event.COMPLETE));
		}

		
		private var progressTotal:int=0;
		private function reportProgress(caption:String='',ready:Number=0, total:Number=0):void{
			dispatchEvent(new OrderBuildProgressEvent(order.id+':'+(currSuborder?currSuborder.sub_id:'')+' '+ caption,ready,total));
		}

	}
}