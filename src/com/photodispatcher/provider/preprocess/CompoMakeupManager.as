package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.IMRunerEvent;
	import com.photodispatcher.event.OrderBuildProgressEvent;
	import com.photodispatcher.factory.PrintGroupBuilder;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.BookPgTemplate;
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderBook;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrintGroupFile;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.shell.IMCommand;
	import com.photodispatcher.shell.IMMultiSequenceRuner;
	import com.photodispatcher.shell.IMSequenceRuner;
	import com.photodispatcher.util.IMCommandUtil;
	import com.photodispatcher.util.StrUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	
	import mx.collections.ArrayCollection;
	
	import org.granite.tide.Tide;

	[Event(name="complete", type="flash.events.Event")]
	[Event(name="progress", type="com.photodispatcher.event.OrderBuildProgressEvent")]
	public class CompoMakeupManager  extends EventDispatcher{

		public function get hasErr():Boolean{
			return errNum<0;
		}
		
		public var errNum:int=0;
		public var error:String;

		private var order:Order;
		private var sourceFolder:String;
		private var maxThreads:int=0;
		private var sourceDir:File;
		private var forceStop:Boolean=false;

		public function CompoMakeupManager(order:Order, sourceFolder:String){
			super(null);
			this.order=order;
			this.sourceFolder=sourceFolder;
		}

		public function run():void{
			errNum=0;
			error='';
			if(!order || !sourceFolder ){
				releaseWithErr(OrderState.ERR_PREPROCESS,'Ошибка инициализации');
				return ;
			}
			var src:Source = Context.getSource(order.source);
			if(!src || src.type != SourceType.SRC_INTERNAL) {
				dispatchEvent(new Event(Event.COMPLETE));
				return ;
			}
			maxThreads=Context.getAttribute('imThreads');
			if (maxThreads<=0){
				releaseWithErr(OrderState.ERR_PREPROCESS,'Не настроен ImageMagick');
				return;
			}
			sourceDir=new File(sourceFolder);
			
			/*
			if(!sourceDir || !sourceDir.exists || !sourceDir.isDirectory){
				releaseWithErr(OrderState.ERR_FILE_SYSTEM,'Не найдена папка '+sourceFolder);
				return;
			}
			*/
			var pg:PrintGroup;
			for each(pg in order.printGroups){
				pg.state=OrderState.PREPROCESS_WAITE;
				//check create printgroup folder
				try{
					var subDir:File=sourceDir.resolvePath(order.ftp_folder).resolvePath(pg.path);
					//clean
					if(subDir.exists){
						if(subDir.isDirectory){
							subDir.deleteDirectory(true);
						}else{
							subDir.deleteFile();
						}
						subDir.createDirectory();
					}
				}catch(err:Error) {
					trace('Ошибка создания папки: '+err.message);
					releaseWithErr(OrderState.ERR_FILE_SYSTEM,'Ошибка создания папки: '+err.message);
					return;
				}
				//get template
				var pt:BookPgTemplate= BookSynonym.getTemplateByPg(pg);
				if(!pt){
					releaseWithErr(OrderState.ERR_GET_PROJECT,"Не найден шаблон " +pg.alias);
					return;					
				}
				pg.bookTemplate=pt;
			}
			
			order.state=OrderState.PREPROCESS_COMPO;
			StateLog.log(order.state,order.id,'','Сборка комбо');
			//load child printgroups
			var latch:DbLatch= new DbLatch(true);
			latch.addEventListener(Event.COMPLETE,onloadChilds);
			latch.addLatch(orderService.loadCompoChilds(order.id));
			latch.start();
		}
		private function get orderService():OrderService{
			return Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
		}
		private var childPGs: ArrayCollection
		private function onloadChilds(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch) latch.removeEventListener(Event.COMPLETE,onloadChilds);
			if(!latch || !latch.complite) {
				releaseWithErr(OrderState.ERR_GET_PROJECT,latch.error);
				return;
			}
			if(!latch.lastDataAC || latch.lastDataAC.length==0) {
				releaseWithErr(OrderState.ERR_GET_PROJECT,"Пустой список элементов комбо");
				return;
			}
			childPGs=latch.lastDataAC;
			//set templates & check 
			for each(var pg:PrintGroup in childPGs){
				var pt:BookPgTemplate= BookSynonym.getTemplateByPg(pg);
				if(!pt){
					releaseWithErr(OrderState.ERR_GET_PROJECT,"Не найден шаблон " +pg.alias);
					return;					
				}
				pg.bookTemplate=pt;
				if(!pg.printFolder){
					releaseWithErr(OrderState.ERR_FILE_SYSTEM,"Не найдена папка для группы " +pg.id);
					return;					
					
				}
				var bf:Array = pg.bookFiles;
				if (!bf || bf.length==0){
					releaseWithErr(OrderState.ERR_GET_PROJECT,"Пустая группа " +pg.id);
					return;										
				}
			}
			startSequence();		
		}

		private var runner:IMSequenceRuner;
		public function stop():void{
			forceStop=true;
			if(runner){
				runner.removeEventListener(ProgressEvent.PROGRESS, onPostProcessProgress);
				runner.removeEventListener(IMRunerEvent.IM_COMPLETED, onPostProcess);
				runner.stop();
				runner=null;
			}
		}
		private var sequence:Array;
		private function startSequence():void{
			sequence=[];
			reportProgress();
			var pg:PrintGroup;
			//create commands
			for each(pg in order.printGroups){
				if(pg ){
					pg.state=OrderState.PREPROCESS_COMPO;
					StateLog.logByPGroup(pg.state, pg.id,"");
					sequence = sequence.concat(buildCommands(pg));
				}
			}
			if(sequence.length==0){
				releaseWithErr(OrderState.ERR_PREPROCESS,"Пустая последовательность команд");
				return;										
			}
			//run sequence
			runner = new IMSequenceRuner();
			runner.addEventListener(IMRunerEvent.IM_COMPLETED, onPostProcess);
			runner.addEventListener(ProgressEvent.PROGRESS, onPostProcessProgress);
			runner.start(sequence,maxThreads);
		}
		
		private function onPostProcessProgress(evt:ProgressEvent):void{
			reportProgress('Сборка комбо',evt.bytesLoaded,evt.bytesTotal);
		}
		private function reportProgress(caption:String='',ready:Number=0, total:Number=0):void{
			dispatchEvent(new OrderBuildProgressEvent(order.id+': '+ caption,ready,total));
		}

		private function onPostProcess(evt:IMRunerEvent):void{
			var runer:IMSequenceRuner=evt.target as IMSequenceRuner;
			if(runer){
				runer.removeEventListener(IMRunerEvent.IM_COMPLETED, onPostProcess);
				runer.removeEventListener(ProgressEvent.PROGRESS, onPostProcessProgress);
			}
			if(evt.hasError){
				releaseWithErr(OrderState.ERR_PREPROCESS,evt.error);
			}else{
				dispatchEvent(new Event(Event.COMPLETE));
			}
		}
		
		private function buildCommands(currPG : PrintGroup):Array{
			//init arrays
			var sheetNum:int=currPG.sheet_num;
			//if (currPG.book_part == BookSynonym.BOOK_PART_BLOCKCOVER ) sheetNum++;
			//book/sheet/files 
			var abk:Array = new Array(currPG.book_num);
			var ash:Array;
			for (var bi:int=0; bi<currPG.book_num; bi++){
				ash= new Array(sheetNum);
				for(var si:int=0; si<sheetNum; si++) ash[si]=[];
				abk[bi]=ash;
			}
			//fill it			
			for each (var pg:PrintGroup in childPGs){
				if (pg){
					var pgPath:File = pg.printFolder;
					for each (var b:OrderBook in pg.books){
						if(b.compo_pg==currPG.id ){
							ash=abk[b.compo_book-1];
							var abf:Array=pg.bookFiles;
							//fiil sheets
							for(si=0; si<sheetNum; si++){
								var bf:PrintGroupFile = abf[(b.book-1)*sheetNum+si];
								if(bf && bf.file_name){
									ash[si].push(pgPath.resolvePath(bf.file_name).nativePath);
								}
							}
						}
					}
				}
			}
			//check/create print group folder
			var outDir:File= sourceDir.resolvePath(order.ftp_folder).resolvePath(currPG.path);
			try{
				if(outDir.exists) outDir.deleteDirectory(true);
				outDir.createDirectory();				
			}catch (e:Error){
				//TODO exception
			}
			
			currPG.resetBookFiles();
			currPG.resetFiles();
			//create scripts
			var cmds:Array=[];
			for (bi=0; bi<currPG.book_num; bi++){
				for(si=0; si<sheetNum; si++){
					var cmd:IMCommand = new IMCommand(IMCommand.IM_CMD_CONVERT);
					cmd.folder = outDir.nativePath;
					cmd.add('-background'); cmd.add('White');
					cmd.add('-gravity'); cmd.add('West');
					//add child files
					for each(var fn:String in abk[bi][si]) cmd.add(fn);
					if (abk[bi][si].length >1){
						cmd.add('-append');
						cmd.add('+repage');						
					}
					//rotate
					cmd.add('-matte');
					cmd.add('-virtual-pixel'); cmd.add('transparent');
					cmd.add('+distort'); cmd.add('ScaleRotateTranslate'); cmd.add("90");
					cmd.add('+repage');
					//create pg file
					bf= new PrintGroupFile();
					bf.book_part=pg.book_part;
					bf.book_num = bi+1;
					bf.page_num = si+1;
					//for blockcover - last page is cover
					if (currPG.book_part == BookSynonym.BOOK_PART_BLOCKCOVER && si == (sheetNum-1) ) bf.page_num = 0;
					bf.file_name=StrUtil.lPad(bf.book_num.toString(),3)+'-'+StrUtil.lPad(bf.page_num.toString(),2)+'.jpg';
					bf.caption=PrintGroupFile.CAPTION_BOOK_NUM_HOLDER+'-'+StrUtil.lPad(bf.page_num.toString(),2);
					bf.prt_qty=1;
					bf.print_group=pg.id;
					currPG.addFile(bf);
					IMCommandUtil.setOutputParams(cmd);
					cmd.add(bf.file_name);
					cmds.push(cmd);
				}
			}
			return cmds;
		}
		
		private function releaseWithErr(err:int,errMsg:String):void{
			if(err>=0) return;
			errNum=err;
			order.state=err;
			error=errMsg;
			StateLog.log(order.state,order.id,'',error);
			dispatchEvent(new Event(Event.COMPLETE));
		}

	}
}