package com.photodispatcher.print{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.IMRunerEvent;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrintGroupFile;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.services.OrderStateService;
	import com.photodispatcher.model.mysql.services.PrintGroupService;
	import com.photodispatcher.shell.IMCommand;
	import com.photodispatcher.shell.IMRuner;
	import com.photodispatcher.util.IMCommandUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.filesystem.File;
	
	import mx.collections.ArrayCollection;
	
	import org.granite.tide.Tide;
	
	[Event(name="complete", type="flash.events.Event")]
	public class PreparePrint extends EventDispatcher{
		public static const ROTATE_FOLDER:String='rotate';

		public var hasErr:Boolean=false;
		public var errMsg:String;
		
		public var printGrp:PrintGroup;
		private var lab:LabGeneric;
		
		private var srcFolder:File;
		private var commands:Array=[];
		private var maxThreads:int=0;
		private var rotate:Boolean;
		private var profilePath:String;
		
		public function PreparePrint(printGroup:PrintGroup, lab:LabGeneric){
			super(null);
			this.printGrp=printGroup;
			this.lab=lab;
		}
		
		public function run():void{
			if(!printGrp || !lab){
				if(printGrp) printGrp.state=OrderState.ERR_PRINT_POST;
				dispatchErr('Не верные параметры запуска.');
				return;
			}
			
			//check if neeed prepare
			rotate=printGrp.book_type!=0 &&
				(lab.src_type==SourceType.LAB_NORITSU || lab.src_type==SourceType.LAB_NORITSU_NHF) &&
				Context.getAttribute('printRotated');
			profilePath=lab.profileFile(printGrp.paper);
			//check if prifile file exists
			if(profilePath){
				var file:File= new File(profilePath);
				if(!file.exists || file.isDirectory) profilePath=null;
			}
			if(!rotate && !profilePath){
				//nothig to prepare
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			
			//capture rotate state
			printGrp.state=OrderState.PRN_PREPARE;
			//call service
			var svc:PrintGroupService=Tide.getInstance().getContext().byType(PrintGroupService,true) as PrintGroupService;
			var latch:DbLatch= new DbLatch(true);
			latch.addEventListener(Event.COMPLETE,onStateCapture);
			latch.addLatch(svc.capturePrintState(new ArrayCollection([printGrp]),false));
			latch.start();
		}
		
		private function onStateCapture(evt:Event):void{
			var pgBd:PrintGroup;
			var latch:DbLatch= evt.target as DbLatch;
			if(latch) latch.removeEventListener(Event.COMPLETE,onStateCapture);
			if(!latch || !latch.complite){
				printGrp.state=OrderState.ERR_READ_LOCK;
				dispatchErr('Ошибка базы: ' +latch.error);
				return;
			}
			var result:Array=latch.lastDataArr;
			if(result && result.length>0){
				pgBd=result[0] as PrintGroup;
				if(pgBd.id!=printGrp.id) pgBd=null;
			}
			
			if(!pgBd || pgBd.state!=OrderState.PRN_PREPARE){
				//can't сapture state
				if(pgBd){
					printGrp.state=pgBd.state;
				}else{
					printGrp.state=OrderState.ERR_READ_LOCK;
				}
				dispatchErr('Не верный статус группы печати (сapture state '+OrderState.PRN_PREPARE.toString()+') '+printGrp.id);
				return;
			}
			runRotate();
		}


		private function runRotate():void{	
			lab.stateCaption='Допечатная подготовка';
			//check src folder
			//look up prt folder in print & wrk folders
			var src:Source=Context.getSource(printGrp.source_id);
			var srcFName:String;
			var dir:File;
			if(src){
				//check print folder
				srcFName=src.getPrtFolder()+File.separator+printGrp.order_folder+File.separator+printGrp.path;
				try{ 
					srcFolder=new File(srcFName);
				}catch(e:Error){}
				if(srcFolder && srcFolder.exists){
					dir=srcFolder.resolvePath(PrintGroup.SUBFOLDER_PRINT);
					if(!dir.exists || !dir.isDirectory) srcFolder=null;
				}else{
					srcFolder=null;
				}
				if(!srcFolder){
					//check wrk folder
					srcFName=src.getWrkFolder()+File.separator+printGrp.order_folder+File.separator+printGrp.path;
					try{ 
						srcFolder=new File(srcFName);
					}catch(e:Error){}
					if(srcFolder && srcFolder.exists){
						dir=srcFolder.resolvePath(PrintGroup.SUBFOLDER_PRINT);
						if(!dir.exists || !dir.isDirectory) srcFolder=null;
					}else{
						srcFolder=null;
					}
				}
			}
			
			if(!srcFolder){
				// set order err state 
				printGrp.state=OrderState.ERR_PRINT_POST_FOLDER_NOT_FOUND;
				dispatchErr('Папка группы печати '+printGrp.id+' "'+srcFName+'" не найдена.');
				return;
			}
			
			//create result subdir
			var dstFolder:File=srcFolder.resolvePath(ROTATE_FOLDER);
			//attemt to create
			try{
				if(dstFolder.exists) dstFolder.deleteDirectory(true); 
				dstFolder.createDirectory();
				dstFolder=dstFolder.resolvePath(PrintGroup.SUBFOLDER_PRINT);
				dstFolder.createDirectory();
			}catch(e:Error){
				printGrp.state=OrderState.ERR_FILE_SYSTEM;
				dispatchErr('Ошибка создания папки "'+dstFolder.nativePath+'". '+e.message);
				return;
			}

			//generate commands
			createCommands();
			if(commands.length==0){
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}

			//set state 
			printGrp.state=OrderState.PRN_PREPARE;
			StateLog.logByPGroup(OrderState.PRN_PREPARE,printGrp.id,'Поворот на 180');
			//proces
			runCommands();
		}

		private function createCommands():void{
			commands=[];
			var files:Array;
			var i:int;
			var item:PrintGroupFile;
			var command:IMCommand;

			files=printGrp.printFiles;
			if(!files || files.length==0) return;

			for (i=0; i<files.length; i++){
				item=files[i] as PrintGroupFile;
				if(item){
					command=new IMCommand(IMCommand.IM_CMD_CONVERT);
					command.folder=srcFolder.nativePath;
					command.add(item.file_name);
					if(rotate){
						//convert 001-02.jpg "-rotate" "180" -quality 100 001-02_r180.jpg
						command.add('-rotate');
						command.add('180');
					}
					if(profilePath){
						//convert "001-24 (1).jpg" -intent relative -black-point-compensation -profile "../Noritsu3411_ChrystalArchive-Semimate.icm" "..\cnv\001-24 (1).jpg"
						command.add('-intent'); command.add('relative');
						command.add('-black-point-compensation');
						command.add('-profile'); command.add(profilePath);
					}
					
					IMCommandUtil.setOutputParams(command);
					command.add(ROTATE_FOLDER+File.separator+item.file_name);
					commands.push(command);
				}
			}
		}
		
		private function runCommands():void{
			maxThreads=Context.getAttribute('imThreads');
			if (maxThreads<=0){
				//dispatchErr(OrderState.ERR_PRINT_POST,'IM не настроен или количество потоков 0.');
				//skip prepare
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			//start theads
			for (var i:int=0; i<Math.min(maxThreads,commands.length); i++){
				runNextCmd();
			}
		}
		
		private function runNextCmd():void{
			var cmd:IMCommand;
			var command:IMCommand;
			var minState:int= IMCommand.STATE_COMPLITE;
			//var complited:int=0;
			if(hasErr) return;
			//look not statrted
			for each (cmd in commands){
				if(cmd){
					minState=Math.min(minState,cmd.state);
					if(cmd.state==IMCommand.STATE_WAITE){
						if(!command) command=cmd;
						//break;
					}
					//if(cmd.state==IMCommand.STATE_COMPLITE) complited++;
				}
			}
			//reportProgress((sequenceNum==0?'Подготовка книги':'Сборка PDF'),complited,commands.length);
			//check comleted
			if(!command && minState>=IMCommand.STATE_COMPLITE){
				//complited
				trace('RotateTask. Complited, printgroup '+printGrp.id);
				//TODO set rotate mark
				printGrp.printPrepare=true;
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			runCmd(command);
		}
		private function runCmd(command:IMCommand):void{
			if(!command) return;
			var im:IMRuner=new IMRuner(Context.getAttribute('imPath'),command.folder);
			im.addEventListener(IMRunerEvent.IM_COMPLETED, onCmdComplite);
			im.start(command, false);
		}
		private function onCmdComplite(e:IMRunerEvent):void{
			var im:IMRuner=e.target as IMRuner;
			im.removeEventListener(IMRunerEvent.IM_COMPLETED, onCmdComplite);
			trace('RotateTask. Command complite: '+im.currentCommand);
			if(e.hasError){
				trace('RotateTask. Rotate error, printgroup '+printGrp.id+', error: '+e.error);
				//IMRuner.stopAll();
				if(!hasErr){
					printGrp.state=OrderState.ERR_PREPROCESS;
					dispatchErr(e.error);
				}
				return;
			}
			runNextCmd();
		}

		
		private function dispatchErr(msg:String):void{
			hasErr=true;
			errMsg=msg;
			//StateLogDAO.logState(printGrp.state, printGrp.order_id,printGrp.id,'Ошибка размещения на печать: '+msg); 
			dispatchEvent(new Event(Event.COMPLETE));
		}

	}
}