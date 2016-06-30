package com.photodispatcher.print{
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.LabDevice;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrnQueue;
	import com.photodispatcher.model.mysql.entities.PrnStrategy;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.services.LabService;
	import com.photodispatcher.model.mysql.services.PrintGroupService;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	import flash.utils.getTimer;
	
	import mx.collections.ISort;
	
	import org.granite.tide.Tide;
	
	import spark.collections.Sort;
	import spark.collections.SortField;
	
	public class PrintQueuePusher extends PrintQueueGeneric{
		public static const STRATEGY_BY_CHANEL:int=1;
		public static const STRATEGY_BY_ALIAS:int=2;
		public static const REFRESH_INTERVAL:int=5*60*1000; //mksek
		
		/*
		private var _strategy:PrnStrategy;
		public function set strategy(value:PrnStrategy):void{
			if(!value || value.strategy_type!=PrnStrategy.STRATEGY_PUSHER) return; 
			_strategy = value;
			if(prnQueue && _strategy){
				prnQueue.is_active=_strategy.is_active;
				prnQueue.strategy_type=_strategy.strategy_type;
				prnQueue.strategy_type_name=_strategy.strategy_type_name;
			}
		}
		*/
		
		private var  strategyInternal:int=STRATEGY_BY_ALIAS;
		private var queueLimit:int=1000;
		private var refreshInterval:int=REFRESH_INTERVAL;
		private var lastRefresh:int;

		public function PrintQueuePusher(printManager:PrintQueueManager, prnQueue:PrnQueue){
			prnQueue= new PrnQueue();
			prnQueue.label='пихалка';
			prnQueue.strategy=PrnStrategy.STRATEGY_PUSHER;
			prnQueue.created=new Date();
			//prnQueue.started=new Date();
			super(printManager, prnQueue);
		}
		
		/*
		override public function isActive():Boolean{
			return _strategy && _strategy.is_active;
		}
		*/
		
		override public function fetch():Boolean{
			if(!super.fetch()) return false;
			if(!isActive()){
				compliteFetch();
				return false;
			}
			
			refresh();
			/*
			if(lastRefresh==0 || (getTimer()-lastRefresh)>refreshInterval){
				refresh();
			}else{
				fetchInternal();
			}
			*/
			return true;
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
				if(!latch.complite){
					compliteFetch();
					return;
				}
				//TODO some sync?
				queue=latch.lastDataAC;
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
					idx=ArrayUtil.searchItemIdx('id',pg.id,queue.source);
					//remove from queue
					if(idx>-1) queue.removeItemAt(idx);
				}
			}
			//order like pdf queue
			var sort:ISort = new Sort();
			sort.fields = [new SortField("alias",false), new SortField("sheet_num",false,true), new SortField("book_part",false,true)];
			queue.sort=sort;
			queue.refresh();
		}

		protected function fetchInternal():void{
			var devs:Array = printManager.getPrintReadyDevices();
			if(!devs || devs.length==0){
				compliteFetch();
				return;
			}

			var devCandidat:LabDevice;
			var pg:PrintGroup;
			var dev:LabDevice;
			var lab:LabGeneric;
			var readyDevices:Array = [];
			for each(dev in devs){
				lab = printManager.getLab(dev.lab);
				if(lab && lab.pusher_enabled && !printManager.isLabLocked(dev.lab)){
					readyDevices.push(dev);
				}
			}
			if(!readyDevices || readyDevices.length==0){
				compliteFetch();
				return;
			}
			
			for each (pg in queue){
				if(printManager.isInWebQueue(pg)) continue;
				if(printManager.isPgLocked(pg.id, prnQueue.priority)) continue;
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
			compliteFetch();
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
				lab = printManager.getLab(dev.lab);
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
					lab = printManager.getLab(dev.lab);
					//TODO hardcoded SourceType.LAB_FUJI for photo
					if(lab && (lab.src_type==SourceType.LAB_FUJI || (lab.src_type==SourceType.LAB_NORITSU && pg.paper==LabGeneric.PAPER_METALIC))) setB.push(dev);
				}
				if(setB.length>0){
					setA=setB;
					setB=[];//??
				}else{
					return null;
				}
			}else if(strategyInternal==STRATEGY_BY_ALIAS){
				//by alias set
				for each(dev in setA){
					lab = printManager.getLab(dev.lab);
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
				lab = printManager.getLab(result.lab);
				pg.destinationLab=lab;
			}
			return result;
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