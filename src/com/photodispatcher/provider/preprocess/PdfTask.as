package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.IMRunerEvent;
	import com.photodispatcher.shell.IMCommand;
	import com.photodispatcher.shell.IMRuner;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.filesystem.File;
	
	[Event(name="complete", type="flash.events.Event")]
	public class PdfTask extends EventDispatcher{
		
		private var srcFileName:String;
		private var wrkDir:String;

		public var resultFileName:String;
		public var hasError:Boolean;
		public var err_msg:String;
		
		public function PdfTask(fileName:String){
			srcFileName=fileName;
			super(null);
		}
		
		public function catFrom(startPage:int){
			if(startPage<=0){
				hasError=true;
				err_msg='Не верная стартовая страница ' +startPage.toString();
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			init();
			var command:IMCommand=new IMCommand(IMCommand.IM_CMD_PDF_TOOL);
			command.folder=wrkDir;
			//pdftk in.pdf cat 1-12 14-end output out1.pdf
			command.add(srcFileName);
			command.add('cat');
			command.add(startPage.toString()+'-end');
			command.add('output');
			command.add(resultFileName);
			runCmd(command);

		}

		public function catTo(endPage:int){
			if(endPage<=0){
				hasError=true;
				err_msg='Не верная страница ' +endPage.toString();
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			init();
			var command:IMCommand=new IMCommand(IMCommand.IM_CMD_PDF_TOOL);
			command.folder=wrkDir;
			//pdftk in.pdf cat 1-12 14-end output out1.pdf
			command.add(srcFileName);
			command.add('cat');
			command.add('1-'+endPage.toString());
			command.add('output');
			command.add(resultFileName);
			runCmd(command);
		}
		
		private function init():void{
			var altPdf:Boolean=Context.getAttribute("altPDF");
			
			if(!altPdf){
				hasError=true;
				err_msg='Не настроена альтернативная сборка в PDF';
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			
			if(!srcFileName){
				hasError=true;
				err_msg='Не указан файл';
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			
			var file:File=new File(srcFileName);
			if(!file.exists || file.isDirectory){
				hasError=true;
				err_msg='Файл '+srcFileName+' не найден';
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			
			var dstName:String=file.name+'C';
			var idx:int=0;
			var dir:File=file.parent;
			wrkDir=dir.nativePath;
			file=dir.resolvePath(dstName+'.pdf');
			while(file.exists && idx<100){
				idx++;
				file=dir.resolvePath(dstName+idx.toString()+'.pdf');
			}
			resultFileName=file.nativePath;
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
			
			if(e.hasError){
				hasError=true;
				err_msg=e.error;
				trace('IMSequenceRuner. Error: '+e.error+'\n command: '+(e.command?e.command.toString():''));
			}
			dispatchEvent(new Event(Event.COMPLETE));
		}

	}
}