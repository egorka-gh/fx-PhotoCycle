package com.photodispatcher.model.dao{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.OrderState;
	
	import mx.collections.ArrayCollection;
	
	public class OrderStateDAO extends BaseDAO{
		
		private static var stateMap:Object;
		
		public static function getStateName(id:int):String{
			var os:OrderState;
			if(!stateMap) initStateMap();
			if(stateMap) os=stateMap[id.toString()] as OrderState;
			return os?os.name:'';
		}

		public static function getStateArray(from:int=-1, to:int=-1, excludeRuntime:Boolean=false):Array{
			var result:Array=[];
			if(from==-1) from=int.MIN_VALUE;
			if(to==-1) to=int.MAX_VALUE;
			if(!stateMap) initStateMap();
			if(stateMap){
				var os:OrderState;
				for (var key:Object in stateMap){
					os=stateMap[key] as OrderState;
					if(os && os.id>=from && os.id<to && (!excludeRuntime || os.runtime==0)) result.push(os);
				}
			}
			result.sortOn('id',Array.NUMERIC);
			return result;
		}
		
		public static function getStateList():ArrayCollection{
			var result:ArrayCollection=new ArrayCollection();
			if(!stateMap) initStateMap();
			if(stateMap){
				var os:OrderState;
				for (var key:Object in stateMap){
					os=stateMap[key] as OrderState;
					if(os) result.addItem(os);
				}
			}
			return result;
		}
		
		public static function initStateMap():void{
			var dao:OrderStateDAO=new OrderStateDAO();
			if(dao.runSelect('SELECT * FROM config.order_state ORDER BY id')){
				var a:Array=dao.itemsArray;
				if(!a) return;
				stateMap=new Object();
				for each(var o:Object in a){
					var s:OrderState= o as OrderState;
					if(s){
						stateMap[s.id.toString()]=s;
					}
				}
			}
		}
		
		/*
		public function getOrderStateByPrintGroups(order_id:String, silent:Boolean=false):OrderState{
			var sql:String='SELECT ifnull(min(pg.state),0) id FROM print_group pg WHERE pg.order_id = ?';
			runSelect(sql, [order_id],silent);
			return item as OrderState;
		}
		*/
		
		override protected function processRow(o:Object):Object{
			var a:OrderState = new OrderState();
			a.id=o.id;
			a.name=o.name;
			a.runtime=o.runtime;
			a.extra=o.extra;
				
			a.loaded = true;
			return a;
		}

	}
}