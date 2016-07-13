package com.photodispatcher.print{
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.LabDevice;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrnQueue;
	import com.photodispatcher.model.mysql.services.PrnStrategyService;
	import com.photodispatcher.provider.preprocess.QueueMarkTask;
	
	import flash.events.Event;
	
	import mx.controls.Alert;
	
	import org.granite.tide.Tide;
	
	public class PrintQueuePartPDF extends PrintQueueGeneric{
		
		
		public function PrintQueuePartPDF(printManager:PrintQueueManager, prnQueue:PrnQueue){
			super(printManager, prnQueue);
			canLockLab=true;
			canLockPG=true;
		}
		
		override public function fetch():Boolean{
			if(!super.fetch()) return false;
			if(!isActive()){
				compliteFetch();
				return false;
			}
			var dev:LabDevice;
			var readyDevices:Array = printManager.getPrintReadyDevices(true,2);
			if(!readyDevices || readyDevices.length==0){
				compliteFetch();
				return false;
			}

			////check lab type by alias ???
			
			//get next print group
			var pgCandidat:PrintGroup=nextPG();
			
			if(!pgCandidat){
				if(isComplited()) prnQueue.is_active=false;
				compliteFetch();
				return false;
			}

			// check if lab is assigned
			var lab:LabGeneric;
			if(prnQueue.lab==0){
				for each(dev in readyDevices){
					lab = printManager.getLab(dev.lab);
					if(lab && !printManager.isLabLocked(lab.id) && lab.canPrint(pgCandidat) && lab.checkAliasPrintCompatiable(pgCandidat)){
						prnQueue.lab=lab.id;
						break;
					}else{
						lab=null;
					}
				}
				/*
				if(lab){
					//start prnQueue
					var svcs:PrnStrategyService=Tide.getInstance().getContext().byType(PrnStrategyService,true) as PrnStrategyService;
					var latch:DbLatch= new DbLatch();
					latch.addLatch(svcs.startQueue(prnQueue.id, prnQueue.sub_queue, lab.id));
					latch.start();
					prnQueue.started=new Date();
				}
				*/
			}else{
				for each(dev in readyDevices){
					if(dev.lab==prnQueue.lab){
						lab = printManager.getLab(dev.lab);
						break;
					}
				}
			}

			if(!lab){
				compliteFetch();
				return false;
			}
			
			var isStarting:Boolean;
			if(!isStarted()){
				//try to start queue
				if(printManager.getLabStartedQueue(lab.id)==null){
					//start prnQueue
					isStarting=true;
					var svcs:PrnStrategyService=Tide.getInstance().getContext().byType(PrnStrategyService,true) as PrnStrategyService;
					var latch:DbLatch= new DbLatch();
					latch.addEventListener(Event.COMPLETE,onstartQueue);
					latch.addLatch(svcs.startQueue(prnQueue.id, prnQueue.sub_queue, lab.id));
					latch.start();
					prnQueue.started=new Date();
				}else{
					//can't start
					compliteFetch();
					return false;
				}
			}
			//started queue - proceed
			
			//TODO complite or proceed???
			/*
			while(pgCandidat!=null && printManager.isInWebQueue(pgCandidat)){
				pgCandidat=nextPG();
			}
			*/
			if(pgCandidat!=null && printManager.isInWebQueue(pgCandidat)){
				compliteFetch();
				return true;
			}

			while(pgCandidat!=null && !lab.canPrint(pgCandidat)){
				pgCandidat.state=OrderState.ERR_PRINT_POST;
				pgCandidat=nextPG();
			}
			
			if(pgCandidat){
				pgCandidat.destinationLab=lab;
				pgFetched.push(pgCandidat);
			}
			if(!isStarting) compliteFetch();
			return true;
		}
		
		private function onstartQueue(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(!latch) return;
			latch.removeEventListener(Event.COMPLETE,onstartQueue);
			if(latch.complite){
				markQueue();
			}else{
				prnQueue.started=null;
				//reset fetch
				pgFetched=[];
				compliteFetch();
			}
		}

		protected function nextPG():PrintGroup{
			var pgCandidat:PrintGroup;
			if(queue){
				for each(var pg:PrintGroup in queue){
					if(pg.state==OrderState.PRN_WAITE){
						pgCandidat=pg;
						break;
					}
					//reset errs ?? 4 next itteration
					if(pg.state<0) pg.state=OrderState.PRN_WAITE;
				}
			}
			return pgCandidat;
		}

		private function markQueue():void{
			var svc:PrnStrategyService=Tide.getInstance().getContext().byType(PrnStrategyService,true) as PrnStrategyService;
			var latch:DbLatch=new DbLatch();
			latch.addEventListener(Event.COMPLETE,onLoadMark);
			latch.addLatch(svc.getQueueMarkPGs(prnQueue.id));
			latch.start();
		}

		private function onLoadMark(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onLoadMark);
				if(latch.complite && latch.lastDataArr.length>0){
					//mark queue
					var pgStart:PrintGroup=latch.lastDataArr[0] as PrintGroup;
					var pgEnd:PrintGroup;
					if(latch.lastDataArr.length>1) pgEnd=latch.lastDataArr[1] as PrintGroup;
					var qmTask:QueueMarkTask= new QueueMarkTask(pgStart, pgEnd);
					qmTask.addEventListener(Event.COMPLETE, onqmTask);
					qmTask.run();
				}else if(isFetching){
					//reset fetch
					pgFetched=[];
					compliteFetch();
				}
			}
		}
		private function onqmTask(evt:Event):void{
			var qmTask:QueueMarkTask=evt.target as QueueMarkTask;
			if(qmTask){
				qmTask.removeEventListener(Event.COMPLETE, onqmTask);
				if(qmTask.hasError){
					Alert.show('Ошибка маркировки партии '+qmTask.error);
				}
			}
			if(isFetching) compliteFetch();
		}

		
	}
}