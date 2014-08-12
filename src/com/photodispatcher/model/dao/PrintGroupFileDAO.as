package com.photodispatcher.model.dao{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.mysql.entities.PrintGroupFile;
	
	import flash.globalization.DateTimeStyle;
	
	import mx.collections.ArrayCollection;
	import mx.collections.ArrayList;
	import mx.events.ItemClickEvent;
	
	import spark.components.gridClasses.GridColumn;
	import spark.formatters.DateTimeFormatter;
	
	public class PrintGroupFileDAO extends BaseDAO{

		public static function gridColumns():ArrayList{
			var result:Array= [];
			var col:GridColumn;
			
			col= new GridColumn('print_group'); col.headerText='Группа печати'; col.width=85; result.push(col);
			col= new GridColumn('path'); col.headerText='Папка'; col.width=110; result.push(col);
			col= new GridColumn('file_name'); col.headerText='Файл'; col.width=250; result.push(col); 
			col= new GridColumn('caption'); col.headerText='Подпись'; col.width=250; result.push(col); 
			col= new GridColumn('book_num'); col.headerText='№ Книги'; result.push(col);
			col= new GridColumn('page_num'); col.headerText='№ Листа'; result.push(col);
			col= new GridColumn('prt_qty'); col.headerText='Кол отпечатков'; result.push(col);
			return new ArrayList(result);
		}

		public function getByPrintGroup(printGroupId:String):Array{
			runSelect('SELECT * FROM print_group_file WHERE print_group=?',[printGroupId]);
			return itemsArray;
		}
		
		public function getByOrder(orderId:String):Array{
			var sql:String='SELECT pgf.*, pg.path'+
				' FROM print_group pg INNER JOIN print_group_file pgf ON pg.id = pgf.print_group'+
				' WHERE pg.order_id = ?';
			runSelect(sql,[orderId]);
			return itemsArray;
		}

		override protected function processRow(o:Object):Object{
			var a:PrintGroupFile = new PrintGroupFile();
			/*
			a.id=o.id;
			a.print_group=o.print_group;
			a.file_name=o.file_name;
			a.prt_qty=o.prt_qty;
			a.path=o.path;
			a.book_num=o.book_num;	
			a.page_num=o.page_num;	

			a.loaded = true;
			*/
			//fillRow(o,a);
			return a;
		}
	}
}