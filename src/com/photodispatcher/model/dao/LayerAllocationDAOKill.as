package com.photodispatcher.model.dao{
	import com.photodispatcher.model.LayerAllocation;

	public class LayerAllocationDAOKill extends BaseDAO{

		public function getBySet(layerset:int, forEdit:Boolean, silent:Boolean=false):Array {
			var sql:String;
			var param:Array;
			if (forEdit){
				sql="SELECT ? layerset, lt.id tray, IFNULL(la.layer,0) layer, l.name layer_name"+
					" FROM config.layer_tray lt"+
					" LEFT OUTER JOIN config.layer_allocation la ON  la.tray=lt.id and la.layerset=?"+
					" LEFT OUTER JOIN config.layer l ON l.id=IFNULL(la.layer,0)"+
					" ORDER BY lt.id";
				param=[layerset,layerset];
			}else{
				sql="SELECT la.layerset, la.tray, la.layer, l.name layer_name"+
					" FROM config.layer_allocation la"+ 
						" INNER JOIN config.layer l ON l.id=la.layer"+
					" WHERE la.layerset=? AND la.layer!=0"+
					" ORDER BY la.tray";
				param=[layerset];
			}
			runSelect(sql,param,silent );
			return itemsArray ;
		}
		
		public function updateBatch(items:Array):void{
			if(!items || items.length==0) return;
			var sequence:Array=saveSequence(items);
			executeSequence(sequence);
		}
		
		public function saveSequence(items:Array):Array{
			var sequence:Array=[];
			var item:LayerAllocation;
			var o:Object;
			var sql:String;
			var params:Array;
			if (!items) return [];
			for each(o in items){
				item= o as LayerAllocation;
				if(item){
					if(item.layer==0){
						//del
						sql='DELETE FROM config.layer_allocation WHERE layerset=? AND tray=?';
						params=[item.layerset, item.tray];
						sequence.push(prepareStatement(sql,params));
					}else{
						//persist
						sql='UPDATE config.layer_allocation SET layer=? WHERE layerset=? AND tray=?';
						params=[item.layer, item.layerset, item.tray];
						sequence.push(prepareStatement(sql,params));
						sql='INSERT OR IGNORE INTO config.layer_allocation(layerset, tray, layer) VALUES(?,?,?)';
						params=[item.layerset, item.tray, item.layer];
						sequence.push(prepareStatement(sql,params));
					}
				}
			}
			return sequence;
		}

		override protected function processRow(o:Object):Object{
			var a:LayerAllocation= new LayerAllocation();
			fillRow(o,a);
			return a;
		}
	}
}