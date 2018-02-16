package com.photodispatcher.tech.picker{
	import com.photodispatcher.event.ControllerMesageEvent;
	import com.photodispatcher.model.mysql.entities.Layer;
	import com.photodispatcher.model.mysql.entities.LayerSequence;
	import com.photodispatcher.service.barcode.ComInfo;
	import com.photodispatcher.service.barcode.ComReader;
	import com.photodispatcher.service.barcode.FeederController;
	import com.photodispatcher.service.barcode.FeederSetController;
	import com.photodispatcher.service.barcode.Socket2Com;
	import com.photodispatcher.view.AlertrPopup;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	import mx.controls.Alert;

	[Event(name="error", type="flash.events.ErrorEvent")]
	public class TechPickerFeeder extends TechPicker{
		
		public function TechPickerFeeder(techGroup:int){
			super(techGroup);
			feedDelay=100;
		}
		
		override public function get feedDelay():int{
			return super.feedDelay;
		}
		
		override public function set feedDelay(value:int):void{
			if(value<100) value=100;
			super.feedDelay = value;
		}
		
		
		override protected function onControllerMsg(event:ControllerMesageEvent):void{
			if(!isRunning || isPaused) return;
			if(event.state==FeederController.CHANEL_STATE_REAM_EMPTY){
				var msg:String='Лоток '+(event.chanel+1).toString()+': '+FeederController.chanelStateName(FeederController.CHANEL_STATE_REAM_EMPTY);
				log(msg);
				/*
				var ap:AlertrPopup= new AlertrPopup();
				ap.show(msg,3,16);
				*/
				return;
			}
			//reset refeed
			refeed=false;
			if(event.chanel==currentTray){
				//msg from current tray
				if(layerInLatch.isOn && (event.state==FeederController.CHANEL_STATE_SINGLE_SHEET || event.state==FeederController.CHANEL_STATE_DOUBLE_SHEET)){
					//layerIn msg					
					var waiteState:int=FeederController.CHANEL_STATE_SINGLE_SHEET;
					//var wrongState:int=FeederController.CHANEL_STATE_DOUBLE_SHEET;
					if(currentLayer==Layer.LAYER_SHEET){
						waiteState=FeederController.CHANEL_STATE_DOUBLE_SHEET;
						//wrongState=FeederController.CHANEL_STATE_SINGLE_SHEET;
					}
					
					if((event.state==waiteState) || (doubleSheetOff && currentLayer==Layer.LAYER_SHEET && event.state==FeederController.CHANEL_STATE_SINGLE_SHEET)){
						//start OutLatch
						layerOutLatch.setOn();
						//layer in
						//currentTray=-1;
						layerInLatch.forward();
					}else{ //if(event.state==wrongState){
						//wrong state
						pause('Лоток '+(event.chanel+1).toString()+': '+FeederController.chanelStateName(event.state));
					}
				}else if(layerOutLatch.isOn && event.state==FeederController.CHANEL_STATE_SHEET_PASS){
					//layer out
					currentTray=-1;
					if(currentGroup!=COMMAND_GROUP_BOOK_SHEET) currBarcode=null; //barcode covered vs some layer
					if(feedDelay<100){
						layerOutLatch.forward();
					}else{
						startFeedDelay();
					}
				}else{
					//unexpected msg
					pause('Не ожидаемое срабатывание '+'Лоток '+(event.chanel+1).toString()+': '+FeederController.chanelStateName(event.state));
				}
			}else{
				//msg from wrong tray
				pause('Не ожидаемое срабатывание '+'Лоток '+(event.chanel+1).toString()+': '+FeederController.chanelStateName(event.state));
			}
		}
		
		override protected function nextStep():void{
			//controller.close(currentTray);
			//reset refeed
			refeed=false;

			if(!isRunning || isPaused) return;
			if(hasPauseRequest){
				hasPauseRequest=false;
				pause('Пауза по запросу пользователя',false);
				return;
			}
			var steps:int=0;
			switch(currentGroup){
				case COMMAND_GROUP_START:
					if (vacuumOnStartOn) steps++;
					if (engineOnStartOn) steps++;
					if(currentGroupStep>=steps){
						//complite
						currentGroup= COMMAND_GROUP_BOOK_START;
						//nextStep();
						runDelayTimer();
						return;
					}
					if(currentGroupStep==0 && vacuumOnStartOn){
						//log('vacuumOn');
						aclLatch.setOn();
						controller.vacuumOn();
						return;
					}
					//log('engineOn');
					aclLatch.setOn();
					controller.engineOn();
					break;
				case COMMAND_GROUP_PAUSE:
					steps=3;
					if(currentGroupStep>=steps){
						//complite
						pauseComplete();
						return;
					}
					switch(currentGroupStep){
						case 0:
							/*
							if(currentTray!=-1){
								aclLatch.setOn();
								controller.close(currentTray);
							}else{
							*/
								currentGroupStep++;
								nextStep();
							//}
							break;
						case 1:
							if (vacuumOnErrOff){
								aclLatch.setOn();
								controller.vacuumOff();
							}else{
								currentGroupStep++;
								nextStep();
							}
							break;
						case 2:
							if (engineOnErrOff){
								aclLatch.setOn();
								controller.engineOff();
							}else{
								currentGroupStep++;
								nextStep();
							}
							break;
					}
					break;
				case COMMAND_GROUP_RESUME:
					steps=2;
					if(currentGroupStep>=steps){
						//complite 
						//restore paused step
						if(pausedGroup!=-1 && pausedGroupStep!=-1){
							log('Resume complited');
							currentGroup=pausedGroup;
							currentGroupStep=pausedGroupStep;
							pausedGroup=-1;
							pausedGroupStep=-1;
							runDelayTimer();
						}
						return;
					}
					switch(currentGroupStep){
						case 0:
							if (vacuumOnErrOff){
								aclLatch.setOn();
								controller.vacuumOn();
							}else{
								currentGroupStep++;
								nextStep();
							}
							break;
						case 1:
							if (engineOnErrOff){
								aclLatch.setOn();
								controller.engineOn();
							}else{
								currentGroupStep++;
								nextStep();
							}
							break;
					}
					break;
				case COMMAND_GROUP_STOP:
					steps=3;
					if(currentGroupStep>=steps){
						//complite
						stopComplite();
						return;
					}
					switch(currentGroupStep){
						case 0:
							/*
							if(currentTray!=-1){
								aclLatch.setOn();
								controller.close(currentTray);
							}else{
							*/
								currentGroupStep++;
								nextStep();
							//}
							break;
						case 1:
							aclLatch.setOn();
							controller.vacuumOff();
							break;
						case 2:
							aclLatch.setOn();
							controller.engineOff();
							break;
					}
					break;
				case COMMAND_GROUP_BOOK_START:
					//check completed
					if(currentGroupStep>=currentSequence.length){
						//complited
						currentGroup= COMMAND_GROUP_BOOK_SHEET;
						nextStep();
						return;
					}
					feedLayer(currentSequence[currentGroupStep] as LayerSequence);
					break;
				case COMMAND_GROUP_BOOK_SHEET:
					//check completed
					if(currentGroupStep>=1){
						//complited
						if ((sheetCount>=currSheetTot) || (register && register.currentBookComplited)){ 
							//book complited
							currentGroup= COMMAND_GROUP_BOOK_END;
						}else{
							currentGroup= COMMAND_GROUP_BOOK_BETWEEN_SHEET;
						}
						nextStep();
						return;
					}
					feedSheet();
					break;
				case COMMAND_GROUP_BOOK_BETWEEN_SHEET:
					//check completed
					if(!currInerlayer || currentGroupStep>=currInerlayer.sequenceMiddle.length){
						//complited
						currentGroup= COMMAND_GROUP_BOOK_SHEET;
						nextStep();
						return;
					}
					feedLayer(currInerlayer.sequenceMiddle[currentGroupStep] as LayerSequence);
					break;
				case COMMAND_GROUP_BOOK_END:
					//check completed
					if(currentGroupStep>=currentSequence.length){
						sheetCount=0;
						if(logger) logger.clear();
						//if (currBookIdx>=currBookTot){ 
						if (register.isComplete){
							//order complited
							detectFirstBook=false;
							register.finalise();
							register=null;
							currBookTot=-1;
							currBookIdx=-1;
							currSheetTot=-1;
							currSheetIdx=-1;
							log('Заказ '+currPgId+' завершен.');
							currPgId='';
							currExtraInfo=null;
							currentGroup= COMMAND_GROUP_ORDER_END;
							nextStep();
						}else{
							//current book complited
							currentGroup= COMMAND_GROUP_BOOK_START;
							nextStep();
						}
						return;
					}
					feedLayer(currentSequence[currentGroupStep] as LayerSequence);
					break;
				case COMMAND_GROUP_ORDER_END:
					if(currentGroupStep>=1){
						//complite
						if(stopOnComplite){
							stop();
							return;
						}
						currentGroup= COMMAND_GROUP_BOOK_START;
						if(pauseOnComplite){
							pause('Пауза между заказами',false);
							return;
						}
						nextStep();
						return;
					}
					feedLayer(currentSequence[0] as LayerSequence);
					break;
				default:
					log('Не определена последовательность');
					break;
			}
		}
		
		override protected function startDevices():void{
			//create devs
			
			//controller
			var proxies:Array= serialProxy.getProxiesByType(ComInfo.COM_TYPE_CONTROLLER);
			var controllers:Array=[];
			if(proxies){
				var proxy:Socket2Com;
				var c:FeederController;
				for each(proxy in proxies){
					if(proxy && proxy.tray>0){
						c= new FeederController();
						c.comPort=proxy;
						controllers.push(c);
					}
				}
			}
			if(!controller){
				var newController:FeederSetController= new FeederSetController();
				newController.controllers=controllers;
				controller=newController;
			}else{
				(controller as FeederSetController).controllers=controllers;
			}

			controller.start();
			
			//reinit trayset
			if(!traySet) traySet= new TraySet();
			traySet.controllers=controllers;
			
			//bar readers
			var readers:Array= serialProxy.getProxiesByType(ComInfo.COM_TYPE_BARREADER);
			if(!readers || readers.length==0) return;
			var i:int;
			if(!barcodeReaders){
				//init bar readers
				var newBarcodeReaders:Array=[];
				for (i=0; i<readers.length; i++) newBarcodeReaders.push(new ComReader(500));
				barcodeReaders=newBarcodeReaders;
			}
			if(readers.length!=barcodeReaders.length){
				barcodeReaders=null;
				return;
			}
			//start readers
			for (i=0; i<readers.length; i++) (barcodeReaders[i] as ComReader).start(readers[i]);
		}
		
		override protected function feedLayer(ls:LayerSequence):void{
			refeed=true;
			super.feedLayer(ls);
			//start out latch ??? 			layerOutLatch.setOn();
		}
		
		override protected function feedSheet():void{
			refeed=true;
			super.feedSheet();
			//start out latch ??? 			layerOutLatch.setOn();
		}
		
		protected var refeed:Boolean=false;
		
		override protected function onLatchTimeout(event:ErrorEvent):void{
			//controller.close(currentTray);

			if(!isRunning || isPaused) return;
			var l:PickerLatch=event.target as PickerLatch;
			if(!l) return; 
			switch(l.type){
				case PickerLatch.TYPE_ACL:
					refeed=false;
					if(isServiceGroup(currentGroup)){
						//skip
						//log('ACL Timeout - skipped (service group)');
						l.reset();
						checkLatches();
						break;
					}
				case PickerLatch.TYPE_REGISTER:
					pause('Таймаут ожидания. '+l.label+':'+l.caption);
					break;
				case PickerLatch.TYPE_BARCODE:
					if(layerInLatch.isOn || layerOutLatch.isOn || waiteTraySwitch){
						//sheet is not in or not out; restart
						//also restart barLatch on waiteTraySwitch complite
						barLatch.setOn();
					}else{
						//TODO neve run?
						if(register && register.inexactBookSequence && register.currentBookComplited){
							register.finalise();
							register=null;
							inexactBookSequence=false;
							log('Сборка брака завершена: заказ "'+currPgId+'"');
							stop();
							return;
						}
						pause('Таймаут ожидания. '+l.label+':'+l.caption);
					}
					break;
				case PickerLatch.TYPE_LAYER_IN:
					//layer not in
					//try refeed
					if(refeed){
						log('Лоток '+(currentTray+1).toString()+' повторная подача листа.');
						refeed=false;
						layerInLatch.setOn(); //restart in latch
						if(currentGroup==COMMAND_GROUP_BOOK_SHEET) barLatch.setOn(); //restart bar latch
						aclLatch.setOn();
						controller.open(currentTray);
						return;
					}
					//try next tray 
					currentTray=-1;
					var ct:int=traySet.getNextTray(currentLayer); 
					if(ct<0 || layerInLatch.startingTray==ct){
						//check if defect complited
						if(currentGroup==COMMAND_GROUP_BOOK_SHEET){
							if(register && register.inexactBookSequence && register.currentBookComplited){
								register.finalise();
								register=null;
								inexactBookSequence=false;
								log('Сборка брака завершена: заказ "'+currPgId+'"');
								stop();
								return;
							}
						}
						pause('Заполните лотки для слоя '+traySet.getLayerName(currentLayer));
						return;
					}
					//open next tray
					log('Cлой '+traySet.getLayerName(currentLayer)+' переключение на лоток '+(currentTray+1).toString());
					refeed=true;
					currentTray=ct;
					layerInLatch.setOn();
					if(currentGroup==COMMAND_GROUP_BOOK_SHEET) barLatch.setOn(); //restart bar latch
					aclLatch.setOn();
					controller.open(currentTray);
					break;
				case PickerLatch.TYPE_LAYER_OUT:
					//layer not out
					pause('Застрял слой '+traySet.getLayerName(currentLayer));
					break;
			}
		}
		
		override protected function onLatchRelease(event:Event):void{
			if(!isRunning || isPaused) return;
			checkLatches();
		}
		
		private var feedTimer:Timer;
		
		protected function startFeedDelay():void{
			if(feedDelay<100) return;
			
			if(!feedTimer){
				feedTimer= new Timer(feedDelay,1);
				feedTimer.addEventListener(TimerEvent.TIMER, onFeedDelayTimer);
			}
			feedTimer.start();
			log('Задержка подачи листа');
		}
		private function onFeedDelayTimer(evt:TimerEvent):void{
			layerOutLatch.forward();
		}
	}
}