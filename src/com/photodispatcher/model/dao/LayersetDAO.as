package com.photodispatcher.model.dao{
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.Layerset;
	
	import mx.collections.ArrayCollection;

	public class LayersetDAO extends BaseDAO{

		public function findAll(type:int=0,silent:Boolean=false, techGroup:int=-1):ArrayCollection{
			var res:Array=findAllArray(type, silent, techGroup);
			return new ArrayCollection(res);
		}
		
		public function findAllArray(type:int=0, silent:Boolean=false, techGroup:int=-1):Array{
			var params:Array=[];
			var sql:String='SELECT s.*, bt.name book_type_name'+
				' FROM config.layerset s'+
				' INNER JOIN config.book_type bt ON bt.id=s.book_type'+
				' WHERE s.subset_type=?';
			params.push(type);
			if(techGroup!=-1){
				sql+=' AND s.layerset_group = ?';
				params.push(techGroup);
			}
			sql+=' ORDER BY s.is_passover DESC, s.name';
			runSelect(sql,params,silent);
			var res:Array=itemsArray;
			return res;
		}

		override public function save(item:Object):void{
			var it:Layerset=item as Layerset;
			if(!it) return;
			if (it.id==-1){
				create(it);
			}else{
				update(it);
			}
		}
		
		public function update(item:Layerset):void{
			execute(
				'UPDATE config.layerset SET name=?, layerset_group=?, book_type=?, is_pdf=?, is_passover=?, is_book_check_off=?, is_epaper_check_off=? WHERE id=?',
				[	item.name,
					item.layerset_group,
					item.book_type,
					item.is_pdf?1:0,
					item.is_passover?1:0,
					item.is_book_check_off?1:0,
					item.is_epaper_check_off?1:0,
					item.id],item);
		}
		
		public function create(item:Layerset):void{
			addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			execute("INSERT INTO config.layerset (subset_type, layerset_group, name, book_type, is_pdf, is_passover, is_book_check_off, is_epaper_check_off)" +
				" VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
				[	item.subset_type,
					item.layerset_group,
					item.name,
					item.book_type,
					item.is_pdf?1:0,
					item.is_passover?1:0,
					item.is_book_check_off?1:0,
					item.is_epaper_check_off?1:0],item);
		}
		private function onCreate(e:AsyncSQLEvent):void{
			removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				var it:Layerset= e.item as Layerset;
				if(it){ 
					it.id=e.lastID;
					it.loaded=true;
				}
			}
		}

		
		override protected function processRow(o:Object):Object{
			var a:Layerset= new Layerset();
			fillRow(o,a);
			return a;
		}

	}
}