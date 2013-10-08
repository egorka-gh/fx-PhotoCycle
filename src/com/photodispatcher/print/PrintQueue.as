package com.photodispatcher.print{
	import com.photodispatcher.model.LabPrintCode;
	import com.photodispatcher.model.LabRoll;
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.dao.LabRollDAO;
	import com.photodispatcher.model.dao.PrintGroupDAO;

	public class PrintQueue{

		[Bindable]
		public var printQueueLen:int=-1;//sek
		[Bindable]
		public var printQueueLimit:int;//sek
		
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
			if(!lab) return;
			//TODO inplement refresh late on read lock
			//read print groups in Print state
			var pgDao:PrintGroupDAO= new PrintGroupDAO();
			var pgs:Array=pgDao.findInPrint(lab.id);
			if(!pgs) return;//read lock
			printGroups=pgs; 
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
			//fuill rolls queue
			for each(pg in pgs){
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
					roll.printQueueLen+=height*(pg.prints-pg.prints_done);
				}
			}
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
				return;
			}
			var roll:LabRoll;
			var result:int=0;
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
			}
			if(streems>1){
				//parallel
				//dumy calc
				result=Math.round(result/(Number(streems)-0.5));
			}
			printQueueLen=result;
		}
	}
}