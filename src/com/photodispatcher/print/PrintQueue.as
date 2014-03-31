package com.photodispatcher.print{
	import com.photodispatcher.model.LabPrintCode;
	import com.photodispatcher.model.LabRoll;
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.dao.LabRollDAO;
	import com.photodispatcher.model.dao.PrintGroupDAO;
	
	import flash.events.TimerEvent;
	import flash.utils.Timer;

	public class PrintQueue{
		private static const READ_DELAY_MIN:int=400;
		private static const READ_DELAY_MAX:int=1000;
		private static const READ_MAX_WAITE:int=30000;


		[Bindable]
		public var printQueueLen:int=-1;//sek
		[Bindable]
		public var printQueueLimit:int;//sek

		public var queueOrders:int;
		public var queuePGs:int;
		public var queuePrints:int;

		[Bindable]
		public var printQueueLenM:int=0;//metre

		[Bindable]
		public  var rolls:Array=[];
		
		private var printGroups:Array=[];

		private var lab:LabBase;
		
		public function PrintQueue(lab:LabBase){
			this.lab=lab;
		}

		public function refreshOnlineRolls():void{
			var roll:LabRoll;
			var temp:LabRoll;
			for each(roll in rolls){
				temp=lab.getOnlineRoll(roll.paper, roll.width);
				if(roll.is_online){
					if(!temp){
						roll.is_online=false;
						roll.lab_device=0;
						roll.len=0;
						lab.setRollSpeed(roll);
					}
				}else{
					if(temp){
						roll.is_online=temp.is_online;
						roll.lab_device=temp.lab_device;
						roll.len=temp.len;
						lab.setRollSpeed(roll);
					}
				}
			}
			recalc();
		}

		public function refresh():void{
			if(isReading) return;
			_refresh();
		}
		private function _refresh():void{
			if(!lab) return;
			//read print groups in Print state
			var ordersMap:Object=new Object();
			var pgDao:PrintGroupDAO= new PrintGroupDAO();
			var pgs:Array=pgDao.findInPrint(lab.id);
			if(!pgs){
				//read lock
				refreshLate();
				return;
			}
			//read complited
			queueOrders=0;
			queuePGs=0;
			queuePrints=0;
			isReading= false;
			printGroups=pgs;
			queuePGs=printGroups.length;
			var newRolls:Array;
			var pg:PrintGroup;
			var roll:LabRoll;
			var channel:LabPrintCode;
			var rMap:Object= new Object();
			var height:int;
			//add online rolls
			newRolls=lab.getOnlineRolls();
			for each(roll in newRolls){
				lab.setRollSpeed(roll);
				rMap[roll.width.toString()+'~'+roll.paper.toString()]=roll;
			}
			//fill rolls queue
			for each(pg in pgs){
				ordersMap[pg.order_id]=pg.order_id;
				channel=lab.printChannel(pg);
				//TODO more then 1 online rolls vs same width/papper?????? 
				if(channel){
					roll=rMap[channel.roll.toString()+'~'+channel.paper.toString()] as LabRoll;
					if(!roll){
						roll=new LabRoll();
						roll.paper=pg.paper;
						roll.paper_name=pg.paper_name;
						roll.width=channel.roll;
						lab.setRollSpeed(roll);
						rMap[channel.roll.toString()+'~'+channel.paper.toString()]=roll;
					}
					height=pg.width==channel.width?pg.height:pg.width;
					queuePrints+=(pg.prints-pg.prints_done);
					roll.printQueueLen+=height*(pg.prints-pg.prints_done);
					roll.printGroups.push(pg);
				}
			}
			var key:String;
			for (key in ordersMap) queueOrders++;
			newRolls=[];
			for each(roll in rMap){
				if(roll){
					if(roll.is_online){
						newRolls.unshift(roll);
					}else{
						newRolls.push(roll);
					}
				}
			}
			rolls=newRolls;
			recalc();
		}
		
		private function recalc():void{
			//TODO dumy calc if dev >1
			var devs:Array=lab.getOnlineDevices();
			var streems:int=1;
			if(devs.length>1) streems=devs.length;
			if(rolls.length==0){
				printQueueLen=-1;
				printQueueLenM=0;
				return;
			}
			var roll:LabRoll;
			var result:int=0;
			var resultM:int=0;
			//calc rolls time
			for each(roll in rolls){
				if(roll.speed==0){
					roll.printQueueTime=-1;
				}else{
					roll.printQueueTime=roll.printQueueLen/roll.speed;
				}
			}
			//serial print
			for each(roll in rolls){
				if(roll.printQueueTime>0) result+=roll.printQueueTime;
				resultM+=roll.printQueueLen;
			}
			if(streems>1){
				//parallel
				//dumy calc
				result=Math.round(result/(Number(streems)-0.5));
			}
			printQueueLen=result;
			printQueueLenM=Math.round(resultM/1000);
		}
		
		private var isReading:Boolean=false;
		private var readDelay:int=0;
		private var timer:Timer;
		private var readAttempt:int=0;
		
		private function getDelay():int{
			var timeout:int=0;
			while (timeout<READ_DELAY_MIN){
				timeout=Math.random()*(READ_DELAY_MAX+READ_DELAY_MIN*readAttempt);
			}
			return timeout;
		}

		private function refreshLate():void{
			if(!isReading){
				isReading= true;
				readDelay=0;
				readAttempt=0;
			}
			if (readDelay>=READ_MAX_WAITE){
				//max wait reached
				//clean up
				isReading= false;
				readDelay=0;
				readAttempt=0;
				return;
			}

			if(!timer){
				timer=new Timer(getDelay(),1);
			}else{
				timer.reset();
				timer.delay=getDelay();
			}
			timer.addEventListener(TimerEvent.TIMER,onTimer);
			readDelay+=timer.delay;
			readAttempt++;
			timer.start();
		}

		private function onTimer(e:TimerEvent):void{
			timer.removeEventListener(TimerEvent.TIMER,onTimer);
			_refresh();
		}

	}
}