package com.photodispatcher.print{
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrnQueue;
	import com.photodispatcher.model.mysql.entities.PrnStrategy;
	import com.photodispatcher.util.ArrayUtil;
	import com.photodispatcher.util.GridUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.globalization.DateTimeStyle;
	
	import mx.collections.ArrayCollection;
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;
	import spark.formatters.DateTimeFormatter;
	
	[Event(name="complete", type="flash.events.Event")]
	public class PrintQueueGeneric extends EventDispatcher{
		
		public static function gridColumns():ArrayList{
			var result:Array= [];
			var col:GridColumn;
			
			col= new GridColumn('prnQueue.strategy_type_name'); col.headerText='Стратегия'; result.push(col);
			col= new GridColumn('prnQueue.label'); col.headerText='Наименование'; result.push(col);
			col= new GridColumn('prnQueue.sub_queue'); col.headerText='№'; col.width=50; result.push(col);
//			col= new GridColumn('prnQueue.is_active'); col.headerText='Активна'; col.width=50; col.labelFunction=GridUtil.booleanToLabel; result.push(col);
			col= new GridColumn('prnQueue.is_active'); col.headerText='Активна'; col.width=50; result.push(col);
			col= new GridColumn('prnQueue.priority'); col.headerText='Приоритет'; col.width=50; result.push(col);
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT;
			col= new GridColumn('prnQueue.created'); col.headerText='Создана'; col.formatter=fmt;  col.width=100; result.push(col);
			col= new GridColumn('prnQueue.started'); col.headerText='Старт'; col.formatter=fmt;  col.width=100; result.push(col);
			col= new GridColumn('prnQueue.lab_name'); col.headerText='Лаба'; result.push(col);

			return new ArrayList(result);
		}

		
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

		public function isStarted():Boolean{
			return isActive() && prnQueue.started!=null;
		}

		/*
		* 
		*очередь не контролирует длинну очереди девайса на печать
		*/
		public function isPusher():Boolean{
			return prnQueue.strategy_type==PrnStrategy.STRATEGY_PUSHER;
		}

		public function isPgLocked(pgId:String):Boolean{
			if(!canLockPG || !pgId || !queue) return false;
			var idx:int=ArrayUtil.searchItemIdx('id',pgId,queue.source);
			return idx!=-1;
		}

		public function fetch():Boolean{
			if(isFetching){
				return false;
			}
			pgFetched=[];
			isFetching=true;
			//TODO implement im child class fetchig and call compliteFetch
			//Generic will hang on fetching 
			return true;
		}

		protected function isComplited():Boolean{
			if(!queue) return true;
			for each(var pg:PrintGroup in queue){
				if(pg.state<OrderState.PRN_PRINT){
					return false;
				}
			}
			return true;
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

		public function hasWaitingPG():Boolean{
			if(queue){
				for each(var pg:PrintGroup in queue){
					if(pg.state==OrderState.PRN_WAITE || pg.state<0){
						return true;
					}
				}
			}
			return false;
		}

	}
}