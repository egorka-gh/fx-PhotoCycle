package com.photodispatcher.model.dao{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.Order;
	import com.photodispatcher.model.OrderState;
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.PrintGroupFile;
	import com.photodispatcher.util.GridUtil;
	
	import flash.data.SQLStatement;
	import flash.globalization.DateTimeStyle;
	import flash.utils.Dictionary;
	
	import mx.collections.ArrayCollection;
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;
	import spark.formatters.DateTimeFormatter;
	
	public class PrintGroupDAO extends BaseDAO{
		
		public function getByOrder(orderId:String):Array{
			var sql:String;
			sql='SELECT pg.*, o.source source_id, s.name source_name, o.ftp_folder order_folder, os.name state_name,'+
				' p.value paper_name, fr.value frame_name, cr.value correction_name, cu.value cutting_name,'+
				' lab.name lab_name, bt.name book_type_name, bp.name book_part_name'+
				' FROM print_group pg INNER JOIN orders o ON pg.order_id = o.id'+
				' INNER JOIN config.sources s ON o.source = s.id'+
				' INNER JOIN config.order_state os ON pg.state = os.id'+
				' INNER JOIN config.attr_value p ON pg.paper = p.id'+
				' INNER JOIN config.attr_value fr ON pg.frame = fr.id'+
				' INNER JOIN config.attr_value cr ON pg.correction = cr.id'+
				' INNER JOIN config.attr_value cu ON pg.cutting = cu.id'+
				' INNER JOIN config.book_type bt ON pg.book_type = bt.id'+
				' INNER JOIN config.book_part bp ON pg.book_part = bp.id'+
				' LEFT OUTER JOIN config.sources lab ON pg.destination = lab.id'+
				' WHERE pg.order_id=?';
			//trace(sql);
			var params:Array=[orderId];
			runSelect(sql,params);
			return itemsArray;
		}

		public static function gridColumns(withLab:Boolean=false):ArrayList{
			var a:Array=baseGridColumns();
			var col:GridColumn;
			if(!a) return null;
			if(withLab){
				col= new GridColumn('lab_name'); col.headerText='Лаборатория'; col.width=80;
				a.unshift(col);
			}
			return new ArrayList(a);
		}

		private static function baseGridColumns():Array{
			var result:Array= [];
			
			var col:GridColumn= new GridColumn('source_name'); col.headerText='Источник'; col.width=70; result.push(col);
			//col= new GridColumn('order_id'); col.headerText='Id Заказа'; result.addItem(col);
			col= new GridColumn('id'); col.headerText='ID'; col.width=80; result.push(col);
			col= new GridColumn('state_name'); col.headerText='Статус'; col.width=95; result.push(col); 
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
			col= new GridColumn('state_date'); col.headerText='Дата статуса'; col.formatter=fmt;  col.width=110; result.push(col);
			col= new GridColumn('path'); col.headerText='Папка'; result.push(col);
			col= new GridColumn('width'); col.headerText='Ширина'; result.push(col);
			col= new GridColumn('height'); col.headerText='Длина'; result.push(col);
			col= new GridColumn('paper_name'); col.headerText='Бумага'; result.push(col);
			col= new GridColumn('frame_name'); col.headerText='Рамка'; result.push(col);
			col= new GridColumn('correction_name'); col.headerText='Коррекция'; result.push(col);
			col= new GridColumn('cutting_name'); col.headerText='Обрезка'; result.push(col);
			col= new GridColumn('book_type_name'); col.headerText='Тип книги'; result.push(col);
			col= new GridColumn('book_part_name'); col.headerText='Часть книги'; result.push(col);
			col= new GridColumn('is_pdf'); col.headerText='PDF'; col.labelFunction=GridUtil.booleanToLabel; result.push(col);
			col= new GridColumn('book_num'); col.headerText='Кол книг'; result.push(col);
			//col= new GridColumn('cover_name'); col.headerText='Обложка'; result.addItem(col);
			col= new GridColumn('prints'); col.headerText='Кол отпечатков'; result.push(col);
			return result;
		}

		public static function shortGridColumns():ArrayList{
			var result:Array= [];
			var col:GridColumn;
			
			col= new GridColumn('id'); col.headerText='ID'; col.width=85; result.push(col);
			col= new GridColumn('state_name'); col.headerText='Статус'; col.width=90; result.push(col); 
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
			col= new GridColumn('state_date'); col.headerText='Дата статуса'; col.formatter=fmt;  col.width=110; result.push(col);
			col= new GridColumn('lab_name'); col.headerText='Лаборатория'; col.width=70; result.push(col);
			col= new GridColumn('is_reprint'); col.headerText='Перепечатка'; col.labelFunction=GridUtil.booleanToLabel; result.push(col);
			col= new GridColumn('path'); col.headerText='Папка'; result.push(col);
			col= new GridColumn('width'); col.headerText='Ширина'; result.push(col);
			col= new GridColumn('height'); col.headerText='Длина'; result.push(col);
			col= new GridColumn('paper_name'); col.headerText='Бумага'; result.push(col);
			col= new GridColumn('frame_name'); col.headerText='Рамка'; result.push(col);
			col= new GridColumn('correction_name'); col.headerText='Коррекция'; result.push(col);
			col= new GridColumn('cutting_name'); col.headerText='Обрезка'; result.push(col);
			col= new GridColumn('book_type_name'); col.headerText='Тип книги'; result.push(col);
			col= new GridColumn('book_part_name'); col.headerText='Часть книги'; result.push(col);
			col= new GridColumn('is_pdf'); col.headerText='PDF'; col.labelFunction=GridUtil.booleanToLabel; result.push(col);
			col= new GridColumn('book_num'); col.headerText='Кол книг'; result.push(col);
			col= new GridColumn('prints'); col.headerText='Кол отпечатков'; result.push(col);
			return new ArrayList(result);
		}

		public static function reprintGridColumns():ArrayList{
			var result:Array= [];
			var col:GridColumn;
			
			col= new GridColumn('id'); col.headerText='ID'; col.width=85; result.push(col);
			col= new GridColumn('path'); col.headerText='Папка'; result.push(col);
			col= new GridColumn('width'); col.headerText='Ширина'; result.push(col);
			col= new GridColumn('height'); col.headerText='Длина'; result.push(col);
			col= new GridColumn('paper_name'); col.headerText='Бумага'; result.push(col);
			col= new GridColumn('frame_name'); col.headerText='Рамка'; result.push(col);
			col= new GridColumn('correction_name'); col.headerText='Коррекция'; result.push(col);
			col= new GridColumn('cutting_name'); col.headerText='Обрезка'; result.push(col);
			col= new GridColumn('book_type_name'); col.headerText='Тип книги'; result.push(col);
			col= new GridColumn('book_part_name'); col.headerText='Часть книги'; result.push(col);
			col= new GridColumn('is_pdf'); col.headerText='PDF'; col.labelFunction=GridUtil.booleanToLabel; result.push(col);
			col= new GridColumn('book_num'); col.headerText='Кол книг'; result.push(col);
			return new ArrayList(result);
		}

		public function findAllArray(stateFrom:int=-1, stateTo:int=-1):Array{ 
			var sql:String;
			var where:String='';
			var params:Array;
			
			if(stateFrom!=-1){
				if(where) where=where+' AND';
				where=where+' pg.state>=?';
				if(!params) params=new Array();
				params.push(stateFrom);
			}
			if(stateTo!=-1){
				if(where) where=where+' AND';
				where=where+' pg.state<?';
				if(!params) params=new Array();
				params.push(stateTo);
			}

			if(where) where=' WHERE'+where;
			sql='SELECT pg.*, o.source source_id, s.name source_name, o.ftp_folder order_folder, os.name state_name,'+
				' p.value paper_name, fr.value frame_name, cr.value correction_name, cu.value cutting_name,'+
				' bt.name book_type_name, bp.name book_part_name'+
				' FROM print_group pg INNER JOIN orders o ON pg.order_id = o.id'+
				' INNER JOIN config.sources s ON o.source = s.id'+
				' INNER JOIN config.order_state os ON pg.state = os.id'+
				' INNER JOIN config.attr_value p ON pg.paper = p.id'+
				' INNER JOIN config.attr_value fr ON pg.frame = fr.id'+
				' INNER JOIN config.attr_value cr ON pg.correction = cr.id'+
				' INNER JOIN config.attr_value cu ON pg.cutting = cu.id'+
				' INNER JOIN config.book_type bt ON pg.book_type = bt.id'+
				' INNER JOIN config.book_part bp ON pg.book_part = bp.id'+
				where+
				' ORDER BY pg.state_date';
			//trace(sql);
			runSelect(sql,params);
			return itemsArray;
		}

		public function findAllInPrint():Array{ 
			var sql:String;
			sql='SELECT pg.*, o.source source_id, s.name source_name, o.ftp_folder order_folder, os.name state_name,'+
				' p.value paper_name, fr.value frame_name, cr.value correction_name, cu.value cutting_name,'+
				' lab.name lab_name, bt.name book_type_name, bp.name book_part_name'+
				' FROM print_group pg INNER JOIN orders o ON pg.order_id = o.id'+
				' INNER JOIN config.sources s ON o.source = s.id'+
				' INNER JOIN config.order_state os ON pg.state = os.id'+
				' INNER JOIN config.attr_value p ON pg.paper = p.id'+
				' INNER JOIN config.attr_value fr ON pg.frame = fr.id'+
				' INNER JOIN config.attr_value cr ON pg.correction = cr.id'+
				' INNER JOIN config.attr_value cu ON pg.cutting = cu.id'+
				' INNER JOIN config.book_type bt ON pg.book_type = bt.id'+
				' INNER JOIN config.book_part bp ON pg.book_part = bp.id'+
				' LEFT OUTER JOIN config.lab lab ON pg.destination = lab.id'+
				' WHERE o.state>=? AND o.state<?'+
				' ORDER BY pg.state_date';
			//trace(sql);
			var params:Array=[OrderState.PRN_POST,OrderState.PRN_COMPLETE];
			runSelect(sql,params);
			return itemsArray;
		}

		public function findInPrint(labId:int):Array{ 
			var sql:String;
			sql='SELECT pg.*, o.source source_id, s.name source_name, o.ftp_folder order_folder, os.name state_name,'+
				' p.value paper_name, fr.value frame_name, cr.value correction_name, cu.value cutting_name,'+
				' bt.name book_type_name, bp.name book_part_name, COUNT(DISTINCT tl.sheet) prints_done'+
				' FROM print_group pg'+
				' INNER JOIN orders o ON pg.order_id = o.id'+
				' INNER JOIN config.sources s ON o.source = s.id'+
				' INNER JOIN config.order_state os ON pg.state = os.id'+
				' INNER JOIN config.attr_value p ON pg.paper = p.id'+
				' INNER JOIN config.attr_value fr ON pg.frame = fr.id'+
				' INNER JOIN config.attr_value cr ON pg.correction = cr.id'+
				' INNER JOIN config.attr_value cu ON pg.cutting = cu.id'+
				' INNER JOIN config.book_type bt ON pg.book_type = bt.id'+
				' INNER JOIN config.book_part bp ON pg.book_part = bp.id'+
				' LEFT OUTER JOIN tech_log tl ON pg.id = tl.print_group'+
				' WHERE pg.state=? AND pg.destination=?'+
				' GROUP BY pg.id'+
				' ORDER BY pg.state_date';
			//trace(sql);
			var params:Array=[OrderState.PRN_PRINT,labId];
			runSelect(sql,params,true);
			return itemsArray;
		}

		public function findPrinted(date:Date=null):Array{ 
			var sql:String;
			var where:String
			var params:Array=[OrderState.PRN_COMPLETE,OrderState.PRN_COMPLETE+1];
			if(date){
				where=' AND o.state_date>=?';
				params.push(date);
			}
			sql='SELECT pg.*, o.source source_id, s.name source_name, o.ftp_folder order_folder, os.name state_name,'+
				' p.value paper_name, fr.value frame_name, cr.value correction_name, cu.value cutting_name,'+
				' lab.name lab_name, bt.name book_type_name, bp.name book_part_name'+
				' FROM print_group pg INNER JOIN orders o ON pg.order_id = o.id'+
				' INNER JOIN config.sources s ON o.source = s.id'+
				' INNER JOIN config.order_state os ON pg.state = os.id'+
				' INNER JOIN config.attr_value p ON pg.paper = p.id'+
				' INNER JOIN config.attr_value fr ON pg.frame = fr.id'+
				' INNER JOIN config.attr_value cr ON pg.correction = cr.id'+
				' INNER JOIN config.attr_value cu ON pg.cutting = cu.id'+
				' INNER JOIN config.book_type bt ON pg.book_type = bt.id'+
				' INNER JOIN config.book_part bp ON pg.book_part = bp.id'+
				' LEFT OUTER JOIN config.lab lab ON pg.destination = lab.id'+
				' WHERE o.state>=? AND o.state<?'+where+
				' ORDER BY pg.state_date';
			//trace(sql);
			runSelect(sql,params);
			return itemsArray;
		}

		public function findAll(stateFrom:int=-1, stateTo:int=-1):ArrayCollection{
			var a:Array=findAllArray(stateFrom,stateTo);
			if(a) return new ArrayCollection(a);
			return null;
		}

		public function update(item:PrintGroup):void{
			throw new Error('Write incomplited. Under refactoring.');
			/*
			executeUpdate(
				"UPDATE print_group SET state=?, state_date=? WHERE id=?",
				[	item.state,
					item.state_date,
					item.id]);
			*/
		}

		public function createReprintGroups(printGroups:Array):void{
			if(!printGroups || printGroups.length==0){
				dispatchEvent(new AsyncSQLEvent(AsyncSQLEvent.RESULT_COMLETED));
				return;
			}
			
			var sequence:Array=[];
			var stmt:SQLStatement;
			var sql:String;
			var params:Array;
			var item:PrintGroup;
			var pgf:PrintGroupFile;
			
			var orderId:String;
			var dt:Date=new Date();
			
			for each(item in printGroups){
				if(item){
					//save order id
					orderId=item.order_id;
					//create print group
					sql='INSERT INTO print_group (id, order_id, state, state_date, width, height, frame, paper, path, correction, cutting, file_num,'+
						' book_type, book_part, book_num, is_pdf, is_duplex, is_reprint, prints)' +
						' VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)';
					params=[item.id,
						item.order_id,
						item.state,
						item.state_date,
						item.width,
						item.height,
						item.frame,
						item.paper,
						item.path,
						item.correction,
						item.cutting,
						item.file_num,
						item.book_type,
						item.book_part,
						item.book_num,
						item.is_pdf?1:0,
						item.is_duplex?1:0,
						item.is_reprint?1:0,
						item.prints
					];
					sequence.push(prepareStatement(sql,params));
					
					//log print group state
					sql='INSERT INTO state_log (order_id, pg_id, state, state_date)' +
						' VALUES (?,?,?,?)';
					params=[item.order_id, item.id, item.state, item.state_date];
					sequence.push(prepareStatement(sql,params));
					
					if(item.getFiles() && item.getFiles().length>0){
						for each(pgf in item.getFiles()){
							if(pgf){
								//create PrintGroupFile
								sql='INSERT INTO print_group_file (print_group, file_name, prt_qty, book_num, page_num, caption)' +
									' VALUES (?,?,?,?,?,?)';
								params=[item.id, pgf.file_name, pgf.prt_qty, pgf.book_num, pgf.page_num, pgf.caption];
								sequence.push(prepareStatement(sql,params));
							}
						}
					}
				}
			}
			//reset order state
			sql='UPDATE orders SET state = ?, state_date = ?, reported_state=0 WHERE id = ? AND state > ?';
			params=[OrderState.PRN_POST, dt, orderId, OrderState.PRN_POST];
			sequence.push(prepareStatement(sql,params));
			//log order state
			sql='INSERT INTO state_log ( order_id, state, state_date)'+
				' SELECT o.id, o.state, o.state_date'+
				' FROM orders o WHERE o.id = ? AND o.state = ? AND o.state_date = ?';
			params=[orderId, OrderState.PRN_POST, dt];
			sequence.push(prepareStatement(sql,params));
			
			//start Sequence
			//addEventListener(SqlSequenceEvent.SQL_SEQUENCE_EVENT, onSequenceComplite);
			executeSequence(sequence);
		}

		public function setStateByTech(pgId:String):void{
			var sequence:Array=[];
			var stmt:SQLStatement;
			var sql:String;
			var params:Array;

			//clean tmp
			sql='DELETE FROM tmp_orders';
			sequence.push(prepareStatement(sql));
			sql='DELETE FROM tmp_print_group';
			sequence.push(prepareStatement(sql));

			//get max state by tech
			sql='INSERT INTO tmp_print_group(id, state)'+
				' SELECT pg.id, MAX(st.state)'+ 
				' FROM print_group pg'+
					' INNER JOIN tech_log tl ON pg.id=tl.print_group'+  
					' INNER JOIN config.sources s ON tl.src_id=s.id'+  
					' INNER JOIN config.src_type st ON s.type_id=st.id'+ 
				' WHERE pg.id=? AND st.state>pg.state'+  
				' GROUP BY pg.id, pg.sheet_num'+
				' HAVING COUNT(DISTINCT tl.sheet)=pg.sheet_num';
			params=[pgId];
			sequence.push(prepareStatement(sql,params));
			
			//set pg state
			sql='UPDATE print_group'+
				' SET state=(SELECT state FROM tmp_print_group t WHERE print_group.id=t.id), state_date = ?'
				' WHERE id IN (SELECT id FROM tmp_print_group)';
			var dt:Date=new Date();
			params=[dt];
			sequence.push(prepareStatement(sql,params));

			//log state
			sql='INSERT INTO state_log (order_id, pg_id, state, state_date)'+
				' SELECT pg.order_id, pg.id, pg.state, pg.state_date'+
				' FROM print_group pg'+
				' WHERE pg.id IN (SELECT id FROM tmp_print_group)';
			sequence.push(prepareStatement(sql));

			/*
			//forvard order state
			sql='INSERT INTO tmp_orders(id, state, state_date)'+
					' SELECT  pg.order_id, max(pg.state), ?'+
					' FROM print_group pg'+
					' WHERE pg.order_id IN (SELECT DISTINCT pg3.order_id FROM print_group pg3 INNER JOIN tmp_print_group t ON pg3.id=t.id)'+ 
					' AND NOT EXISTS(SELECT 1 FROM print_group pg1 WHERE pg.order_id=pg1.order_id AND pg.state>pg1.state)'+
					' GROUP BY pg.order_id';
			params=[dt];
			sequence.push(prepareStatement(sql,params));

			//remove if order state same or above
			sql='DELETE FROM tmp_orders'+
				' WHERE EXISTS (SELECT 1 FROM orders o WHERE o.id=tmp_orders.id AND o.state>=tmp_orders.state)';
			sequence.push(prepareStatement(sql));

			//TODO update & log
			*/
			executeSequence(sequence);
		}

		public function printPost(item:PrintGroup, labId:int):void{
			if(!item) return;
			item.state=OrderState.PRN_POST;
			item.destination=labId;
			var sequence:Array=[];
			var stmt:SQLStatement;
			var sql:String;
			var params:Array;
			//update print group
			sql='UPDATE print_group SET state=?, state_date=?, destination=? WHERE id=?';
			params=[item.state, item.state_date, item.destination, item.id];
			sequence.push(prepareStatement(sql,params));
			//log state
			sql='INSERT INTO state_log (order_id, pg_id, state, state_date) VALUES (?, ?, ?, ?)';
			params=[item.order_id, item.id, item.state, item.state_date];
			sequence.push(prepareStatement(sql,params));
			//upade order state
			sql='UPDATE orders SET state = ?, state_date = ? WHERE id = ? AND state != ?';
			params=[item.state, item.state_date, item.order_id, item.state];
			sequence.push(prepareStatement(sql,params));
			//log order state
			sql='INSERT INTO state_log ( order_id, state, state_date)'+
				' SELECT o.id, o.state, o.state_date'+
				' FROM orders o WHERE o.id = ? AND o.state = ? AND o.state_date = ?';
			params=[item.order_id, item.state, item.state_date];
			sequence.push(prepareStatement(sql,params));

			//start Sequence
			//addEventListener(SqlSequenceEvent.SQL_SEQUENCE_EVENT, onSequenceComplite);
			executeSequence(sequence);
		}
		/*
		private function onSequenceComplite(e:SqlSequenceEvent):void{
			removeEventListener(SqlSequenceEvent.SQL_SEQUENCE_EVENT, onSequenceComplite);
			if(e.result==SqlSequenceEvent.RESULT_COMLETED){
				dispatchEvent(new AsyncSQLEvent(AsyncSQLEvent.RESULT_COMLETED));
			}else{
				dispatchEvent(new AsyncSQLEvent(AsyncSQLEvent.RESULT_FAULT,0,0,null,e.error));
			}
		}
		*/

		//private var writePrintStateOrder:String; 
		public function writePrintState(item:PrintGroup):void{
			//TODO refactor to sequence
			if(!item) return;
			var sequence:Array=[];
			var stmt:SQLStatement;
			var sql:String;
			var subSql:String;
			var params:Array;
			var subParams:Array;

			//writePrintStateOrder=item.order_id;

			//update print group
			sql='UPDATE print_group SET state=?, state_date=?, destination=? WHERE id=?';
			params=[item.state, item.state_date, item.destination, item.id];
			sequence.push(prepareStatement(sql,params));
			//log state
			sql='INSERT INTO state_log (order_id, pg_id, state, state_date) VALUES (?, ?, ?, ?)';
			params=[item.order_id, item.id, item.state, item.state_date];
			sequence.push(prepareStatement(sql,params));

			//calc new order state
			sql='DELETE FROM tmp_print_group';
			sequence.push(prepareStatement(sql));
			//get min/max order state by pg
			sql='INSERT INTO tmp_print_group(id, state, state_max)'+
				' SELECT ?, IFNULL(MIN(pg.state),0), IFNULL(MAX(pg.state),0)'+ 
				' FROM print_group pg'+
				' WHERE pg.order_id=?';
			params=[item.order_id, item.order_id];
			sequence.push(prepareStatement(sql,params));
			//calc/set order state
			subSql='SELECT (CASE WHEN (state<? AND state_max<?) THEN state' +
					      ' CASE WHEN (state<?) THEN ?'+
					      ' CASE WHEN (state<?) THEN ?'+ 
					      ' ELSE ? END) as state'+       
					' FROM tmp_print_group t WHERE t.id=?';
			subParams=[OrderState.PRN_POST,OrderState.PRN_POST,
						OrderState.PRN_PRINT,OrderState.PRN_POST,
						OrderState.PRN_COMPLETE,OrderState.PRN_PRINT,
						OrderState.PRN_COMPLETE,
						item.order_id];
			sql='UPDATE orders SET state = ('+subSql+'), state_date = ? WHERE id = ? AND state !=('+subSql+')';
			params=subParams.concat();
			var dt:Date=new Date();
			params.push(dt);
			params.push(item.order_id);
			params=params.concat(subParams);
			sequence.push(prepareStatement(sql,params));
			//log sate
			sql='INSERT INTO state_log ( order_id, state, state_date)'+
				' SELECT o.id, o.state, o.state_date'+
				' FROM orders o WHERE o.id = ? AND o.state_date = ?';
			params=[item.order_id, dt];
			sequence.push(prepareStatement(sql,params));

			//start Sequence
			//addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onWritePrintGropPrint,false,int.MAX_VALUE);
			executeSequence(sequence);
		}
		/*
		private function onWritePrintGropPrint(e:AsyncSQLEvent):void{
			removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT, onWritePrintGropPrint);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				//ok - stop event & set check/set oredr state
				e.stopImmediatePropagation();
				var oDao:OrderDAO=new OrderDAO();
				oDao.addEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onWriteOrderPrint);
				oDao.checkSetPrintState(writePrintStateOrder);
			}else{
				//fault - kipp propagation
				writePrintStateOrder='';
			}
		}
		private function onWriteOrderPrint(e:AsyncSQLEvent):void{
			var oDao:OrderDAO= e.target as OrderDAO;
			if(oDao) oDao.removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onWriteOrderPrint);
			if(e.result==AsyncSQLEvent.RESULT_COMLETED){
				dispatchEvent(new AsyncSQLEvent(AsyncSQLEvent.RESULT_COMLETED));
			}else{
				dispatchEvent(new AsyncSQLEvent(AsyncSQLEvent.RESULT_FAULT,0,0,null,e.error));
			}
		}
		*/

		public function cancelPrint(items:Array, nameMap:Object=null):void{ // labName:String=''):void{
			if(!items || items.length==0){
				dispatchEvent(new AsyncSQLEvent(AsyncSQLEvent.RESULT_COMLETED));
				return;
			}
			var dt:Date=new Date();
			var sequence:Array=[];
			var stmt:SQLStatement;
			var sql:String;
			var params:Array;
			var pg:PrintGroup;
			//var o:Object;
			var labName:String;
			
			for each(pg in items){
				//pg = o as PrintGroup;
				if(pg){
					//set PrintGroup state
					sql='UPDATE print_group SET state=?, state_date=? WHERE id=?';
					params=[OrderState.PRN_CANCEL, dt, pg.id];
					sequence.push(prepareStatement(sql,params));
					//log PrintGroup state
					sql='INSERT INTO state_log (order_id, pg_id, state, state_date, comment) VALUES (?, ?, ?, ?, ?)';
					labName='';
					if(nameMap){
						labName=nameMap[pg.destination.toString()];
					}
					if(!labName) labName='id:'+pg.destination.toString();
					params=[pg.order_id, pg.id, OrderState.PRN_CANCEL, dt, 'Лаборатория: '+labName];
					sequence.push(prepareStatement(sql,params));
					//set order state
					sql='UPDATE orders SET state = ?, state_date = ? WHERE id = ? AND state != ?';
					params=[OrderState.PRN_POST, dt, pg.order_id, OrderState.PRN_POST];
					sequence.push(prepareStatement(sql,params));
					//log order state
					sql='INSERT INTO state_log ( order_id, state, state_date)'+
						' SELECT o.id, o.state, o.state_date'+
						' FROM orders o WHERE o.id = ? AND o.state = ? AND o.state_date = ?';
					params=[pg.order_id, OrderState.PRN_POST, dt];
					sequence.push(prepareStatement(sql,params));
				}
			}

			//start Sequence
			//addEventListener(SqlSequenceEvent.SQL_SEQUENCE_EVENT, onSequenceComplite);
			executeSequence(sequence);
		}

		
		override protected function processRow(o:Object):Object{
			var a:PrintGroup = new PrintGroup();
			fillRow(o,a);
			//don't set before a.state, u'l lost actual state_date
			a.state_date=new Date(o.state_date);
			return a;
		}
	}
}