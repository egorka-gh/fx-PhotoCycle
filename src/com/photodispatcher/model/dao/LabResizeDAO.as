package com.photodispatcher.model.dao{
	import com.photodispatcher.event.AsyncSQLEvent;
	//import com.photodispatcher.model.LabResize;
	
	import mx.collections.ArrayCollection;
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;

	public class LabResizeDAO extends BaseDAO{
		/*
		private static var sizeMap:Object;

		public static function getSizeLimit(size:int):int{
			var sl:LabResize;
			if(!sizeMap) initSizeMap();
			if(sizeMap) sl=sizeMap[size.toString()] as LabResize;
			return sl?sl.pixels:0;
		}

		public static function initSizeMap():void{
			var dao:LabResizeDAO=new LabResizeDAO();
			if(dao.runSelect('SELECT l.* FROM config.lab_resize l ORDER BY l.width',null,true)){
				var a:Array=dao.itemsArray;
				if(!a) return;
				sizeMap=new Object();
				for each(var o:Object in a){
					var s:LabResize= o as LabResize;
					if(s){
						sizeMap[s.width.toString()]=s;
					}
				}
			}
		}

		override protected function processRow(o:Object):Object{
			var a:LabResize = new LabResize();
			a.id=o.id;
			a.width=o.width;
			a.pixels=o.pixels;
			
			a.loaded = true;
			return a;
		}

		override public function save(item:Object):void{
			var it:LabResize= item as LabResize;
			if(!it) return;
			if (it.id){
				update(it);
			}else{
				create(it);
			}
		}
		
		public function update(item:LabResize):void{
			execute(
				"UPDATE config.lab_resize SET width=?, pixels=? WHERE id=?",
				[	item.width,
					item.pixels,
					item.id],item);
		}
		
		public function create(item:LabResize):void{
			addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			execute(
				"INSERT INTO config.lab_resize (width, pixels) " +
				"VALUES (?,?)",
				[item.width, item.pixels], item);
		}
		private function onCreate(e:AsyncSQLEvent):void{
			removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				var it:LabResize= e.item as LabResize;
				if(it) it.id=e.lastID;
			}
		}
		
		public function findAll():ArrayCollection{
			var sql:String;
			sql='SELECT l.* FROM config.lab_resize l ORDER BY l.width';
			runSelect(sql);
			return itemsList;
		}

		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			//var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
			col= new GridColumn('width'); col.headerText='Размер (мм)'; col.width=100; result.addItem(col);
			col= new GridColumn('pixels'); col.headerText='Ресайз (pcx)'; result.addItem(col);
			return result;
		}
*/
	}
}