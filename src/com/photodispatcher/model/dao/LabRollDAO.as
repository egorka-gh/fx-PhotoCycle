package com.photodispatcher.model.dao{
	import com.photodispatcher.model.LabRoll;
	
	public class LabRollDAO extends BaseDAO{

		/*
		public function getByLab(lab:int, silent:Boolean=true):Array {
			var sql:String;
			sql='SELECT r.width, r.pixels, lr.lab_device, av.id paper, av.value paper_name,'+
				' lr.len_std, lr.len, lr.is_online, 1 is_used'+  
				' FROM config.roll r'+
				' INNER JOIN config.lab_rolls lr ON r.width=lr.width'+
				' INNER JOIN config.attr_value av ON lr.paper=av.id AND av.attr_tp=2'+
				' INNER JOIN config.lab_device ld ON lr.lab_device=ld.id'+
				' WHERE ld.lab=?'+
				' ORDER BY r.width';
			runSelect(sql,[lab],silent );
			return itemsArray ;
		}
		*/
		
		public function getByDevice(device:int, forEdit:Boolean=false, silent:Boolean=true):Array {
			var sql:String;
			if(!forEdit){
				sql='SELECT r.width, r.pixels, ? lab_device, av.id paper, av.value paper_name,'+
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
		
		public function fillByChannels(device:int):void{
			var sql:String='INSERT INTO config.lab_rolls (lab_device, width, paper)'+
							' SELECT d.id, lr.roll, lr.paper'+
							' FROM config.lab_device d'+
							' INNER JOIN config.lab l ON d.lab=l.id'+
							' INNER JOIN (SELECT DISTINCT lpc.src_type, lpc.roll, lpc.paper FROM config.lab_print_code lpc'+ 
							                  ' WHERE lpc.roll IS NOT NULL AND lpc.roll!=0) lr ON lr.src_type=l.src_type'+                   
							' WHERE d.id=? AND NOT EXISTS(SELECT 1 FROM config.lab_rolls dr WHERE dr.lab_device=d.id AND dr.width=lr.roll AND dr.paper=lr.paper)';
			execute(sql,[device]);
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

		public function saveOnlineState(item:LabRoll, saveLen:Boolean=false):void{
			//is_online - neve persists it, used only at runtime
			/*
			var sql:String;
			if(!saveLen){
				sql='UPDATE config.lab_rolls SET is_online=? WHERE lab_device=? AND width=? AND paper=?';
				execute(sql,[item.is_online?1:0, item.lab_device, item.width, item.paper]);
			}else{
				sql='UPDATE config.lab_rolls SET is_online=?, len=? WHERE lab_device=? AND width=? AND paper=?';
				execute(sql,[item.is_online?1:0, item.len, item.lab_device, item.width, item.paper]);
			}
			*/
		}

		override protected function processRow(o:Object):Object{
			var a:LabRoll= new LabRoll();
			fillRow(o,a);
			return a;
		}
	}
}