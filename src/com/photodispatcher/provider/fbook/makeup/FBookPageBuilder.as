package com.photodispatcher.provider.fbook.makeup{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.IMRunerEvent;
	import com.photodispatcher.provider.fbook.data.PageData;
	import com.photodispatcher.shell.IMCommand;
	import com.photodispatcher.shell.IMRuner;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="imCompleted", type="com.photodispatcher.event.IMRunerEvent")]
	public class FBookPageBuilder extends EventDispatcher{
		
		public var hasErr:Boolean;
		public var error:String;

		private var page:PageData;
		private var wrkFolder:String;
		private var commands:Array;
		
		public function FBookPageBuilder(page:PageData, wrkFolder:String){
			super(null);
			this.page=page;
			this.wrkFolder=wrkFolder;
		}
		
		public function build():void{
			if(!page || !wrkFolder){
				releaseWithErr('FBookPageBuilder ошибка инициализации');
				return;
			}
			commands=page.commands;
			if(!commands || commands.length==0){
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			
			runNextCommand();
		}
		
		private function runNextCommand():void{
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
			
			//check comleted
			if(!command && minState>=IMCommand.STATE_COMPLITE){
				//complited 
				trace('FBookPageBuilder. Page makeup complited, page:'+page.pageNum.toString());
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			command.folder=wrkFolder;
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
			trace('FBookPageBuilder. Command complite: '+im.currentCommand);
			if(e.hasError){
				trace('FBookPageBuilder. Page makeup error, page:'+page.pageNum.toString()+', error: '+e.error);
				//IMRuner.stopAll(); !!! stop in manager
				releaseWithErr(e.error);
				return;
			}
			dispatchEvent(e.clone());
			runNextCommand();
		}

		
		private function releaseWithErr(errMsg:String):void{
			hasErr=true;
			error=errMsg;
			dispatchEvent(new Event(Event.COMPLETE));
		}
	}
}