package com.photodispatcher.shell{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.IMRunerEvent;
	
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.ProgressEvent;
	
	[Event(name="imCompleted", type="com.photodispatcher.event.IMRunerEvent")]
	[Event(name="progress", type="flash.events.ProgressEvent")]
	public class IMSequenceRuner extends EventDispatcher{
		
		private var sequence:Array;
		private var threads:int;
		private var hasErr:Boolean=false;
		private var forceStop:Boolean=false;
		
		
		public var compliteCommands:int;

		public var state:int=IMCommand.STATE_WAITE;

		public var ignoreErrors:Boolean;

		public function IMSequenceRuner(sequence:Array=null, ignoreErrors:Boolean=false){
			super(null);
			this.sequence=sequence;
			this.ignoreErrors=ignoreErrors;
		}
		
		public function start(sequence:Array=null, threads:int=1):void{
			hasErr=false;
			compliteCommands=0;
			if(sequence) this.sequence=sequence;
			this.threads=threads;
			if(!this.sequence || this.sequence.length==0){
				//empty sequence 
				dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED));
				return;
			}
			if(threads<=0){
				//no threads 
				dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED,null,true,'IM не настроен или количество потоков 0.'));
				return;
			}
			state=IMCommand.STATE_STARTED;
			//start theads
			for (var i:int=0; i<Math.min(threads,this.sequence.length); i++){
				runNextCmd();
			}
		}
		
		public function stop():void{
			forceStop=true;
			IMRuner.stopAll();
		}
		
		private function runNextCmd():void{
			var cmd:IMCommand;
			var command:IMCommand;
			var minState:int= IMCommand.STATE_COMPLITE;
			var complited:int=0;
			if(!ignoreErrors && hasErr) return;
			if(forceStop) return;
			//look not statrted
			for each (cmd in sequence){
				minState=Math.min(minState,cmd.state);
				if(cmd.state==IMCommand.STATE_WAITE){
					if(!command) command=cmd;
					//break;
				}
				if(cmd.state==IMCommand.STATE_COMPLITE || (ignoreErrors && cmd.state==IMCommand.STATE_ERR)) complited++;
			}
			compliteCommands=complited;
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,complited,sequence.length));
			//check comleted
			if(!command && minState>=IMCommand.STATE_COMPLITE){
				//complite
				if(hasErr){
					state=IMCommand.STATE_ERR;
				}else{
					state=IMCommand.STATE_COMPLITE;
				}
				dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED, null,hasErr));
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
			if(forceStop) return;

			if(e.hasError){
				hasErr=true;
				trace('IMSequenceRuner. Error: '+e.error+'\n command: '+(e.command?e.command.toString():''));
				if(!ignoreErrors){
					state=IMCommand.STATE_ERR;
					IMRuner.stopAll();
					dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED,e.command,true,e.error));
					return;
				}
			}
			runNextCmd();
		}

	}
}