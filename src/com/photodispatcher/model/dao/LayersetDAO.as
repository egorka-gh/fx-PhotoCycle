package com.photodispatcher.model.dao{
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.Layerset;
	
	import mx.collections.ArrayCollection;

	public class LayersetDAO extends BaseDAO{

		public function findAll(type:int=0,silent:Boolean=false):ArrayCollection{
			var res:Array=findAllArray(type, silent);
			return new ArrayCollection(res);
		}
		
		public function findAllArray(type:int=0, silent:Boolean=false):Array{
			var sql:String='SELECT s.id, s.subset_type, s.name, s.book_type, s.is_pdf, s.interlayer_thickness, bt.name book_type_name'+
				' FROM config.layerset s'+
				' INNER JOIN config.book_type bt ON bt.id=s.book_type'+
				' WHERE s.subset_type=?';
			sql+=' ORDER BY s.name';
			runSelect(sql,[type],silent);
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
				'UPDATE config.layerset SET name=?, book_type=?, is_pdf=?, interlayer_thickness=? WHERE id=?',
				[	item.name,
					item.book_type,
					item.is_pdf?1:0,
					item.interlayer_thickness,
					item.id],item);
		}
		
		public function create(item:Layerset):void{
			addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			execute("INSERT INTO config.layerset (subset_type, name, book_type, is_pdf, interlayer_thickness)" +
				"VALUES (?, ?, ?, ?, ?)",
				[	item.subset_type,
					item.name,
					item.book_type,
					item.is_pdf?1:0,
					item.interlayer_thickness],item);
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