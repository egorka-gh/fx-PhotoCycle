package com.photodispatcher.model.dao{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.dao.daoi.ISourcesDAO;
	import com.photodispatcher.view.itemRenderer.CBoxGridItemEditor;
	
	import mx.collections.ArrayCollection;
	import mx.collections.ArrayList;
	import mx.core.ClassFactory;
	
	import spark.components.gridClasses.GridColumn;
	
	public class SourcesDAO extends BaseDAO{
		
		public static function gridColumns(labColumns:Boolean=false):ArrayList{
			var result:ArrayList= new ArrayList();
			
			var col:GridColumn= new GridColumn('id'); col.headerText='ID'; result.addItem(col);
			col= new GridColumn('name'); col.headerText='Наименование'; result.addItem(col); 
			col= new GridColumn('type_name'); col.headerText='Тип'; result.addItem(col); 
			col= new GridColumn('online'); col.headerText='Online'; result.addItem(col); 
			if(!labColumns){
				col= new GridColumn('code'); col.headerText='Код'; result.addItem(col); 
			}
			return result;
		}

		public function findAll(locationType:int=1):ArrayCollection{
			var res:Array=findAllArray(locationType);
			return new ArrayCollection(res);
		}

		public function findAllArray(locationType:int=1):Array{
			var sql:String='SELECT s.id, s.name, s.type_id, s.code, coalesce(ss.sync,s.sync,0) sync, s.online, st.name type_name, st.loc_type'+
							' FROM config.sources s' +
							' INNER JOIN config.src_type st ON st.id = s.type_id'+
							' LEFT OUTER JOIN sources_sync ss on s.id=ss.id' +
							' WHERE st.loc_type = ? ORDER BY s.name';
			runSelect(sql,[locationType]);
			var res:Array=itemsArray;
			if (locationType==1 && res) Context.setSources(res);
			return res;
		}
		
		override public function save(item:Object):void{
			var it:Source=item as Source;
			if(!it) return;
			if (it.id>0){
				update(it);
			}else{
				create(it);
			}
		}
		
		public function update(item:Source):void{
			execute(
				'UPDATE config.sources SET name=?, type_id=?, online=?, code=? WHERE id=?',
				[	item.name,
					item.type,
					item.online?1:0,
					item.code.charAt(0),
					item.id],item);

		}
		
		public function create(item:Source):void{
			addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			execute("INSERT INTO config.sources (id, name, type_id, code) " +
						"VALUES (?,?,?,?)",
						[	item.id > 0 ? item.id : null,
							item.name,
							item.type,
							item.code.charAt(0)],item);
		}
		private function onCreate(e:AsyncSQLEvent):void{
			removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				var it:Source= e.item as Source;
				if(it) it.id=e.lastID;
			}
		}
		
		override protected function processRow(o:Object):Object{
			var a:Source = new Source();
			a.id=o.id;
			a.name=o.name;
			a.type=o.type_id;
			a.sync=o.sync;
			a.type_name=o.type_name;
			//a.type_id_name=a.type_name;
			a.online= o.online==1;
			a.loc_type=o.loc_type;
			a.code=o.code;
			if(!a.code) a.code=String.fromCharCode(64+a.id); 
			
			//a.loaded = true;
			return a;
		}

	}
}