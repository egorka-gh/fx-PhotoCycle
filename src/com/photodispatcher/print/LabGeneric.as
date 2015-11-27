package com.photodispatcher.print{
	import com.google.zxing.common.flexdatatypes.ArrayList;
	import com.photodispatcher.event.PrintEvent;
	import com.photodispatcher.model.mysql.entities.BookPgTemplate;
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.model.mysql.entities.Lab;
	import com.photodispatcher.model.mysql.entities.LabDevice;
	import com.photodispatcher.model.mysql.entities.LabMeter;
	import com.photodispatcher.model.mysql.entities.LabPrintCode;
	import com.photodispatcher.model.mysql.entities.LabProfile;
	import com.photodispatcher.model.mysql.entities.LabRoll;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	import flash.events.IEventDispatcher;
	
	import mx.collections.ArrayCollection;

	[Event(name="postComplete", type="com.photodispatcher.event.PrintEvent")]
	public class LabGeneric extends Lab implements IEventDispatcher{
		
		public static const STATE_ERROR:int=-1;
		public static const STATE_OFF:int=0;
		public static const STATE_ON:int=1;
		public static const STATE_SCHEDULED_ON:int=2;
		public static const STATE_SCHEDULED_OFF:int=3;
		public static const STATE_ON_WARN:int=4;
		public static const STATE_MANUAL:int=10;
		
		//papers
		public static const PAPER_DEFAULT_MATT:int=11;
		public static const PAPER_THERMO:int=36;
		public static const PAPER_CANVAS:int=37;
		
		
		public static const LABELS_STATE:Object = 
			{
				"-1": "STATE_ERROR",
				"0": "STATE_OFF",
				"1": "STATE_ON",
				"2": "STATE_SCHEDULED_ON",
				"3": "STATE_SCHEDULED_OFF",
				"4": "STATE_ON_WARN",
				"10": "STATE_MANUAL"
			};
		
		[Bindable]
		public var enabled:Boolean=true;//??????
		
		[Bindable]
		public var stateCaption:String;
		
		/**
		 * deprecated??
		 * никак не используется, нужно отвязать view?
		[Bindable]
		public var printQueue:PrintQueue;
		 */
		
		/**
		 * deprecated??
		 * используется для определения работает ли лаба по расписанию
		 * сейчас никак не используется, кроме индикации
		 */
		[Bindable]
		public var onlineState:int=STATE_OFF;

		//public var currentPG:PrintGroup;
		
		
		protected var printTasks:Array=[];
		
		protected var currentPrintTask:PrintTask;
		
		protected var _chanelMap:Object;
		
		public function LabGeneric(lab:Lab){
			super();
			lab.cloneTo(this);
			//printQueue=new PrintQueue(this);
		}

		public function orderFolderName(printGroup:PrintGroup):String{
			return printGroup?printGroup.id:'';
		}
		
		public function checkPrintGroupInLab(pg:PrintGroup):Boolean {
			
			var _id:String = pg.id;
			var _tasks:Array = currentPrintTask? printTasks.concat(currentPrintTask) : printTasks;
			return _tasks.some(function (item:PrintTask, index:int, array:Array):Boolean {
				return item.printGrp.id == _id;
			});
			
		}
		
		/*
		*постановка в печать
		*
		*/
		public function post(pg:PrintGroup, revers:Boolean):void{
			if(!pg) return;

			if (!canPrintInternal(pg)){
				pg.state=OrderState.ERR_PRINT_POST;
				dispatchErr(pg,'Группа печати '+pg.id+' не может быть распечатана в '+name+'.');
				return;
			}
			var pt:PrintTask= new PrintTask(pg,this, revers);
			printTasks.push(pt);
			//start post sequence
			stateCaption='Копирование';
			postNext();
		}
		
		public function hasInPostQueue(pgId:String):Boolean{
			if(!pgId) return false;
			if(!printTasks || printTasks.length==0) return false;
			var pt:PrintTask;
			for each (pt in printTasks){
				if (pt.printGrp.id==pgId) return true;
			}
			return false;
		}
		
		protected function dispatchErr(pg:PrintGroup, msg:String):void{
			StateLog.logByPGroup(pg.state, pg.id,'Ошибка размещения на печать: '+msg);
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
				currentPrintTask = pt;
				//StateLog.logByPGroup(OrderState.PRN_POST, pt.printGrp.id);
				pt.addEventListener(Event.COMPLETE,taskComplete);
				pt.post();
			}else{
				//complited
				stateCaption='Копирование завершено';
			}
		}
		
		public function taskComplete(e:Event):void{
			postRunning=false;
			currentPrintTask = null;
			var pt:PrintTask=e.target as PrintTask;
			if(pt){
				pt.removeEventListener(Event.COMPLETE,taskComplete);
				if (pt.hasErr){
					dispatchErr(pt.printGrp, pt.errMsg);
				}else{
					dispatchEvent(new PrintEvent(PrintEvent.POST_COMPLETE_EVENT,pt.printGrp));
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

		public function printChannel(printGroup:PrintGroup, rolls:Array = null):LabPrintCode {
			
			var cm:Object = rolls? channelMapByOnRolls(rolls) : chanelMap;
			
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
		
		public function profileFile(paper:int):String{
			if(!profiles || profiles.length==0) return null;
			var profile:LabProfile= ArrayUtil.searchItem('paper',paper, profiles.toArray()) as LabProfile;
			if(!profile) return null;
			return profile.path();
		}

		public function canPrint(printGroup:PrintGroup):Boolean{
			return canPrintInternal(printGroup);
		}

		protected function canPrintInternal(printGroup:PrintGroup):Boolean{
			var result:LabPrintCode=printChannel(printGroup);
			return result?true:false;
		}
		
		// Lazy loading chanels
		
		protected function get chanelMap():Object{
			if(!_chanelMap){
				var chanels:Array = LabPrintCode.getChanels(this.src_type);
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
		
		/**
		 * возвращает карту каналов по списку рулонов
		 */
		protected function channelMapByOnRolls(rolls:Array):Object {
			
			var chanels:Array = LabPrintCode.getChanels(this.src_type);
			
			if(chanels == null){
				return null;
			}
			
			var map:Object = new Object;
			
			for each (var code:LabPrintCode in chanels){
				if(code){
					
					if(checkCodeForRolls(code, rolls)){
						
						map[code.key(src_type)] = code;
						
					}
					
				}
			}
			
			return map;
		}
		
		/**
		 * проверяет, может ли канал печататься на любом из рулонов в списке
		 */
		protected function checkCodeForRolls(code:LabPrintCode, rolls:Array):Boolean {
			
			return rolls.some(
				function(item:LabRoll, index:int, array:Array):Boolean {
					return item.paper == code.paper && item.width == code.width;
				}
			);
			
		}
		
		/**
		 * возвращает массив LabDevice у которых есть подходящий рулон 
		 */
		public function getCompatiableDevices(pg:PrintGroup):Array {
			var result:Array = [];
			var dev:LabDevice;
			var code:LabPrintCode;
			if(devices){
				for each (dev in devices){
					//if(printChannel(pg, dev.rollsOnline.toArray())) result.push(dev);
					if(printChannel(pg, dev.rolls.toArray())) result.push(dev);
				}
			}
			return result;
		}

		/**
		 * возвращает массив LabDevice у которых подходящий рулон online 
		 */
		public function getOnLineRollDevices(pg:PrintGroup):Array {
			var result:Array = [];
			var dev:LabDevice;
			
			//var code:LabPrintCode;
			if(devices){
				for each (dev in devices){
					var add:Boolean=false;
					//check online rolls
					if(dev.rollsOnline && dev.rollsOnline.length>0){
						add=printChannel(pg, dev.rollsOnline.toArray())!=null;
					}
					//check by last roll
					if(!add) add=dev.lastRoll &&  printChannel(pg, [dev.lastRoll])!=null;
					if(add) result.push(dev);
				}
			}
			return result;
		}

		public function checkAliasPrintCompatiable(pg:PrintGroup):Boolean {
			//var res:Boolean;
			var alias:BookSynonym = pg.bookSynonym;
			if(alias) {
				var pgTemplate:BookPgTemplate = alias.getBookPgTemplateByPart(pg.book_part);
				if(pgTemplate && pgTemplate.lab_type == this.src_type) return true;
			}
			return false;
		}

		[Bindable]
		public var stops:ArrayCollection;
		
		public function resetStops():void{
			stops=new ArrayCollection();
		}
		
		protected var _postMeter:LabMeter;
		protected var devPrintMetersMap:Object={};
		protected var devStopMetersMap:Object={};
		
		[Bindable]
		public var currMetersAC:ArrayCollection;
		
		public function resetMeters():void{
			_postMeter=null;
			devPrintMetersMap={};
			devStopMetersMap={};
			currMetersAC=new ArrayCollection();
		}
		
		public function addMeter(meter:LabMeter):void{
			if(!meter) return;
			if (meter.meter_type==LabMeter.TYPE_POST){
				//post printgroup, no device - lab meter
				_postMeter=meter;
			}else if (meter.meter_type==LabMeter.TYPE_PRINT){
				//device print meter
				devPrintMetersMap[meter.lab_device]=meter;
			}else if (meter.meter_type==LabMeter.TYPE_STOP){
				//device stop meter
				devStopMetersMap[meter.lab_device]=meter;
			}
			currMetersAC.addItem(meter);
		}

		public function getPostMeter():LabMeter{
			return _postMeter;
		}

		public function getPrintMeter(deviceId:int):LabMeter{
			return devPrintMetersMap[deviceId] as LabMeter;
		}
		
		/*
		public function getDeviceMeter(deviceId:int):LabMeter{
			var meter:LabMeter=devPrintMetersMap[deviceId] as LabMeter;
			if(!meter) return _postMeter;
			if(_postMeter){
				return _postMeter.isNewer(meter)?_postMeter:meter;
			}
			return meter;
		}
		*/
		public function getDeviceStopMeter(deviceId:int):LabMeter{
			return devStopMetersMap[deviceId] as LabMeter;
		}
		
		
		/************************************ deprecated ************************************/
		
		/**
		 * deprecated
		 */
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
		
		/**
		 * deprecated
		 */
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
		
		/**
		 * deprecated
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
		
		/**
		 * deprecated
		 */
		public function setRollSpeed(roll:LabRoll):void{
			if(!roll || !devices) return;
			roll.speed=0;
			var dev:LabDevice;
			if(roll.lab_device){
				dev=ArrayUtil.searchItem('id',roll.lab_device,devices.toArray()) as LabDevice;
				if(dev) roll.speed=roll.width<203?dev.speed1:dev.speed2;
			}
			if(roll.speed==0){
				var speed:int=int.MAX_VALUE;
				//get min speed from all devices
				for each(dev in devices) speed=Math.min(speed,roll.width<203?dev.speed1:dev.speed2);
				if(speed!=int.MAX_VALUE) roll.speed=speed;
			}
		}
		
		/**
		 * deprecated ?
		 */
		public function refresh():void{
			refreshOnlineState();
			//TODO closed while not in use
			return;
			refreshPrintQueue();
		}
		
		/**
		 * deprecated ?
		 */
		public function refreshPrintQueue():void{
			// deprecated, не нужно
			// printQueue.refresh();	
		}
		
		/**
		 * deprecated
		 */
		public function refreshOnlineState():void{
			var dev:LabDevice;
			var newState:int=STATE_OFF;
			if(!is_managed || !devices){
				onlineState=STATE_MANUAL;
				return;
			}
			for each(dev in devices){
				if(dev){
					//check time table
					dev.checkTimeTable();
					newState=Math.max(newState,dev.onlineState);
					//check roll
				}
			}
			onlineState=newState;
		}
		
		
		
	}
}
