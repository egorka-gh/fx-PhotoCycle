package com.photodispatcher.model.dao{
	import com.photodispatcher.model.LabRoll;
	
	public class LabRollDAO extends BaseDAO{
		
		
		public function getByDevice(device:int, forEdit:Boolean=false, silent:Boolean=true):Array {
			var sql:String;
			if(!forEdit){
				sql='SELECT r.width, r.pixels, lr.lab_device, av.id paper, av.value paper_name,'+
						' lr.len_std, lr.len, lr.is_online, 1 is_used'+  
					' FROM config.roll r'+
					' INNER JOIN config.lab_rolls lr ON r.width=lr.width'+
					' INNER JOIN config.attr_value av ON lr.paper=av.id AND av.attr_tp=2'+
					' WHERE lr.lab_device=?'+
					' ORDER BY r.width';
			}else{
				sql='SELECT r.width, r.pixels, ? lab_device, av.id paper, av.value paper_name,'+
						' lr.len_std, lr.len, lr.is_online, ifnull(lr.width,0) is_used'+  
					' FROM config.roll r'+
					' INNER JOIN config.attr_value av ON av.attr_tp=2'+
					' LEFT OUTER JOIN config.lab_rolls lr ON lr.paper=av.id AND r.width=lr.width AND lr.lab_device=?'+
					' ORDER BY r.width';
			}
			runSelect(sql,[device, device],silent );
			return itemsArray ;
		}
		
		public function saveSequence(items:Array):Array{
			var sequence:Array=[];
			var item:LabRoll;
			var o:Object;
			var sql:String;
			var params:Array;
			if (!items) return [];
			for each(o in items){
				item= o as LabRoll;
				if(item){
					if(!item.is_used){
						//del
						sql='DELETE FROM config.lab_rolls WHERE lab_device=? AND width=? AND paper=?';
						params=[item.lab_device, item.width, item.paper];
						sequence.push(prepareStatement(sql,params));
					}else{
						//persist
						sql='UPDATE config.lab_rolls SET len_std=? WHERE lab_device=? AND width=? AND paper=?';
						params=[item.len_std, item.lab_device, item.width, item.paper];
						sequence.push(prepareStatement(sql,params));
						sql='INSERT OR IGNORE INTO config.lab_rolls(lab_device, width, paper, len_std) VALUES(?,?,?,?)';
						params=[item.lab_device, item.width, item.paper, item.len_std];
						sequence.push(prepareStatement(sql,params));
					}
				}
			}
			return sequence;
		}

		override protected function processRow(o:Object):Object{
			var a:LabRoll= new LabRoll();
			fillRow(o,a);
			return a;
		}
	}
}