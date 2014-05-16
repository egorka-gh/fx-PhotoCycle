package com.photodispatcher.model.dao{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.AttrJsonMap;
	import com.photodispatcher.model.Order;
	import com.photodispatcher.model.OrderState;
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.PrintGroupFile;
	import com.photodispatcher.model.Source;
	import com.photodispatcher.model.Suborder;
	
	import flash.data.SQLStatement;
	import flash.globalization.DateTimeStyle;
	
	import mx.collections.ArrayCollection;
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;
	import spark.formatters.DateTimeFormatter;

	public class OrderDAO extends BaseDAO{

		override protected function processRow(o:Object):Object{
			var a:Order = new Order();
			fillRow(o,a);
			//don't set before a.state, u'l lost actual state_date
			a.state_date= new Date(o.state_date);

			return a;
		}

		public function setLocalFolder(id:String, localFolder:String):void{
			var sql:String='UPDATE orders SET local_folder = ? WHERE id = ?';
			var params:Array=[];
			params.push(localFolder);
			params.push(id);
			execute(sql,params);
		}

		public function setState(id:String, newState:int):void{
			asyncFaultMode=FAULT_REPIT;
			//start Sequence
			executeSequence(setStateSequence(id, newState));
		}
		private function setStateSequence(id:String, newState:int):Array{
			var stateToLog:int; 
			var idToLog:String; 
			var sequence:Array=[];
			stateToLog=newState;
			idToLog=id;
			var sql:String='UPDATE orders SET state = ?, state_date = ? WHERE id = ? AND state != ?';
			var params:Array=[];
			var dt:Date=new Date();
			params.push(newState);
			params.push(dt);
			params.push(id);
			params.push(newState);
			sequence.push(prepareStatement(sql,params));
			
			sql='INSERT INTO state_log ( order_id, state, state_date)'+
				' SELECT o.id, o.state, o.state_date'+
				' FROM orders o WHERE o.id = ? AND o.state = ? AND o.state_date = ?';
			params=[id, newState, dt];
			sequence.push(prepareStatement(sql,params));
			return sequence;
		}
		
		public function addManual(order:Order):void{
			if(!order) return;
			var sql:String='INSERT INTO orders (id, source, src_id, state, state_date, ftp_folder, fotos_num)' + 
							' SELECT ?, ?, ?, ?, ?, ?, ? WHERE NOT EXISTS(SELECT 1 from orders o WHERE o.id=?)';
			var params:Array=[order.id,
								order.source,
								order.src_id,
								order.state,
								order.state_date,
								order.ftp_folder,
								order.fotos_num,
								order.id];
			execute(sql,params);
		}
		
		public function setStateBatch(newState:int,orderIds:Array, updateGroups:Boolean=true):void{
			if(!orderIds || orderIds.length==0) return;
			var id:String;
			var sequence:Array=[];
			var stmt:SQLStatement;
			var sql:String;
			var params:Array;
			var dt:Date=new Date();
			for each (var o:Object in orderIds){
				id=o as String;
				if(id){
					//order
					sql='UPDATE orders SET state = ?, state_date = ? WHERE id = ? AND state != ?';
					params=[newState, dt, id, newState];
					sequence.push(prepareStatement(sql,params));
					
					sql='INSERT INTO state_log ( order_id, state, state_date)'+
						' SELECT o.id, o.state, o.state_date'+
							' FROM orders o WHERE o.id = ? AND o.state = ? AND o.state_date = ?';
					params=[id, newState, dt];
					sequence.push(prepareStatement(sql,params));

					//print groups
					if(updateGroups){
						sql='UPDATE print_group SET state = ?, state_date = ? WHERE order_id = ? AND state != ?;';
						params=[newState, dt, id, newState];
						sequence.push(prepareStatement(sql,params));
						
						sql='INSERT INTO state_log ( order_id, pg_id, state, state_date)'+
							' SELECT pg.order_id, pg.id, pg.state, pg.state_date'+
								' FROM print_group pg WHERE pg.order_id = ? AND pg.state = ? AND pg.state_date = ?';
						params=[id, newState, dt];
						sequence.push(prepareStatement(sql,params));
					}
				}
			}
			//start Sequence
			executeSequence(sequence);
		}

		/*
		public function checkSetPrintState(id:String):int{
			//TODO refactor to sequence
			var order:Order;
			var osDao:OrderStateDAO=new OrderStateDAO();
			var pgState:OrderState=osDao.getOrderStateByPrintGroups(id,true);
			if(pgState==null){
				dispatchEvent(new AsyncSQLEvent(AsyncSQLEvent.RESULT_FAULT_LOCKED));
				return 0;
			}
			var newState:int;
			if (pgState && pgState.id){
				if (pgState.id<OrderState.PRN_PRINT){
					newState=OrderState.PRN_POST;
				}else if (pgState.id<OrderState.PRN_COMPLETE){
					newState=OrderState.PRN_PRINT;
				}else{
					newState=OrderState.PRN_COMPLETE;
				}
				setState(id,newState);
			}
			return newState;
		}
		*/
		
		public function getItem(id:String, extraInfo:Boolean=false):Order{
			var sql:String='SELECT o.*, s.name source_name, os.name state_name';
			if(extraInfo) sql+=', oei.endpaper, oei.interlayer, oei.calc_type, oei.cover, oei.format, oei.corner_type, oei.kaptal';
			sql=sql+		' FROM orders o'+
							' INNER JOIN config.order_state os ON o.state = os.id'+
							' INNER JOIN config.sources s ON o.source = s.id';
			if(extraInfo) sql+=' LEFT OUTER JOIN order_extra_info oei ON o.id=oei.id';
			sql+=			' WHERE o.id=?';
			runSelect(sql, [id]);
			return item as Order;
		}

		public function findeById(id:String):ArrayCollection{
			if(!id) return new ArrayCollection();
			id='%'+id+'%';
			var sql:String='SELECT o.*, s.name source_name, os.name state_name, s.code source_code'+
				' FROM orders o'+
				' INNER JOIN config.order_state os ON o.state = os.id'+
				' INNER JOIN config.sources s ON o.source = s.id'+
				' WHERE o.id LIKE ?';
			runSelect(sql, [id]);
			
			return itemsList;
		}

		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();

			var col:GridColumn= new GridColumn('source_name');
			col.headerText='Источник'; result.addItem(col);
			col= new GridColumn('state_name'); col.headerText='Статус'; result.addItem(col); 
			col= new GridColumn('id'); result.addItem(col);
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
			col= new GridColumn('src_date'); col.headerText='Размещен'; col.formatter=fmt;  result.addItem(col);
			fmt=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
			col= new GridColumn('state_date'); col.headerText='Дата статуса'; col.formatter=fmt;  result.addItem(col);
			col= new GridColumn('ftp_folder'); col.headerText='Ftp Папка'; result.addItem(col);
			col= new GridColumn('fotos_num'); col.headerText='Кол фото'; result.addItem(col);
			return result;
		}

		public static function shortGridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			
			col= new GridColumn('source_name'); col.headerText='Источник'; result.addItem(col);
			col= new GridColumn('id'); result.addItem(col);
			col= new GridColumn('state_name'); col.headerText='Статус'; result.addItem(col); 
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
			col= new GridColumn('state_date'); col.headerText='Дата статуса'; col.formatter=fmt;  result.addItem(col);
			col= new GridColumn('ftp_folder'); col.headerText='Ftp Папка'; result.addItem(col);
			return result;
		}

		public function findAll(source:int=-1, stateFrom:int=-1, stateTo:int=-1):ArrayCollection{
			var a:Array=findAllArray(source, stateFrom, stateTo);
			if(a){
				return new ArrayCollection(a);
			}else{
				return null;
			}
		}

		public function findAllArray(source:int=-1, stateFrom:int=-1, stateTo:int=-1):Array{
			var where:String='';
			var sql:String;
			var params:Array;
			if(source!=-1){
				if(where) where=where+' AND';
				where=where+' o.source =?';
				if(!params) params=new Array();
				params.push(source);
			}
			if(stateFrom!=-1){
				if(where) where=where+' AND';
				where=where+' o.state>=?';
				if(!params) params=new Array();
				params.push(stateFrom);
			}
			if(stateTo!=-1){
				if(where) where=where+' AND';
				where=where+' o.state<?';
				if(!params) params=new Array();
				params.push(stateTo);
			}
			
			if(where) where=' WHERE'+where;
			sql='SELECT o.*, s.name source_name, os.name state_name'+
				' FROM orders o'+
				' INNER JOIN config.order_state os ON o.state = os.id'+
				' INNER JOIN config.sources s ON o.source = s.id'+
				where+
				' ORDER BY o.src_date';
			runSelect(sql,params);
			return itemsArray;
		}

		public function cleanUp(order:Order):void{
			if(!order) return;
			var sequence:Array=[];
			var stmt:SQLStatement;
			
			var sql:String="DELETE FROM print_group_file WHERE print_group LIKE '"+order.id+"' || '%'";
			sequence.push(prepareStatement(sql)); 
			
			sql="DELETE FROM print_group WHERE order_id = ?";
			sequence.push(prepareStatement(sql,[order.id]));

			sql="DELETE FROM order_extra_info WHERE id = ?";
			sequence.push(prepareStatement(sql,[order.id]));

			sql="DELETE FROM order_extra_info WHERE id IN (SELECT id FROM suborders WHERE order_id = ?)";
			sequence.push(prepareStatement(sql,[order.id]));

			sql="DELETE FROM order_extra_info WHERE id like ? || '.%'";
			sequence.push(prepareStatement(sql,[order.id]));

			sql="DELETE FROM suborders WHERE order_id = ?";
			sequence.push(prepareStatement(sql,[order.id]));
			
			sql='UPDATE orders SET state = ?, state_date = ? WHERE id = ?';
			var params:Array=[OrderState.WAITE_FTP, new Date(), order.id];
			sequence.push(prepareStatement(sql,params));

			sql='INSERT INTO state_log (order_id, pg_id, state, state_date, comment)' +
				' VALUES (?,?,?,?,?)';
			params=[order.id, '', OrderState.WAITE_FTP, new Date(),'reset'];
			sequence.push(prepareStatement(sql,params));
			//start Sequence
			//addEventListener(SqlSequenceEvent.SQL_SEQUENCE_EVENT, onSequenceComplite);
			executeSequence(sequence);
		}

		public function createChilds(order:Order):void{
			if(!order) return;
			var sequence:Array=[];
			var stmt:SQLStatement;
			var o:Object; var oo:Object;
			var pg:PrintGroup;
			var pgf:PrintGroupFile;
			var i:int=1;
			//var pg_id:String;
			var sql:String;
			var params:Array;
			var dt:Date=new Date();
			var so:Suborder;
			
			if(order.state<OrderState.CANCELED) order.state=order.is_preload?OrderState.PRN_WAITE_ORDER_STATE:OrderState.PRN_WAITE;
			
			//fill sub orders
			if(order.suborders){
				for each(so in order.suborders){
					sql='INSERT INTO suborders (id, order_id, src_type, sub_id, ftp_folder, prt_qty, proj_type, state, state_date)' +
						' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)';
					params=[so.id,
							order.id,
							so.src_type,
							so.sub_id,
							so.ftp_folder,
							so.prt_qty,
							so.proj_type,
							so.state,
							dt];
					sequence.push(prepareStatement(sql,params));
					//add sub orders extra info
					if(so.endpaper || so.interlayer || so.cover || so.format || so.corner_type || so.kaptal){
						sql='INSERT OR IGNORE INTO order_extra_info (id, endpaper, interlayer, calc_type, cover, format, corner_type, kaptal)' +
							' VALUES (?,?,?,?,?,?,?,?)';
						params=[so.id, so.endpaper, so.interlayer, so.calc_type, so.cover, so.format, so.corner_type, so.kaptal];
						sequence.push(prepareStatement(sql,params));
					}
				}
			}

			//fill print groups
			if(order.printGroups){
				for each(o in order.printGroups){
					pg= o as PrintGroup;
					if(pg){
						if(pg.state<OrderState.CANCELED) pg.state=order.state;
						//create print group
						sql='INSERT INTO print_group (id, order_id, state, state_date, width, height, frame, paper, path, correction, cutting, file_num,'+
													' book_type, book_part, book_num, sheet_num, is_pdf, is_duplex, prints)' +
													' VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)';
						params=[pg.id,
								order.id,
								pg.state,
								dt,
								pg.width,
								pg.height,
								pg.frame,
								pg.paper,
								pg.path,
								pg.correction,
								pg.cutting,
								pg.file_num,
								pg.book_type,
								pg.book_part,
								pg.book_num,
								pg.sheet_num,
								pg.is_pdf?1:0,
								pg.is_duplex?1:0,
								pg.prints];
						sequence.push(prepareStatement(sql,params));

						//log print group state
						sql='INSERT INTO state_log (order_id, pg_id, state, state_date)' +
										  ' VALUES (?,?,?,?)';
						params=[order.id, pg.id, order.state, dt];
						sequence.push(prepareStatement(sql,params));

						if(pg.getFiles() && pg.getFiles().length>0){
							for each(oo in pg.getFiles()){
								pgf= oo as PrintGroupFile;
								if(pgf){
									//create PrintGroupFile
									sql='INSERT INTO print_group_file (print_group, file_name, prt_qty, book_num, page_num, caption)' +
										' VALUES (?,?,?,?,?,?)';
									params=[pg.id, pgf.file_name, pgf.prt_qty, pgf.book_num, pgf.page_num, pgf.caption];
									sequence.push(prepareStatement(sql,params));
								}
							}
						}
						i++;
					}
				}
			}
			
			//add extra info
			if(order.calc_type || order.endpaper || order.interlayer || order.cover || order.format || order.corner_type || order.kaptal){
				sql='INSERT OR IGNORE INTO order_extra_info (id, endpaper, interlayer, calc_type, cover, format, corner_type, kaptal)' +
					' VALUES (?,?,?,?,?,?,?,?)';
				params=[order.id, order.endpaper, order.interlayer, order.calc_type, order.cover, order.format, order.corner_type,order.kaptal];
				sequence.push(prepareStatement(sql,params));
			}

			
			//set order state
			sql='UPDATE orders SET state = ?, state_date = ?, data_ts = ? WHERE id = ?';
			params=[order.state, dt, order.data_ts, order.id];
			sequence.push(prepareStatement(sql,params));

			//log order state
			sql='INSERT INTO state_log (order_id, state, state_date)' +
							' VALUES (?,?,?)';
			params=[order.id, order.state, dt];
			sequence.push(prepareStatement(sql,params));

			//start Sequence
			//addEventListener(SqlSequenceEvent.SQL_SEQUENCE_EVENT, onSequenceComplite);
			executeSequence(sequence);
		}

		public function sync(source:Source,raw:Array):void{
			var sequence:Array=[];
			var stmt:SQLStatement;
			if(!source || !raw || raw.length==0){
				dispatchEvent(new AsyncSQLEvent(AsyncSQLEvent.RESULT_COMLETED));
				return;
			}
			//get jsonMap
			//var jmDao:AttrJsonMapDAO=new AttrJsonMapDAO();
			//var jMap:Array=jmDao.getOrderMapBySourceType(source.type_id);
			var jMap:Array=AttrJsonMapDAO.getOrderJson(source.type_id);
			if(!jMap){
				dispatchEvent(new AsyncSQLEvent(AsyncSQLEvent.RESULT_FAULT_LOCKED,0,0,null,'Ошибка чтения attr_json_map. Данные блокированы.'));
				return;
			}
			//clear Temp Tables
			sequence.push(prepareStatement('DELETE FROM tmp_orders'));
			//src_id's which still in responce   
			//var keepOrders:Array=new Array();
			
			//increment source sync
			source.incrementSync();
			//sync moved to data.sources_sync (to prevent config lock)
			//sequence.push(prepareStatement('UPDATE config.sources SET sync=? WHERE id=?',[source.sync, source.id]));
			sequence.push(prepareStatement('UPDATE sources_sync SET sync=? WHERE id=?',[source.sync, source.id]));
			//insert if new source
			sequence.push(prepareStatement('INSERT INTO sources_sync (id, sync)' + 
											' SELECT ?, ? WHERE NOT EXISTS(SELECT 1 from sources_sync ss WHERE ss.id=?)',[source.id, source.sync, source.id]));

			//add new records
			trace('OrderDAO.sync. Add new records');
			for each (var jo:Object in raw){
				if(jo){
					//build sql
					var params:Array=[];
					var src_id:int;
					var sql:String='';
					var subSql:String='';
					sql='source, state, state_date';
					subSql='?, ?, ?';
					params.push(source.id);
					params.push(OrderState.WAITE_FTP);
					params.push(new Date());
					for each(var o:Object in jMap){
						var ajm:AttrJsonMap=o as AttrJsonMap;
						if(ajm && ajm.persist){
							//isert fields list
							if(sql) sql+=',';
							sql+=(' '+ajm.field);
							//params array
							var val:Object=getRawVal(ajm.json_key, jo);
							if(ajm.field.indexOf('date')!=-1){
								//convert date
								var d:Date=parseDate(val.toString());
								params.push(d);
							}else{
								params.push(val);
							}
							//store src_id val 4 WHERE
							if(ajm.field=='src_id'){
								//removes subNumber (-#) for fotokniga
								//TODO build suborder ???
								src_id=cleanId(val as String);
							}
							//store src_id val 4 subsequent processing
							//keepOrders.push(src_id);
							
							if(subSql) subSql+=',';
							subSql+=' ?';
						}
					}
					//add sync
					sql+=', sync';
					params.push(source.sync);
					subSql+=', ?';
					//add id
					sql+=', id';
					params.push(source.id.toString()+'_'+src_id.toString());
					subSql+=', ?';
					
					//sql='INSERT OR IGNORE INTO orders ('+sql+') VALUES ('+subSql+')';
					sql='INSERT INTO tmp_orders ('+sql+') VALUES ('+subSql+')';
					//executeUpdate(sql,params);
					sequence.push(prepareStatement(sql,params));
				}
			}
			//search new
			//update orders set sync=1 where not exists(select 1 from orders2 as o2 where o2.id=orders.id)
			//update orders set sync=ifnull((select 0 from orders2 as o2 where o2.id=orders.id),1)
			sql='UPDATE tmp_orders SET is_new=IFNULL((SELECT 0 FROM orders WHERE orders.id=tmp_orders.id),1)';
			sequence.push(prepareStatement(sql));
			//isert new
			sql='INSERT INTO orders (id, source, src_id, src_date, state, state_date, ftp_folder, fotos_num, sync, is_preload, data_ts)' +
				' SELECT id, source, src_id, src_date, state, state_date, ftp_folder, fotos_num, sync, is_preload, data_ts' +
			  	  ' FROM tmp_orders WHERE is_new=1';
			sequence.push(prepareStatement(sql));
			//log state
			sql='INSERT INTO state_log (order_id, state, state_date)' +
				' SELECT id, state, state_date' +
				' FROM tmp_orders WHERE is_new=1';
			sequence.push(prepareStatement(sql));
			//update sync
			sql='UPDATE orders SET sync=? WHERE orders.id IN (SELECT id FROM tmp_orders WHERE is_new!=1)';
			sequence.push(prepareStatement(sql,[source.sync]));
			
			//check/process preload
			//log printgroup state
			sql='INSERT INTO state_log (order_id, pg_id, state, state_date)' +
				' SELECT pg.order_id, pg.id, ?, ?' +
				' FROM print_group pg WHERE pg.state = ? AND pg.order_id IN (SELECT t.id FROM tmp_orders t WHERE t.is_preload=0 AND t.is_new!=1)';
			sequence.push(prepareStatement(sql,[OrderState.PRN_WAITE, new Date(),OrderState.PRN_WAITE_ORDER_STATE]));
			//update printgroup state/preload
			sql='UPDATE print_group SET state = ?, state_date = ? WHERE state = ? AND order_id IN (SELECT id FROM tmp_orders t WHERE t.is_preload=0 AND t.is_new!=1)';
			sequence.push(prepareStatement(sql,[OrderState.PRN_WAITE, new Date(),OrderState.PRN_WAITE_ORDER_STATE]));
			//log order state
			sql='INSERT INTO state_log (order_id, state, state_date)' +
				' SELECT o.id, ?, ?' +
				' FROM orders o WHERE o.state = ? AND o.id IN (SELECT id FROM tmp_orders t WHERE t.is_preload=0 AND t.is_new!=1)';
			sequence.push(prepareStatement(sql,[OrderState.PRN_WAITE, new Date(),OrderState.PRN_WAITE_ORDER_STATE]));
			//update order state/preload
			sql='UPDATE orders SET state = ?, state_date = ?, is_preload=0 WHERE state = ? AND id IN (SELECT id FROM tmp_orders t WHERE t.is_preload=0 AND t.is_new!=1)';
			sequence.push(prepareStatement(sql,[OrderState.PRN_WAITE, new Date(),OrderState.PRN_WAITE_ORDER_STATE]));
			//update orders preload
			sql='UPDATE orders SET is_preload=0 WHERE is_preload=1 AND id IN (SELECT id FROM tmp_orders t WHERE t.is_preload=0 AND t.is_new!=1)';
			sequence.push(prepareStatement(sql));
			
			//log canceled state
			sql='INSERT INTO state_log (order_id, state, state_date)' +
				' SELECT id, ?, ? FROM orders WHERE source=? AND state BETWEEN ? AND ? AND sync!=?';
			params=new Array();
			params.push(OrderState.CANCELED);
			params.push(new Date());
			params.push(source.id);
			params.push(OrderState.WAITE_FTP);
			params.push(OrderState.PRN_WAITE);
			params.push(source.sync);
			sequence.push(prepareStatement(sql,params));
			//cancel print groups
			sql='UPDATE print_group SET state = ?, state_date = ? WHERE order_id IN'+
				' (SELECT id FROM orders WHERE source=? AND state BETWEEN ? AND ? AND sync!=?)';
			params=new Array();
			params.push(OrderState.CANCELED);
			params.push(new Date());
			params.push(source.id);
			params.push(OrderState.WAITE_FTP);
			params.push(OrderState.PRN_WAITE);
			params.push(source.sync);
			sequence.push(prepareStatement(sql,params));
			//cancel orders if not in sync
			sql='UPDATE orders SET state=?, state_date=? WHERE source=? AND state BETWEEN ? AND ? AND sync!=?';
			params=new Array();
			params.push(OrderState.CANCELED);
			params.push(new Date());
			params.push(source.id);
			params.push(OrderState.WAITE_FTP);
			params.push(OrderState.PRN_WAITE);
			params.push(source.sync);
			sequence.push(prepareStatement(sql,params));
			
			//finde reload candidate by project data time
			sql='UPDATE tmp_orders SET reload=1 WHERE data_ts IS NOT NULL AND EXISTS(SELECT 1 FROM orders WHERE orders.id=tmp_orders.id AND orders.data_ts IS NOT NULL AND orders.data_ts!=tmp_orders.data_ts AND orders.state BETWEEN ? AND ?)';
			params=[OrderState.PRN_WAITE_ORDER_STATE, OrderState.PRN_WAITE];
			sequence.push(prepareStatement(sql,params));
			//clean orders 4 reload
			//clean files
			sql='DELETE FROM print_group_file WHERE print_group IN (SELECT pg.id FROM tmp_orders t INNER JOIN print_group pg ON pg.order_id=t.id WHERE t.reload=1)';
			sequence.push(prepareStatement(sql));
			//clean print_group
			sql='DELETE FROM print_group WHERE order_id IN (SELECT id FROM tmp_orders t WHERE t.reload=1)';
			sequence.push(prepareStatement(sql));
			//clean order extra_info
			sql='DELETE FROM order_extra_info WHERE id IN (SELECT id FROM tmp_orders t WHERE t.reload=1)';
			sequence.push(prepareStatement(sql));
			//clean suborder extra_info
			sql='DELETE FROM order_extra_info WHERE id IN (SELECT so.id FROM tmp_orders t INNER JOIN suborders so ON so.order_id=t.id WHERE t.reload=1)';
			sequence.push(prepareStatement(sql));
			//clean lost extra_info
			sql="DELETE FROM order_extra_info WHERE EXISTS (SELECT * FROM tmp_orders t WHERE t.reload=1 AND order_extra_info.id LIKE t.id || '.%' )";
			sequence.push(prepareStatement(sql));
			//clean suborder
			sql='DELETE FROM suborders WHERE order_id IN (SELECT id FROM tmp_orders t WHERE t.reload=1)';
			sequence.push(prepareStatement(sql));
			//reset order state
			sql='UPDATE orders SET state = ?, state_date = ? WHERE id IN (SELECT id FROM tmp_orders t WHERE t.reload=1)';
			params=[OrderState.WAITE_FTP, new Date()];
			sequence.push(prepareStatement(sql,params));
			//log
			sql='INSERT INTO state_log (order_id, state, state_date, comment)' +
				' SELECT id, ?, ?, ?  FROM tmp_orders t WHERE t.reload=1';
			params=[OrderState.WAITE_FTP, new Date(), 'перезагрузка, заказ изменен на сайте'];
			sequence.push(prepareStatement(sql,params));
						
			//set project data time 
			sql="UPDATE orders SET data_ts=(SELECT tt.data_ts FROM tmp_orders tt WHERE tt.id=orders.id)" + 
				" WHERE EXISTS (SELECT 1 FROM tmp_orders t WHERE t.id=orders.id AND t.data_ts IS NOT NULL AND t.is_new!=1 AND t.data_ts!=ifnull(orders.data_ts,''))";
			sequence.push(prepareStatement(sql));
			

			//addEventListener(SqlSequenceEvent.SQL_SEQUENCE_EVENT, onSyncComplite);
			executeSequence(sequence);
		}

		public function startExtraStateByTech(orderId:String,tech_type:int, tech_point:int=0):void{
			var sequence:Array=[];
			var stmt:SQLStatement;
			var sql:String;
			var params:Array;
			var dt:Date=new Date();

			//set order extra state
			sql='INSERT OR IGNORE INTO order_extra_state (id, state, start_date)'+
				' SELECT ?, st.state, ? FROM config.src_type st WHERE st.id=?';
			params=[orderId, dt, tech_type];
			sequence.push(prepareStatement(sql,params));
			
			if(tech_point){
				//log operation start time
				sql='INSERT INTO tech_log (print_group, sheet, src_id, log_date) VALUES (?,?,?,?)';
				params=[orderId+'_1', 0, tech_point, dt];
				sequence.push(prepareStatement(sql,params));
			}

			executeSequence(sequence);

		}

		public function prolongExtraState(orderId:String, state:int, comment:String=null):void{
			var sequence:Array=[];
			var stmt:SQLStatement;
			var sql:String;
			var params:Array;
			var dt:Date=new Date();
			
			//set order extra state
			sql='INSERT OR IGNORE INTO order_exstate_prolong (id, state, state_date, comment)'+
				' VALUES (?, ?, ?, ?)';
			params=[orderId, state, dt, comment];
			sequence.push(prepareStatement(sql,params));

			executeSequence(sequence);
		}

		public function setExtraStateByTech(orderId:String,tech_type:int, tech_point:int=0):void{
			var sequence:Array=[];
			var stmt:SQLStatement;
			var sql:String;
			var params:Array;
			var dt:Date=new Date();
			
			//set order extra state end date
			sql='UPDATE order_extra_state'+
				' SET state_date=?'+
				' WHERE id=? AND state=(SELECT st.state FROM config.src_type st WHERE st.id=?)';
			params=[dt, orderId, tech_type];
			sequence.push(prepareStatement(sql,params));
			
			//insert if not exists
			sql='INSERT OR IGNORE INTO order_extra_state (id, state, start_date, state_date)'+
				' SELECT ?, st.state, ?, ? FROM config.src_type st WHERE st.id=?';
			params=[orderId, dt, dt, tech_type];
			sequence.push(prepareStatement(sql,params));

			//set order state
			sql='UPDATE orders'+
				' SET state=(SELECT st.state FROM config.src_type st WHERE st.id=?), state_date = ?'+
				' WHERE id=?'+
				' AND EXISTS (SELECT 1 FROM config.src_type st WHERE st.id=? AND st.book_part=0)';
			params=[tech_type, dt, orderId, tech_type];
			sequence.push(prepareStatement(sql,params));
			
			//log state
			sql='INSERT INTO state_log (order_id, pg_id, state, state_date)'+
				' SELECT ?, ?, st.state, ? FROM config.src_type st WHERE st.id=?';
			params=[orderId, orderId+'_1', dt, tech_type];
			sequence.push(prepareStatement(sql,params));

			//set pg state
			//TODO fbook? will set all pg's (need some link between suborder-pg)
			sql='UPDATE print_group'+
				' SET state=(SELECT st.state FROM config.src_type st WHERE st.id=?), state_date = ?'+
				' WHERE id IN' +
				' (SELECT pg.id'+
				 ' FROM config.src_type st'+
				  ' INNER JOIN print_group pg ON pg.order_id=? AND pg.book_part=st.book_part'+
				 ' WHERE st.id=?)';
			params=[tech_type, dt, orderId, tech_type];
			sequence.push(prepareStatement(sql,params));

			if(tech_point){
				//log operation end time
				sql='INSERT INTO tech_log (print_group, sheet, src_id, log_date) VALUES (?,?,?,?)';
				params=[orderId+'_1', 0, tech_point, dt];
				sequence.push(prepareStatement(sql,params));
			}
			
			executeSequence(sequence);
		}

		private function getRawVal(key:String, jo:Object):Object{
			if(!key) return null; 
			var path:Array=key.split('.');
			var value:Object=jo;
			for each(var subkey:String in path){
				if (value.hasOwnProperty(subkey)){
					value=value[subkey];
				}else{
					return null;
				}
			}
			if (value!=jo){
				return value;
			}else{
				return null;
			}
		}
		private function parseDate(s:String):Date{
			//json date, parsed as "2012-05-17 15:52:08"
			var d:Date=new Date();
			if(!s) return d;
			var a1:Array=s.split(' ');
			if(!a1 || a1.length!=2) return d;
			var a2:Array=(a1[0] as String).split('-');
			if(!a2 || a2.length!=3) return d;
			var a3:Array=(a1[1] as String).split(':');
			if(!a3 || a3.length<3) return d;
			return new Date(a2[0],a2[1]-1,a2[2],a3[0],a3[1],a3[2]);
		}
		
		private function cleanId(src_id:String):int{
			//removes subNumber (-#) for fotokniga
			var a:Array=src_id.split('-');
			var sId:String;
			if(!a || a.length==0){
				sId=src_id;
			}else{
				sId=a[0];
			}
			return int(sId);
		}

		public function getExtraInfoByPG(pgId:String, silent:Boolean=false):Order{
			var result:Order= new Order();
			result.id=PrintGroup.orderIdFromId(pgId);
			
			var sql:String='SELECT oei.*, pg.book_type'+
							' FROM print_group pg'+
							' INNER JOIN order_extra_info oei ON oei.id=pg.order_id'+
							' WHERE pg.id=?';
			sql+=' UNION ALL';
			sql= sql +' SELECT oei.*, pg.book_type'+  
						' FROM print_group pg'+
						' INNER JOIN suborders so ON pg.order_id=so.order_id AND pg.path=so.ftp_folder'+
						' INNER JOIN order_extra_info oei ON oei.id=so.id'+
						' WHERE pg.id=?';
			runSelect(sql, [pgId,pgId],silent);
			
			if(!lastResult) return null;
			if(lastResult.length==0) return result;
			return processRow(lastResult[0]) as Order;
		}

	}
}