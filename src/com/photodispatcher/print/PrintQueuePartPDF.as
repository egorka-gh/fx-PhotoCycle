package com.photodispatcher.print{
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.LabDevice;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrnQueue;
	import com.photodispatcher.model.mysql.services.PrnStrategyService;
	
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
			
			if(!isStarted()){
				//try to start queue
				if(printManager.getLabStartedQueue(lab.id)==null){
					//start prnQueue
					var svcs:PrnStrategyService=Tide.getInstance().getContext().byType(PrnStrategyService,true) as PrnStrategyService;
					var latch:DbLatch= new DbLatch();
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
			compliteFetch();
			return true;
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
		
	}
}