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
	
	[Event(name="error", type="flash.events.ErrorEvent")]
	[Event(name="complete", type="flash.events.Event")]
	[Bindable]
	public class GlueProgramHandler extends EventDispatcher{
		
		public function GlueProgramHandler(loop:Boolean = true){
			super(null);
			this.loop = loop;
		}
		
		private var loop:Boolean; 
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
				_glue.removeEventListener(Event.CONNECT, onGlueConnect);
			}
			_glue = value;
			if(_glue){
				_glue.addEventListener(ErrorEvent.ERROR, onGlueErr);
				_glue.addEventListener(GlueMessageEvent.GLUE_MESSAGE, onGlueMessage);
				_glue.addEventListener(Event.CONNECT, onGlueConnect);
			}
		}

		protected function onGlueErr(event:ErrorEvent):void{
			currStepCaption='Ошибка';
			if(isStarted && !isPaused){
				log('Остановка выполнения программы');
				isPaused=true;
			}
		}

		protected function onGlueConnect(event:Event):void{
			currStepCaption='Подключен';
		}

		
		public var currStep:int;
		public var currStepCaption:String
		public var isStarted:Boolean;
		public var isPaused:Boolean;
		public var debugMode:Boolean;
		
		public var loger:ISimpleLogger;
		
		public function connect():void{
			if(!glue) return;
			if(glue.isStarted) return;
			currStepCaption='Подключение';
			glue.start();
		}
		
		public function start():void{
			if(!glue || !glue.isStarted) return;
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
			currStepCaption='Пауза';
		}

		/*public function resume():void{
			if(!isStarted || !isPaused) return;
			isPaused=false;
			runStep();
		}*/
		
		public function stop():void{
			log('Остановка программы');
			currStepCaption='Стоп';
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
				case GlueProgramStep.TYPE_SET_PRODUCT : {
					//run command
					glue.run_SetProduct(program.product);
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
			}
		}

		private function checkMessages():Boolean{
			var step:GlueProgramStep=program.steps.getItemAt(currStep) as GlueProgramStep;
			if(!step){
				log('Не определен шаг программы (checkMessages)');
				return false;
			}
			if(step.type!=GlueProgramStep.TYPE_WAIT_FOR){
				log('Не верный шаг программы (checkMessages)' +step.type.toString());
				return false;
			}
			if(!step.checkBlocks || step.checkBlocks.length==0){
				log('Не определены условия проверки (checkMessages)' +step.type.toString());
				return false;
			}
			for each (var checkBlock:GlueMessageBlock in step.checkBlocks){
				//log('Проверяю блок ' +checkBlock.key+' элементов '+checkBlock.items.length.toString());
				var mess:GlueMessage= ArrayUtil.searchItem('type',checkBlock.type, lastMessages) as GlueMessage;
				if(mess){
					var mBlock:GlueMessageBlock=mess.getBlock(checkBlock.key);
					if(mBlock){
						var chItem:GlueMessageItem;
						for each(chItem in checkBlock.items){
							//log('Проверяю ' +chItem.key+'='+chItem.value);
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
			if (loop){
				currStep = (currStep+1) % program.steps.length;
			}else{
				currStep++;
				if (currStep == program.steps.length){
					//complited
					stop();
					dispatchEvent(new Event(Event.COMPLETE));
					return;
				}
			}
			step=program.steps.getItemAt(currStep) as GlueProgramStep;
			if(step) currStepCaption=step.caption;
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