package com.photodispatcher.service.glue{
	
	import com.photodispatcher.event.GlueMessageEvent;
	import com.photodispatcher.interfaces.ISimpleLogger;
	import com.photodispatcher.model.mysql.AsyncLatch;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	[Bindable]
	public class GlueProgramHandler extends EventDispatcher{
		
		public function GlueProgramHandler(){
			super(null);
		}
		
		private var _program:GlueProgram;
		public function get program():GlueProgram{
			return _program;
		}
		public function set program(value:GlueProgram):void{
			if(isStarted){
				riseErr(0,'Не допускается смена программы вовремя выполнения');
				return
			}
			_program = value;
		}
		
		
		private var _glue:GlueProxy;
		public function get glue():GlueProxy{
			return _glue;
		}
		public function set glue(value:GlueProxy):void{
			if(_glue){
				_glue.removeEventListener(ErrorEvent.ERROR, onGlueErr);
				_glue.removeEventListener(GlueMessageEvent.GLUE_MESSAGE, onGlueMessage);
			}
			_glue = value;
			_glue.addEventListener(ErrorEvent.ERROR, onGlueErr);
			_glue.addEventListener(GlueMessageEvent.GLUE_MESSAGE, onGlueMessage);

		}

		protected function onGlueErr(event:ErrorEvent):void{
			if(isStarted && !isPaused){
				log('Остановка выполнения программы');
				isPaused=true;
			}
		}

		
		public var currStep:int;
		public var isStarted:Boolean;
		public var isPaused:Boolean;
		public var debugMode:Boolean;
		
		public var loger:ISimpleLogger;
		
		public function start():void{
			if(!glue && !glue.isStarted) return;
			if(!program || !program.steps || program.steps.length<2) return;
			if(isStarted && !isPaused) return;
			if(!isPaused){
				if(loger) loger.clear();
				currStep=0;
				isStarted=true;
				log('Старт программы');
			}else{
				log('Возобновление программы');
				isPaused=false;
			}
			runStep();
		}
		
		public function pause():void{
			if(!isStarted || isPaused) return;
			isPaused=true;
			log('Пауза программы');

		}

		/*public function resume():void{
			if(!isStarted || !isPaused) return;
			isPaused=false;
			runStep();
		}*/
		
		public function stop():void{
			log('Остановка программы');
			isStarted=false;
			isPaused=false;
		}

		private var timer:Timer;
		private var lastMessages:Array;

		protected function runStep():void{
			if(!isStarted || isPaused) return;
			var step:GlueProgramStep=program.steps.getItemAt(currStep) as GlueProgramStep;
			log('Выполнение '+step.caption);
			switch(step.type){
				case GlueProgramStep.TYPE_PAUSE: 
				case GlueProgramStep.TYPE_WAIT_FOR: {
					if(step.interval>20){
						if(!timer){
							timer= new Timer(step.interval,1);
							timer.addEventListener(TimerEvent.TIMER_COMPLETE, onTimer);
						}
						timer.delay=step.interval;
						timer.reset();
						timer.start();
					}else{
						nextStep();
					}
					break;
				}
				case GlueProgramStep.TYPE_PUSH_BUTTON : {
					//run command
					glue.pushButton(step.command);
					//TODO waite acl
					nextStep();
					break;
				}
					
				default: {
					nextStep();
					break;
				}
			}
		}
		
		private function onTimer(e:TimerEvent):void{
			if(!isStarted) return;
			var step:GlueProgramStep=program.steps.getItemAt(currStep) as GlueProgramStep;
			if(step.type==GlueProgramStep.TYPE_PAUSE){
				//puse complite 
				nextStep();
			}else if(step.type==GlueProgramStep.TYPE_WAIT_FOR){
				//ask states
				lastMessages=[];
				glue.run_GetButtons();
				glue.run_GetStatus();
				/*
				var latch:AsyncLatch=glue.run_GetButtons();
				latch.join(glue.run_GetStatus());
				latch.addEventListener(Event.COMPLETE, onMessagesComplite);
				latch.start();
				*/
			}
		}
		
		/*
		private function onMessagesComplite(evt:Event):void{
			var latch:AsyncLatch=evt.target as AsyncLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE, onMessagesComplite);
				if(!isStarted) return;
				if(latch.hasError){
					latch.stop();
					if(isStarted && !isPaused){
						log('Остановка выполнения программы');
						isPaused=true;
						return;
					}
				}
			}
			if(checkMessages()){
				//waite complite 
				nextStep();
			}else{
				//keep waite
				runStep();
			}
		}
		*/
		

		private function checkMessages():Boolean{
			var step:GlueProgramStep=program.steps.getItemAt(currStep) as GlueProgramStep;
			for each (var checkBlock:GlueMessageBlock in step.checkBlocks){
				var mess:GlueMessage= ArrayUtil.searchItem('type',checkBlock.type, lastMessages) as GlueMessage;
				if(mess){
					var mBlock:GlueMessageBlock=mess.getBlock(checkBlock.key);
					if(mBlock){
						var chItem:GlueMessageItem;
						for each(chItem in checkBlock){
							var mItem:GlueMessageItem=mBlock.getItem(chItem.key);
							if(!mItem || mItem.value!=chItem.value) return false;
						}
					}else{
						return false;
					}
				}else{
					return false;
				}
			}
			return true;
		}
		
		private function onGlueMessage( event:GlueMessageEvent ):void{
			var step:GlueProgramStep=program.steps.getItemAt(currStep) as GlueProgramStep;
			if(!event.message ) return;
			if(step.type==GlueProgramStep.TYPE_WAIT_FOR){
				lastMessages.push(event.message);
				if(lastMessages && lastMessages.length==2){
					if(checkMessages()){
						//waite complite 
						log('Проверка состояния - выпонено');
						nextStep();
					}else{
						//keep waite
						log('Проверка состояния - не выпонено');
						runStep();
					}

				}
			}
		}

		protected function nextStep():void{
			var step:GlueProgramStep=program.steps.getItemAt(currStep) as GlueProgramStep;
			if(step) log('Завершено '+step.caption);
			currStep = (currStep+1) % program.steps.length;
			runStep();
		}

		protected function log(msg:String):void{
			if(loger) loger.log(msg);
		}
		
		protected function riseErr(errCode:int,msg:String):void{
			dispatchEvent( new ErrorEvent(ErrorEvent.ERROR,false,false,msg,errCode));
		}

	}
}