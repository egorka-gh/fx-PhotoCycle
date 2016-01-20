package com.photodispatcher.print{
	
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.model.mysql.entities.LabDevice;
	import com.photodispatcher.model.mysql.entities.LabMeter;
	import com.photodispatcher.model.mysql.entities.LabStopType;
	import com.photodispatcher.model.mysql.entities.LabTimetable;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.services.LabService;
	import com.photodispatcher.model.mysql.services.PrintGroupService;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	import flash.utils.getTimer;
	
	import org.granite.tide.Tide;

	[Event(name="complete", type="flash.events.Event")]
	public class PrintQueueKillllllll extends EventDispatcher{

		public static const STRATEGY_BY_CHANEL:int=1;
		public static const STRATEGY_BY_ALIAS:int=2;
		public static const REFRESH_INTERVAL:int=5*60*1000; //mksek
		
		
		
		private var  strategy:int=STRATEGY_BY_ALIAS;
		
		[Bindable]
		public var queueLimit:int=100;
		
		protected var printManager:PrintQueueManager;

		//print groups ordered by state date & current strategy
		protected var queue:Array;
		protected var pgFetched:Array; // :PrintGroup;

		private var refreshInterval:int=REFRESH_INTERVAL;
		private var lastRefresh:int;
		

		public function PrintQueueKillllllll(printManager:PrintQueueManager){
			super();
			this.printManager=printManager;
			queue=[];
		}
		
		public function fetch():void{
			pgFetched=[];
			//need refresh?
			if(lastRefresh==0 || (getTimer()-lastRefresh)>refreshInterval){
				refresh();
			}else{
				fetchInternal();
			}
		}

		protected function refresh():void{
			//load main queue
			var latch:DbLatch=new DbLatch();
			latch.addEventListener(Event.COMPLETE, onRefresh);
			// получаем список в статусе 200, готовые к печати
			//latch.addLatch(printGroupService.loadReady4Print(queueLimit, true));
			//all types
			latch.addLatch(printGroupService.loadReady4Print(queueLimit, false));
			latch.start();
		}
		
		private function onRefresh(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE, onRefresh);
				if(!latch.complite) return;
				//TODO some sync?
				queue=latch.lastDataArr;
				syncQueue();
			}
			fetchInternal();
		}
		
		private function syncQueue():void{
			if(!queue || queue.length==0) return;
			var idx:int;
			var pg:PrintGroup;
			for each(pg in pgFetched){
				if(pg){
					idx=ArrayUtil.searchItemIdx('id',pg.id,queue);
					//remove from queue
					if(idx>-1) queue.splice(idx,1);
				}
			}
		}
		
		
		protected function fetchInternal():void{
			var readyDevices:Array = printManager.getPrintReadyDevices();
			if(!readyDevices || readyDevices.length==0) return;
			var devCandidat:LabDevice;
			
			var pg:PrintGroup;
			var dev:LabDevice;
			for each (pg in queue){
				if(printManager.isInWebQueue(pg)) continue;
				dev=chooseDevice(pg,readyDevices);
				if(dev){
					//found 
					pgFetched.push(pg);
					if(dev.compatiableQueue.length>=2){ //TODO dumy check limit 1 (max 2 ) post per fetch
						//device full
						//remove device
						var idx:int=ArrayUtil.searchItemIdx('id',dev.id,readyDevices);
						if(idx>-1) readyDevices.splice(idx,1);
					}else{
						//4 chooseDevice
						dev.compatiableQueue.push(pg);
						dev.lastPostDate=new Date();
					}
				}
				if(readyDevices.length==0) break;
			}

			if(pgFetched.length>0){
				//has some
				//remove from queue
				syncQueue();
			}
			//call print manager
			dispatchEvent(new Event(Event.COMPLETE));
			
			/*
			if(readyDevices.length>0){
				//TODO get pgs by devices
			}
			*/
		}
		
		protected function chooseDevice(pg:PrintGroup, devices:Array):LabDevice{
			if(!pg || !devices || devices.length==0) return null;
			var setA:Array=[];
			var setB:Array=[];
			var dev:LabDevice;
			var lab:LabGeneric;
			var result:LabDevice;
			
			//can print set
			for each(dev in devices){
				lab = printManager.labMap[dev.lab] as LabGeneric;
				if(lab && lab.canPrint(pg)) setA.push(dev);
			}
			if(setA.length==0) return null;
			
			/*
			//has online rool set
			for each(dev in setA){
				if(dev.rollsOnline && dev.rollsOnline.length>0){
					lab = printManager.labMap[dev.lab] as LabGeneric;
					if(lab && lab.printChannel(pg,dev.rollsOnline)) setB.push(dev);
					
				}
			}
			if(setB.length>0){
				setA=setB;
				setB=[];
			}else{
				return null;
			}
			*/
			
			if(pg.book_type==0){
				//PHOTO print
				for each(dev in setA){
					lab = printManager.labMap[dev.lab] as LabGeneric;
					//TODO hardcoded SourceType.LAB_FUJI for photo
					if(lab && lab.src_type==SourceType.LAB_FUJI) setB.push(dev);
				}
				if(setB.length>0){
					setA=setB;
					setB=[];//??
				}else{
					return null;
				}
			}else if(strategy==STRATEGY_BY_ALIAS){
				//by alias set
				for each(dev in setA){
					lab = printManager.labMap[dev.lab] as LabGeneric;
					if(lab && lab.checkAliasPrintCompatiable(pg)) setB.push(dev);
				}
				if(setB.length>0){
					setA=setB;
					setB=[];//??
				}else{
					return null;
				}
			}

			if(setA.length==1){
				result= setA[0] as LabDevice; 
			}else{
				//coose by dev Queue or last post
				for each(dev in setA){
					if(!result){
						result=dev;
					}else{
						if(result.compatiableQueue > dev.compatiableQueue){
							result=dev;
						}else if(result.compatiableQueue == dev.compatiableQueue && result.lastPostDate){
							if((dev.lastPostDate==null) || (dev.lastPostDate.time < result.lastPostDate.time)) result=dev;
						}
					}
				}
			}
			if(result){
				//set destination lab
				lab = printManager.labMap[result.lab] as LabGeneric;
				pg.destinationLab=lab;
			}
			return result;
		}

		/*
		protected function checkWebReady(printGroups:Array):void {
			
			if(!printGroups || printGroups.length == 0) return;
			
			var webTask:PrintQueueWebTask = new PrintQueueWebTask(printGroups);
			webTask.addEventListener(Event.COMPLETE, onWebCheck);
			webTask.execute();
		}

		protected function onWebCheck(event:Event):void{
			pgFetched=null;
			var webTask:PrintQueueWebTask= event.target as PrintQueueWebTask;
			if(!webTask) return;
			webTask.removeEventListener(Event.COMPLETE, onWebCheck);
			var webReady:Array = webTask.getItemsReady();
			if(webReady && webReady.length>0){
				var pg:PrintGroup=webReady[0] as PrintGroup;
				if(pg && pgCandidat &&  pg.id==pgCandidat.id){
					pgFetched=pgCandidat;
					// нужно поставить корректный статус для очереди, при веб проверке может меняться ??
					pgFetched.state = OrderState.PRN_QUEUE;
				}
			}
			pgCandidat=null;
			
			if(pgFetched){
				
				dispatchEvent(new Event(Event.COMPLETE));
			}
		}
		*/
		
		public function getFetched():Array{
			if(!pgFetched) return [];
			var ret:Array=pgFetched.concat();
			pgFetched=[];
			return ret;
		}

		
		private var _labService:LabService;
		protected function get labService():LabService{
			if(!_labService) _labService=Tide.getInstance().getContext().byType(LabService,true) as LabService;
			return _labService;
		}
		private var _printGroupService:PrintGroupService;
		protected function get printGroupService():PrintGroupService{
			if(!_printGroupService) _printGroupService=Tide.getInstance().getContext().byType(PrintGroupService,true) as PrintGroupService;
			return _printGroupService;
		}

	}
}