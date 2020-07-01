package com.photodispatcher.provider.check{
	
	import by.blooddy.crypto.MD5;
	
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.IMRunerEvent;
	import com.photodispatcher.factory.PrintGroupBuilder;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderFile;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.shell.IMCommand;
	import com.photodispatcher.shell.IMMultiSequenceRuner;
	import com.photodispatcher.shell.IMRuner;
	import com.photodispatcher.shell.IMSequenceRuner;
	import com.photodispatcher.util.IMCommandUtil;
	import com.photodispatcher.util.StrUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.ByteArray;
	
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="progress", type="flash.events.ProgressEvent")]
	public class IMChecker extends BaseChecker{
		
		private var imPath:String;
		private var maxThreads:int;
		private var orderFolder:String;
		private var commands:Array;
		private var runner:IMSequenceRuner;
		private var multiRunner:IMMultiSequenceRuner;
		private var isScodix:Boolean;
		
		public function IMChecker(){
			super();
		}
		
		override public function init():void{
			imPath=Context.getAttribute('imPath');
			maxThreads=Context.getAttribute('imThreads');
			maxThreads=Math.max(1,maxThreads);
		}
		
		override public function stop():void{
			super.stop();
			IMRuner.stopAll();
		}
		
		
		
		override protected function reset():void{
			if(runner){
				runner.removeEventListener(ProgressEvent.PROGRESS, onProgress); 
				runner.removeEventListener(IMRunerEvent.IM_COMPLETED, onComplete); 
			}
			runner=null;
			if (multiRunner){
				multiRunner.removeEventListener(ProgressEvent.PROGRESS, onProgress); 
				multiRunner.removeEventListener(IMRunerEvent.IM_COMPLETED, onmultiComplete); 				
			}
			multiRunner=null;
			orderFolder=null;
			commands=[];
			isScodix = false;
			//TODO implement
		}
		
		override public function check(order:Order):void{
			if(isBusy) return;
			if(!imPath){
				progressCaption='IM не настроен ';
				return;
			}

			progressCaption='IM';
			hasError=false;
			error='';
			if(!order) return;
			reset();
			currOrder=order;
			if(!currOrder.files || currOrder.files.length==0){
				currOrder.state=OrderState.ERR_CHECK;
				releaseErr('Пустой список файлов');
				return;
			}
			//get order path
			var path:String;
			var file:File;
			var source:Source=Context.getSource(currOrder.source);
			if(source) path=source.getWrkFolder();
			if(path){
				path=path+File.separator+order.ftp_folder;
				file=new File(path);
				if(!file.exists || !file.isDirectory) file=null;
			}
			if(!file){
				currOrder.state=OrderState.ERR_FILE_SYSTEM;
				releaseErr('Папка заказа не доступна '+path);
				return;
			}
			//check scodix 
			isScodix = file.name.indexOf('scodix') > -1;
			orderFolder=file.nativePath;
			currOrder.state=OrderState.FTP_CHECK;
			createCommands();
			if(commands.length==0){
				//complited
				currOrder.state=OrderState.FTP_COMPLETE;
				currOrder.saveState();
				_isBusy=false;
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			_isBusy=true;
			progressCaption='IM '+currOrder.id;
			trace('IMChecker start: '+currOrder.id);
			runner= new IMSequenceRuner(null,true);
			runner.addEventListener(ProgressEvent.PROGRESS, onProgress); 
			runner.addEventListener(IMRunerEvent.IM_COMPLETED, onComplete); 
			runner.start(commands,maxThreads);
		}

		private function createCommands():void{
			var of:OrderFile;
			var command:IMCommand;
			for each(of in currOrder.files){
				if(of && of.state<OrderState.FTP_COMPLETE 
					&& of.file_name && PrintGroupBuilder.ALLOWED_EXTENSIONS[StrUtil.getFileExtension(of.file_name)] ){
					command=new IMCommand(IMCommand.IM_CMD_CONVERT);
					command.folder=orderFolder;
					command.sourceObject=of;
					command.add(of.file_name);
					command.add('null:');
					commands.push(command);
				}
			}
		}

		private function onProgress(e:ProgressEvent):void{
			dispatchEvent(e.clone());
		}
		private function onComplete(e:IMRunerEvent):void{
			if(runner){
				runner.removeEventListener(ProgressEvent.PROGRESS, onProgress); 
				runner.removeEventListener(IMRunerEvent.IM_COMPLETED, onComplete);
			}
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,0,0));
			progressCaption='IM';

			if(!currOrder || !isBusy) return;//stop

			var of:OrderFile;
			var command:IMCommand;

			//mark files as complited
			for each(of in currOrder.files){
				if(of) of.state=OrderState.FTP_COMPLETE;
			}
			if(!e.hasError){
				//check complite
				if(isScodix) {
					buildScodix();
					return;
				}
				currOrder.state=OrderState.FTP_COMPLETE;
				currOrder.saveState();
				_isBusy=false;
				dispatchEvent(new Event(Event.COMPLETE));
			}else{
				hasError=true;
				error='Ошибка проверки IM:';
				currOrder.state=OrderState.FTP_INCOMPLITE;
				currOrder.saveState();
				//mark files
				for each(command in commands){
					if(command){
						if(command.state==IMCommand.STATE_ERR){
							of=command.sourceObject as OrderFile;
							if(of){
								of.state=OrderState.ERR_CHECK_IM;
								StateLog.log(OrderState.ERR_CHECK_IM,currOrder.id,'',of.file_name+' err: '+command.error);
								//trace('IMChecker err: '+currOrder.id+'; '+of.file_name+' err: ' command.error);
								error=error+' '+of.file_name+';';
							}
						}
					}
				}
				trace('IMChecker err: '+currOrder.id+'; '+error);
				_isBusy=false;
				dispatchEvent(new Event(Event.COMPLETE));
			}
		}
		
		
		private function releaseErr(err:String):void{
			hasError=true;
			error=err;
			if(currOrder){
				trace('IMChecker err: '+currOrder.id+'; '+err);
				StateLog.log(currOrder.state,currOrder.id,'',err);
			}
			reset();
			_isBusy=false;
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,0,0));
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		
		/// scodix
		//TODO move to standalone class
		private function buildScodix():void{
			var books:Array=[];
			var scodix:Array=[];
			var sheetsPerBook:int=0;
			//build books
			//book with index 0 is template
			var of:OrderFile;
			for each(of in currOrder.files){
				if (!of || !of.file_name) continue;
				//parse
				//001-00s.pdf
				//001-00.jpg
				//001-01.jpg
				var fileName:String=of.file_name.toLowerCase();
				var subStr:String= fileName.substr(0,3);
				var isTemplate:Boolean= subStr=='000';
				var bookNum:int=int(subStr);
				if (!isTemplate && bookNum<=0) continue; //wrong format
				var sheetNum:int=int(fileName.substr(4,2));
				sheetsPerBook = Math.max(sheetsPerBook,sheetNum);
				var isScodixSheet:Boolean = sheetNum==0 && fileName.charAt(6)=='s';
				if (isScodixSheet){
					scodix[bookNum]=of.file_name;		
				}else{
					if (books[bookNum] == undefined) books[bookNum] = [];
					books[bookNum][sheetNum]=of.file_name;		
				}
			}
			
			//normalize scodix array
			scodix.length=books.length;
			//scan books (0 is template)
			for (var b:int=1; b<books.length; b++){
				if (!scodix[b] && !scodix[0] ){
					currOrder.state=OrderState.ERR_PREPROCESS;
					releaseErr('Не определен scodix для книги №'+b.toString());
					return;					
				}
				if (!scodix[b]) scodix[b]=scodix[0];
				//change file ext to .pdf
				if (StrUtil.getFileExtension(scodix[b]) != 'pdf') scodix[b]=StrUtil.setFileExtension(scodix[b],'pdf');
			}
			//gen commands
			var sequences:Array=[];
			var command:IMCommand;

			//convert all jpg to pdf pages
			//bmpp -l pdf.image -t jpeg  -o dct=on -o bpc=off -o interpolation=off -o resolution=chunk  D:\Buffer\lab\fudji\78985-2\cpy
			command=new IMCommand(IMCommand.IM_CMD_JPG2PDF);
			command.folder=orderFolder;
			IMCommandUtil.setJPG2PDFParams(command);
			//set foler vs jpg
			command.add(orderFolder);
			//add to first separate seq
			sequences.push([command]);

			//create pdf for each book
			//scan books (0 is template)
			var cmds:Array=[];
			//+ cover
			sheetsPerBook ++;
			var template:Array=[];
			if (books[0]) template=books[0] as Array;
			template.length=sheetsPerBook;
			for ( b=1; b<books.length; b++){
				var sheets:Array=[];
				if (books[b]){
					sheets = books[b] as Array;
				}
				sheets.length=sheetsPerBook;

				command=new IMCommand(IMCommand.IM_CMD_PDF_TOOL);
				command.folder=orderFolder;
				//add scodix
				command.add(scodix[b]);
				//add sheets
				for (var s:int=0; s<sheetsPerBook; s++){
					if (!sheets[s] && !template[s] ){
						currOrder.state=OrderState.ERR_PREPROCESS;
						releaseErr('Не определен лист '+StrUtil.lPad(b.toString(),3)+'-'+StrUtil.lPad(s.toString(),2));
						return;					
					}
					//change file ext to .pdf
					var flName:String= sheets[s]?sheets[s]:template[s];
					if (StrUtil.getFileExtension(flName) != 'pdf') flName=StrUtil.setFileExtension(flName,'pdf');
					command.add(flName);	
				}
				//finalise pdf command
				command.add('cat'); 
				command.add('output');
				//set output name
				command.add(StrUtil.lPad(b.toString(),3)+'.pdf');
				cmds.push(command);
			}
			//add books seq
			sequences.push(cmds);
			progressCaption='Scodix '+currOrder.id;
			multiRunner = new IMMultiSequenceRuner(); 
			multiRunner.addEventListener(ProgressEvent.PROGRESS, onProgress);
			multiRunner.addEventListener(IMRunerEvent.IM_COMPLETED, onmultiComplete);
			multiRunner.start(sequences,maxThreads,false);
		}
		private function onmultiComplete(e:IMRunerEvent):void{
			if(multiRunner){
				multiRunner.removeEventListener(ProgressEvent.PROGRESS, onProgress); 
				multiRunner.removeEventListener(IMRunerEvent.IM_COMPLETED, onmultiComplete);
			}
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,0,0));
			progressCaption='IM';
			
			if(!currOrder || !isBusy) return;//stop
			
			if(!e.hasError){
				//check complite
				currOrder.state=OrderState.FTP_COMPLETE;
				currOrder.saveState();
				_isBusy=false;
				dispatchEvent(new Event(Event.COMPLETE));
			}else{
				hasError=true;
				error='Ошибка формирования Scodix:' + e.error;
				currOrder.state=OrderState.FTP_INCOMPLITE;
				currOrder.saveState();
				trace('IMChecker err: '+currOrder.id+'; '+error);
				_isBusy=false;
				dispatchEvent(new Event(Event.COMPLETE));
			}
		}

	}
}