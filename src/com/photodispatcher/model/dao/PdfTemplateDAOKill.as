package com.photodispatcher.model.dao{
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.PdfTemplate;
	
	import mx.collections.ArrayCollection;
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;

	public class PdfTemplateDAOKill extends BaseDAO{
		
		private static var templateMap:Object;
		
		public static function getTemplate(id:int):PdfTemplate{
			var t:PdfTemplate;
			if(!templateMap) initTemplateMap();
			if(templateMap) t=templateMap[id.toString()] as PdfTemplate;
			return t;
		}
		
		private static function initTemplateMap():void{
			var dao:PdfTemplateDAO=new PdfTemplateDAO();
			var a:Array=dao.findAllArr(true);
			if(!a) return;
			var t:PdfTemplate;
			templateMap=new Object();
			for each(t in a){
				if(t){
					templateMap[t.id.toString()]=t;
				}
			}
		}

		override protected function processRow(o:Object):Object{
			var a:PdfTemplate = new PdfTemplate();
			a.id=o.id;
			a.name=o.name;
			a.width=o.width;
			a.height=o.height;
			a.blocks=o.blocks;
			a.block_width=o.block_width;
			a.block_height=o.block_height;
			a.fill_order=o.fill_order;
			
			a.fill_order_name=o.fill_order_name;
			
			a.loaded = true;
			return a;
		}

		override public function save(item:Object):void{
			var it:PdfTemplate= item as PdfTemplate;
			if(!it) return;
			if (it.id){
				update(it);
			}else{
				create(it);
			}
		}
		
		public function update(item:PdfTemplate):void{
			execute(
				'UPDATE config.pdf_template'+
				' SET name=?, width=?, height=?, blocks=?, block_width=?, block_height=?, fill_order=?' + 
				' WHERE id=?',
				[	item.name,
					item.width,
					item.height,
					item.blocks,
					item.block_width,
					item.block_height,
					item.fill_order,
					item.id],item);
		}
		
		public function create(item:PdfTemplate):void{
			addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			execute(
				"INSERT INTO config.pdf_template (name, width, height, blocks, block_width, block_height, fill_order) " +
				"VALUES (?,?,?,?,?,?,?)",
				[	item.name,
					item.width,
					item.height,
					item.blocks,
					item.block_width,
					item.block_height,
					item.fill_order],item);
		}
		private function onCreate(e:AsyncSQLEvent):void{
			removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				var it:PdfTemplate= e.item as PdfTemplate;
				if(it) it.id=e.lastID;
			}
		}

		public static function idToLabel(item:Object, column:GridColumn):String{
			return item[column.dataField+'_name'];
		}
		
		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn= new GridColumn('name'); col.headerText='Наименование'; result.addItem(col);
			col= new GridColumn('width'); col.headerText='Ширина (pcx)'; result.addItem(col);
			col= new GridColumn('height'); col.headerText='Длина (pcx)'; result.addItem(col);
			col= new GridColumn('block_width'); col.headerText='Ширина блока (pcx)'; result.addItem(col);
			col= new GridColumn('block_height'); col.headerText='Длина блока (pcx)'; result.addItem(col);

			//col= new GridColumn('cutting'); col.headerText='Обрезка'; col.labelFunction=idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			return result;
		}

		public function findAllArr(silent:Boolean=false):Array{
			var sql:String;
			sql='SELECT l.*'+
				' FROM config.pdf_template l'+
				' WHERE l.id!=0'+
				' ORDER BY l.name';
			runSelect(sql,null,silent);
			return itemsArray;
		}

	}
}