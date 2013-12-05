package com.photodispatcher.model.dao{
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.Layerset;
	
	import mx.collections.ArrayCollection;

	public class LayersetDAO extends BaseDAO{

		public function findAll(silent:Boolean=false):ArrayCollection{
			var res:Array=findAllArray(silent);
			return new ArrayCollection(res);
		}
		
		public function findAllArray(silent:Boolean=false):Array{
			var sql:String='SELECT s.id, s.name, s.width, s.len, s.book_type, s.is_pdf, s.endpaper, s.interlayer, s.interlayer_thickness, bt.name book_type_name'+
				' FROM config.layerset s'+
				' INNER JOIN config.book_type bt ON bt.id=s.book_type';
			sql+=' ORDER BY s.name';
			runSelect(sql,null,silent);
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
				'UPDATE config.layerset SET name=?, width=?, len=?, book_type=?, is_pdf=?, endpaper=?, interlayer=?, interlayer_thickness=? WHERE id=?',
				[	item.name,
					item.width,
					item.len,
					item.book_type,
					item.is_pdf?1:0,
					item.endpaper,
					item.interlayer,
					item.interlayer_thickness,
					item.id],item);
		}
		
		public function create(item:Layerset):void{
			addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			execute("INSERT INTO config.layerset (name, width, len, book_type, is_pdf, endpaper, interlayer, interlayer_thickness)" +
				"VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
				[	item.name,
					item.width,
					item.len,
					item.book_type,
					item.is_pdf?1:0,
					item.endpaper,
					item.interlayer,
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