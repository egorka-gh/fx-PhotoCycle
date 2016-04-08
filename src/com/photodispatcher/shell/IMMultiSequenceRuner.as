package com.photodispatcher.shell{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.IMRunerEvent;
	
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.ProgressEvent;
	
	[Event(name="imCompleted", type="com.photodispatcher.event.IMRunerEvent")]
	[Event(name="progress", type="flash.events.ProgressEvent")]
	public class IMMultiSequenceRuner extends EventDispatcher{
		
		private var sequence:Array;
		private var threads:int;
		private var totalCommands:int;
		private var hasErr:Boolean=false;
		private var parallel:Boolean=true;
		
		public var ignoreWarning:Boolean;

		public function IMMultiSequenceRuner(ignoreWarning:Boolean=false){
			super(null);
			this.ignoreWarning=ignoreWarning;
		}
		
		public function start(sequences:Array, threads:int=1, parallel:Boolean=true):void{
			this.parallel=parallel;
			hasErr=false;
			//this.sequences=sequences;
			this.threads=threads;
			if(!sequences || sequences.length==0){
				//empty sequence 
				dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED));
				return;
			}
			if(threads<=0){
				//no threads 
				dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED,null,true,'IM не настроен или количество потоков 0.'));
				return;
			}

			//create sequence
			sequence=[];
			var seq:Array;
			var runer:IMSequenceRuner;
			totalCommands=0;
			for each(seq in sequences){
				if(seq && seq.length>0){
					totalCommands+=seq.length;
					runer= new IMSequenceRuner(seq,ignoreWarning);
					sequence.push(runer);
				}
			}
			if(sequence.length==0){
				//empty sequence 
				dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED));
				return;
			}
			
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,0,totalCommands));
			//start theads
			if(parallel){
				for (var i:int=0; i<Math.min(threads,sequence.length); i++){
					runNextSequence();
				}
			}else{
				runNextSequence();
			}
		}
		
		private function runNextSequence():void{
			var runer:IMSequenceRuner;
			var startRuner:IMSequenceRuner;
			var minState:int= IMCommand.STATE_COMPLITE;
			//var complited:int=0;
			if(hasErr) return;
			//look not statrted
			for each (runer in sequence){
				minState=Math.min(minState,runer.state);
				if(runer.state==IMCommand.STATE_WAITE){
					if(!startRuner) startRuner=runer;
				}
				//complited+=runer.compliteCommands;
			}
			//dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,complited,totalCommands));
			//check comleted
			if(!startRuner && minState>=IMCommand.STATE_COMPLITE){
				//complite
				dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED));
				return;
			}
			runSequence(startRuner);
		}
		private function runSequence(runer:IMSequenceRuner):void{
			if(!runer) return;
			runer.addEventListener(IMRunerEvent.IM_COMPLETED, onCmdComplite);
			runer.addEventListener(ProgressEvent.PROGRESS, onCmdProgress);
			if(parallel){
				runer.start();
			}else{
				runer.start(null,threads);
			}
		}
		private function onCmdComplite(e:IMRunerEvent):void{
			var runer:IMSequenceRuner=e.target as IMSequenceRuner;
			runer.removeEventListener(IMRunerEvent.IM_COMPLETED, onCmdComplite);
			runer.removeEventListener(ProgressEvent.PROGRESS, onCmdProgress);
			if(e.hasError){
				hasErr=true;
				trace('IMMultiSequenceRuner. Error: '+e.error+'\n command: '+(e.command?e.command.toString():''));
				IMRuner.stopAll();
				dispatchEvent(new IMRunerEvent(IMRunerEvent.IM_COMPLETED,e.command,true,e.error));
				return;
			}
			runNextSequence();
		}
		
		private function onCmdProgress(e:ProgressEvent):void{
			var runer:IMSequenceRuner;
			var complited:int=0;
			for each (runer in sequence){
				complited+=runer.compliteCommands;
			}
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,complited,totalCommands));
		}

	}
}