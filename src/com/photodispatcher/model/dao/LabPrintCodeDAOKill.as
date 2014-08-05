package com.photodispatcher.model.dao{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.mysql.entities.LabPrintCode;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.util.GridUtil;
	import com.photodispatcher.view.itemRenderer.BooleanGridItemEditor;
	import com.photodispatcher.view.itemRenderer.CBoxGridItemEditor;
	
	import mx.collections.ArrayCollection;
	import mx.collections.ArrayList;
	import mx.core.ClassFactory;
	
	import spark.components.gridClasses.GridColumn;

	public class LabPrintCodeDAOKill extends BaseDAO{
		
		override protected function processRow(o:Object):Object{
			var a:LabPrintCode = new LabPrintCode();
			fillRow(o,a);
			return a;
		}

		override public function save(item:Object):void{
			var it:LabPrintCode= item as LabPrintCode;
			if(!it) return;
			if (it.id){
				update(it);
			}else{
				create(it);
			}
		}
		
		public function update(item:LabPrintCode):void{
			execute(
				"UPDATE config.lab_print_code SET src_type=?, src_id=?, prt_code=?, width=?, height=?, paper=?, frame=?, correction=?, cutting=?, is_duplex=?, roll=? WHERE id=?",
				[	item.src_type,
					item.src_id,
					item.prt_code,
					item.width,
					item.height,
					item.paper,
					item.frame,
					item.correction,
					item.cutting,
					item.is_duplex?1:0,
					item.roll,
					item.id],item);
		}
		
		public function create(item:LabPrintCode):void{
			addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			execute(
				"INSERT INTO config.lab_print_code (src_type, src_id, prt_code, width, height, paper, frame, correction, cutting, is_duplex, roll) " +
					"VALUES (?,?,?,?,?,?,?,?,?,?,?)",
						[item.src_type,
						item.src_id,
						item.prt_code,
						item.width,
						item.height,
						item.paper,
						item.frame,
						item.correction,
						item.cutting,
						item.is_duplex?1:0,
						item.roll],item);
		}
		private function onCreate(e:AsyncSQLEvent):void{
			removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onCreate);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				var it:LabPrintCode= e.item as LabPrintCode;
				if(it) it.id=e.lastID;
			}
		}

		public function findAll(src_type:int):ArrayCollection{
			var sql:String;
			sql='SELECT l.*, p.value paper_name, fr.value frame_name, cr.value correction_name, cu.value cutting_name'+
				  ' FROM config.lab_print_code l'+
				       ' INNER JOIN config.attr_value p ON l.paper = p.id'+
				       ' INNER JOIN config.attr_value fr ON l.frame = fr.id'+
				       ' INNER JOIN config.attr_value cr ON l.correction = cr.id'+
				       ' INNER JOIN config.attr_value cu ON l.cutting = cu.id'+
				 ' WHERE l.src_type = ?'+
				' ORDER BY l.prt_code';
			runSelect(sql,[src_type]);
			return itemsList;
		}

		public function findAllArray(src_type:int):Array{
			var sql:String;
			sql='SELECT l.*, p.value paper_name, fr.value frame_name, cr.value correction_name, cu.value cutting_name'+
				' FROM config.lab_print_code l'+
				' INNER JOIN config.attr_value p ON l.paper = p.id'+
				' INNER JOIN config.attr_value fr ON l.frame = fr.id'+
				' INNER JOIN config.attr_value cr ON l.correction = cr.id'+
				' INNER JOIN config.attr_value cu ON l.cutting = cu.id'+
				' WHERE l.src_type = ?'+
				' ORDER BY l.prt_code';
			runSelect(sql,[src_type]);
			return itemsArray;
		}

		public static function idToLabel(item:Object, column:GridColumn):String{
			return item[column.dataField+'_name'];
		}
		
		public static function gridColumns(labType:int=SourceType.LAB_NORITSU):ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			var visible:Boolean=labType!=SourceType.LAB_NORITSU_NHF;
			col= new GridColumn('prt_code'); col.headerText='Канал'; col.visible=visible && labType!=SourceType.LAB_PLOTTER; result.addItem(col);
			//var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
			col= new GridColumn('width'); col.headerText='Ширина'; result.addItem(col);
			col= new GridColumn('height'); col.headerText='Длина'; result.addItem(col);
			
			col= new GridColumn('roll'); col.headerText='Рулон'; col.itemEditor=new ClassFactory(CBoxGridItemEditor); col.visible=labType!=SourceType.LAB_PLOTTER && labType!=SourceType.LAB_XEROX; result.addItem(col);
			col= new GridColumn('paper'); col.headerText='Бумага'; col.labelFunction=idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); col.visible=visible; result.addItem(col);
			
			visible= visible && labType!=SourceType.LAB_PLOTTER;
			col= new GridColumn('is_duplex'); col.headerText='Duplex'; col.labelFunction=GridUtil.booleanToLabel; col.itemEditor=new ClassFactory(BooleanGridItemEditor); col.visible= visible && labType==SourceType.LAB_XEROX; result.addItem(col);

			visible= visible && labType!=SourceType.LAB_XEROX;
			col= new GridColumn('frame'); col.headerText='Рамка'; col.labelFunction=idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); col.visible=visible; result.addItem(col);

			visible= visible && labType!=SourceType.LAB_FUJI;
			col= new GridColumn('correction'); col.headerText='Коррекция'; col.labelFunction=idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); col.visible=visible; result.addItem(col);
			col= new GridColumn('cutting'); col.headerText='Обрезка'; col.labelFunction=idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); col.visible=visible; result.addItem(col);
			return result;
		}
		
	}
}