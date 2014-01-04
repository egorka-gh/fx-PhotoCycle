package com.photodispatcher.print{
	import com.photodispatcher.event.PrintEvent;
	import com.photodispatcher.model.BookSynonym;
	import com.photodispatcher.model.Lab;
	import com.photodispatcher.model.LabDevice;
	import com.photodispatcher.model.LabPrintCode;
	import com.photodispatcher.model.LabRoll;
	import com.photodispatcher.model.OrderState;
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.Roll;
	import com.photodispatcher.model.dao.LabPrintCodeDAO;
	import com.photodispatcher.model.dao.StateLogDAO;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;

	[Event(name="postComplete", type="com.photodispatcher.event.PrintEvent")]
	public class LabBase extends Lab implements IEventDispatcher{
		public static const STATE_ERROR:int=-1;
		public static const STATE_OFF:int=0;
		public static const STATE_ON:int=1;
		public static const STATE_SCHEDULED_ON:int=2;
		public static const STATE_SCHEDULED_OFF:int=3;
		public static const STATE_ON_WARN:int=4;
		public static const STATE_MANUAL:int=10;
		
		[Bindable]
		public var enabled:Boolean=true;//??????
		[Bindable]
		public var stateCaption:String;
		[Bindable]
		public var printQueue:PrintQueue;

		[Bindable]
		public var onlineState:int=STATE_OFF;

		//public var currentPG:PrintGroup;
		
		protected var printTasks:Array=[];
		protected var _chanelMap:Object;
		
		public function LabBase(lab:Lab){
			super();
			lab.cloneTo(this);
			printQueue=new PrintQueue(this);
		}

		public function orderFolderName(printGroup:PrintGroup):String{
			return printGroup?printGroup.id:'';
		}

		public function post(pg:PrintGroup):void{
			if(!pg) return;
			if (!canPrint(pg)){
				pg.state=OrderState.ERR_PRINT_POST;
				dispatchErr(pg,'Группа печати '+pg.id+' не может быть распечатана в '+name+'.');
				return;
			}
			var pt:PrintTask= new PrintTask(pg,this);
			printTasks.push(pt);
			//start post sequence
			stateCaption='Копирование';
			postNext();
		}
		
		protected function dispatchErr(pg:PrintGroup, msg:String):void{
			StateLogDAO.logState(pg.state, pg.order_id,pg.id,'Ошибка размещения на печать: '+msg);
			dispatchEvent(new PrintEvent(PrintEvent.POST_COMPLETE_EVENT,pg,msg));
		}

		private var postRunning:Boolean;
		protected function postNext():void{
			if(postRunning) return;
			var pt:PrintTask;
			if(printTasks.length>0){
				pt=printTasks.shift() as PrintTask;
			}
			if(pt){
				postRunning=true;
				StateLogDAO.logState(OrderState.PRN_POST, pt.printGrp.order_id, pt.printGrp.id);
				pt.addEventListener(Event.COMPLETE,taskComplete);
				pt.post();
			}else{
				//complited
				stateCaption='Копирование завершено';
			}
		}
		
		public function taskComplete(e:Event):void{
			postRunning=false;
			var pt:PrintTask=e.target as PrintTask;
			if(pt){
				pt.removeEventListener(Event.COMPLETE,taskComplete);
				if (pt.hasErr){
					dispatchErr(pt.printGrp, pt.errMsg);
				}else{
					dispatchEvent(new PrintEvent(PrintEvent.POST_COMPLETE_EVENT,pt.printGrp));
					//StateLogDAO.logState(pt.printGrp.state, pt.printGrp.order_id, pt.printGrp.id,this.name?this.name:('id:'+this.id));
				}
			}
			postNext();
		}
		
		/**
		 *print script props  
		 * */
		public function printChannelCode(printGroup:PrintGroup):String{
			var result:LabPrintCode=printChannel(printGroup);
			return result?result.prt_code:'';
		}

		public function printChannel(printGroup:PrintGroup):LabPrintCode{
			var cm:Object=chanelMap;
			if(!cm || !printGroup) return null;
			var result:LabPrintCode=cm[printGroup.key(src_type)] as LabPrintCode;
			if(!result && printGroup.book_type!=0 
				&& printGroup.book_part!=BookSynonym.BOOK_PART_INSERT && printGroup.book_part!=BookSynonym.BOOK_PART_AU_INSERT){
				//lookup vs closest height
				var ch:LabPrintCode;
				for each (ch in cm){
					//exclude height
					if(ch && ch.key(src_type,1)==printGroup.key(src_type,1) && ch.height>=printGroup.height){
						if(!result){
							result=ch;
						}else if((result.height-printGroup.height)>(ch.height-printGroup.height)){
							result=ch;
						}
					}
				}
			}
			return result;
		}

		protected function canPrint(printGroup:PrintGroup):Boolean{
			var result:LabPrintCode=printChannel(printGroup);
			return result?true:false;
		}
		
		// Lazy loading chanels
		protected function get chanelMap():Object{
			if(!_chanelMap){
				var dao:LabPrintCodeDAO= new LabPrintCodeDAO();
				var chanels:Array= dao.findAllArray(this.src_type);
				if(chanels){
					_chanelMap=new Object;
					for each(var o:Object in chanels){
						var ch:LabPrintCode=o as LabPrintCode;
						if(ch){
							_chanelMap[ch.key(src_type)]=ch;
						}
					}
				}
			}
			return _chanelMap;
		}
		
		public function getOnlineRolls():Array{
			var result:Array=[];
			var dev:LabDevice;
			var roll:LabRoll;
			if(!devices) return result;
			for each(dev in devices){
				if(dev.isOnline){
					if(dev.rolls){
						for each(roll in dev.rolls){
							if (roll.is_online) result.push(roll.clone());
						}
					}
				}
			}
			return result;
		}

		public function getOnlineRoll(paper:int,width:int):LabRoll{
			var dev:LabDevice;
			var roll:LabRoll;
			if(!devices) return null;
			for each(dev in devices){
				if(dev.isOnline){
					if(dev.rolls){
						for each(roll in dev.rolls){
							if (roll.is_online && roll.paper==paper && roll.width==width) return roll.clone();
						}
					}
				}
			}
			return null;
		}

		/*
		public function calcQueueTime(rolls:Array):int{
			if (!rolls || rolls.length==0) return -1;
			var len1:int=0;
			var	len2:int=0
			var speed1:int=0;
			var speed2:int=0;
			var dev:LabDevice;
			if(!devices) return -1; 
			for each(dev in devices){
				if(dev.isOnline){
					speed1+=dev.speed1;
					speed2+=dev.speed2;
				}
			}
			if(speed1<=0 && len1!=0) return -1;
			if(speed2<=0 && len2!=0) return -1;
			return (len1?len1/speed1:0+len2?len2/speed2:0);
		}
		*/
		
		public function getOnlineDevices():Array{
			var result:Array=[];
			var dev:LabDevice;
			refreshOnlineState();
			if(!devices) return result;
			for each(dev in devices){
				if(onlineState==STATE_MANUAL){
					return [dev];
				}else if(dev.isOnline){
					result.push(dev);
				}
			}
			return result;
		}

		public function setRollSpeed(roll:LabRoll):void{
			if(!roll || !devices) return;
			roll.speed=0;
			var dev:LabDevice;
			if(roll.lab_device){
				dev=ArrayUtil.searchItem('id',roll.lab_device,devices) as LabDevice;
				if(dev) roll.speed=roll.width<203?dev.speed1:dev.speed2;
			}
			if(roll.speed==0){
				var speed:int=int.MAX_VALUE;
				//get min speed from all devices
				for each(dev in devices) speed=Math.min(speed,roll.width<203?dev.speed1:dev.speed2);
				if(speed!=int.MAX_VALUE) roll.speed=speed;
			}
		}

		public function refresh():void{
			refreshOnlineState();
			refreshPrintQueue();
		}

		public function refreshPrintQueue():void{
			printQueue.refresh();	
		}
		public function refreshOnlineState():void{
			var dev:LabDevice;
			var newState:int=STATE_OFF;
			if(!is_managed || !devices){
				onlineState=STATE_MANUAL;
				return;
			}
			for each(dev in devices){
				if(dev){
					dev.checkTimeTable();
					newState=Math.max(newState,dev.onlineState);
				}
			}
			onlineState=newState;
		}
	}
}
