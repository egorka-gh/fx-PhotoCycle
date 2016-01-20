package com.photodispatcher.print{
	import com.photodispatcher.model.mysql.entities.PrnQueue;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	import mx.collections.ArrayCollection;
	
	[Event(name="complete", type="flash.events.Event")]
	public class PrintQueueGeneric extends EventDispatcher{
		
		//print groups ordered by state date, or ordered within the meaning of current strategy
		[Bindable]
		public var queue:ArrayCollection;
		[Bindable]
		public var prnQueue:PrnQueue;

		protected var printManager:PrintQueueManager;
		protected var isFetching:Boolean;
		protected var pgFetched:Array; // :PrintGroup;
		protected var canLockLab:Boolean;
		protected var canLockPG:Boolean;

		public function PrintQueueGeneric(printManager:PrintQueueManager, prnQueue:PrnQueue){
			super(null);
			this.printManager=printManager;
			this.prnQueue=prnQueue;
			if(prnQueue) queue=prnQueue.printGroups as ArrayCollection;
		}

		public function isActive():Boolean{
			return prnQueue && prnQueue.is_active;
		}
		
		public function get caption():String{
			var res:String="";
			if(prnQueue){
				res=prnQueue.strategy_type_name;
				if(prnQueue.label) res=res+':'+prnQueue.label;
			}
			return res;
		}

		public function isLabLocked(lab:int):Boolean{
			return isActive() && canLockLab && lab!=0 && prnQueue.lab!=0 && prnQueue.lab==lab;
		}

		public function isPgLocked(pgId:String):Boolean{
			if(!canLockPG || !pgId || !queue) return false;
			var idx:int=ArrayUtil.searchItemIdx('id',pgId,queue.source);
			return idx!=-1;
		}

		public function fetch():Boolean{
			pgFetched=[];
			if(isFetching){
				compliteFetch();
				return false;
			}
			//TODO implement im child class fetchig and call compliteFetch
			isFetching=true;
			return isFetching;
		}
		
		protected function compliteFetch():void{
			isFetching=false;
			//call print manager
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		public function getFetched():Array{
			if(!pgFetched) return [];
			var ret:Array=pgFetched.concat();
			pgFetched=[];
			return ret;
		}

	}
}