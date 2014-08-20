package com.photodispatcher.model.dao{
	
	
	import com.photodispatcher.model.mysql.entities.StateLog;
	
	import flash.globalization.DateTimeStyle;
	
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;
	import spark.formatters.DateTimeFormatter;

	public class StateLogDAO extends BaseDAO{

		public static function gridColumns(includeOrderId:Boolean=false):ArrayList{
			var result:Array= [];
			var col:GridColumn;
			
			if(includeOrderId){
				col= new GridColumn('order_id'); col.headerText='ID Заказа'; col.width=85; result.push(col);
				col= new GridColumn('pg_id'); col.headerText='ID Группы'; col.width=85; result.push(col);
			}else{
				col= new GridColumn('pg_id'); col.headerText='ID'; col.width=85; result.push(col);
			}
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
			col= new GridColumn('state_date'); col.headerText='Дата'; col.formatter=fmt;  col.width=110; result.push(col);
			col= new GridColumn('state_name'); col.headerText='Статус'; col.width=100; result.push(col); 
			col= new GridColumn('comment'); col.headerText='Комментарий'; result.push(col); 
			return new ArrayList(result);
		}

		override protected function processRow(o:Object):Object{
			var a:StateLog = new StateLog();
			/*
			a.id=o.id;
			a.order_id=o.order_id;
			a.pg_id=o.pg_id;
			a.state=o.state;
			a.state_date=new Date(o.state_date);
			a.comment=o.comment;
			
			a.state_name=o.state_name;

			a.loaded = true;
			*/
			return a;
		}

		public function getByOrder(orderId:String):Array{
			var sql:String='SELECT sl.id, sl.order_id, ifnull( sl.pg_id, sl.order_id ) pg_id, sl.state, sl.state_date, sl.comment, os.name state_name'+
							 ' FROM state_log sl INNER JOIN config.order_state os ON sl.state = os.id'+
							 ' WHERE sl.order_id = ?';
			runSelect(sql,[orderId]);
			return itemsArray;
		}
		
		public function findeAllArray(date:Date,onlyErrors:Boolean=true):Array{
			var where:String;
			var params:Array=[];
			var dateFrom:Date;
			var dateTo:Date;
			if(!date) date=new Date();
			dateFrom=new Date(date.fullYear,date.month,date.date);
			dateTo=new Date(date.fullYear,date.month,date.date+1);
			params.push(dateFrom);
			params.push(dateTo);
			if (onlyErrors) where=' AND sl.state<0';
			
			var sql:String='SELECT sl.id, sl.order_id, sl.pg_id, sl.state, sl.state_date, sl.comment, os.name state_name'+
				' FROM state_log sl INNER JOIN config.order_state os ON sl.state = os.id'+
				' WHERE sl.state_date >= ? AND sl.state_date <= ?'+where;
			runSelect(sql,params);
			return itemsArray;
		}
		
		public static function logState(state:int, orderId:String, pgId:String='', comment:String=''):void{
			var dao:StateLogDAO= new StateLogDAO();
			var comm:String=comment;
			if(comm){
				comm=comm.replace('\n',' ');
				comm=comm.replace('\r',' ');
				comm=comm.replace('  ',' ');
				comm=comm.substr(0,250);
			}
			dao.log(state, orderId, pgId, comm);
		}
		
		private function log(state:int, orderId:String, pgId:String='', comment:String=''):void{
			var dt:Date=new Date();
			var sql:String='INSERT INTO state_log (state, order_id, pg_id, state_date, comment) VALUES (?, ?, ?, ?, ?)';
			var params:Array=[state, orderId, (pgId?pgId:null), dt, comment];
			asyncFaultMode=FAULT_IGNORE;
			execute(sql,params);
		}

	}
}