package com.photodispatcher.model.dao{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.model.DBRecord;
	import com.photodispatcher.util.DebugUtils;
	import com.photodispatcher.view.ErrorPopup;
	import com.photodispatcher.view.ModalPopUp;
	
	import flash.data.SQLConnection;
	import flash.data.SQLResult;
	import flash.data.SQLStatement;
	import flash.data.SQLTransactionLockType;
	import flash.errors.SQLError;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.SQLErrorEvent;
	import flash.events.SQLEvent;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	import flash.utils.describeType;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Alert;
	import mx.managers.CursorManager;
	
	import spark.components.gridClasses.GridColumn;
	
	[Event(name="asyncSQLEvent", type="com.photodispatcher.event.AsyncSQLEvent")]
	[Event(name="sqlSequenceEvent", type="com.photodispatcher.event.SqlSequenceEvent")]
	[Event(name="complete", type="flash.events.Event")]
	public class BaseDAO extends EventDispatcher{
		public static const RESULT_COMLETED:int=0;
		public static const RESULT_FAULT:int=1;
		public static const RESULT_FAULT_LOCKED:int=2;

		public static const FAULT_IGNORE:int=0;
		public static const FAULT_REPIT:int=1;

		private static const TRACE_DEBUG:Boolean=false;
		
		private static const TIMEOUT_MIN:int=300;
		private static const TIMEOUT_MAX:int=1000;
		public static var MAX_WAITE:int=60000;

		[ArrayElementType("com.photodispatcher.model.dao.TransactionUnit")]
		private static var queue:Array=[];
		
		private static var _isRunning:Boolean=false;
		[Bindable]
		public static function set isBusy(value:Boolean):void{
			_isRunning=value;
			if(_isRunning){
				CursorManager.setBusyCursor();
			}else{
				CursorManager.removeBusyCursor();
			}
		}
		public static function get isBusy():Boolean{
			return _isRunning;
		}
		
		private static var connection:SQLConnection;
		
		/****************** static *****************************/

		public static function write(dao:BaseDAO, sequence:Array):void{
			if(!dao) return;
			if(!sequence || sequence.length==0){
				//dao.writeComplited vs err
				dao.executeResult(RESULT_COMLETED,0,0);
			}
			if(!connection) connection = Context.getAttribute("asyncConnection");
			if(!connection || !connection.connected){
				//dao.writeComplited vs err
				dao.executeResult(RESULT_FAULT,0,0,'Нет подключения к базе данных');
			}
			var tu:TransactionUnit= new TransactionUnit(dao, sequence, TransactionUnit.TYPE_WRITE);
			queue.push(tu);
			flushQueue();
		}
		
		private static function flushQueue():void{
			if(isBusy) return;
			runNext();
		}
		
		private static function runNext(resetWait:Boolean=true):void{
			if(resetWait) wait=0;
			attempt=0;
			resultId=0;
			resultRows=0;
			resultData=null;

			if(queue.length==0){
				//complited
				isBusy=false;
				return;
			}
			isBusy=true;
			if(TRACE_DEBUG) trace('baseDao attempt to start transaction; wait:'+wait.toString());
			try{
				connection.addEventListener(SQLEvent.BEGIN, onBegin);
				connection.addEventListener(SQLErrorEvent.ERROR, onBeginErr);
				connection.begin(SQLTransactionLockType.IMMEDIATE);
			}catch (error:Error){
				//some problem vs connection
				//complite each item in Queue vs err
				lastErrMsg=error.message;
				var tu:TransactionUnit=getCurrentUnit(true);
				while(tu){
					if(tu.type==TransactionUnit.TYPE_WRITE){
						tu.dao.executeResult(RESULT_FAULT,0,0,error.message);
					}
					tu=getCurrentUnit(true);
				}
				isBusy=false;
			}
		}

		private static var sequenceIdx:int;

		private static function onBegin(event:SQLEvent):void{
			connection.removeEventListener(SQLEvent.BEGIN, onBegin);
			connection.removeEventListener(SQLErrorEvent.ERROR, onBeginErr);
			if(TRACE_DEBUG) trace('baseDao transaction started');
			
			//run sequence
			sequenceIdx=0;
			nextSequenceItem();
		}
		private static var resultId:int;
		private static var resultRows:int;
		private static var resultData:Array;
		private static function nextSequenceItem():void{
			if(sequenceIdx>=getCurrentUnit().sequence.length){
				if(TRACE_DEBUG) trace('baseDao sequence completed');
				//completed
				//commit
				connection.addEventListener(SQLEvent.COMMIT, onCommit);
				connection.addEventListener(SQLErrorEvent.ERROR, onCommitErr);
				if(connection.inTransaction){
					connection.commit();
				}else{
					onCommit(null);
				}
				return;
			}
			lastErr=0;
			lastErrMsg='';
			var stmt:SQLStatement=getCurrentUnit().sequence[sequenceIdx] as SQLStatement;
			stmt.sqlConnection = connection;
			stmt.addEventListener(SQLEvent.RESULT, seqItemResult);
			stmt.addEventListener(SQLErrorEvent.ERROR, seqItemError);
			if(TRACE_DEBUG) trace('baseDao run item '+sequenceIdx.toString()+ ' dao:'+getCurrentUnit().dao.toString()+'; sql:'+stmt.text);
			stmt.execute();
		}

		private static function onCommit(evt:SQLEvent):void{
			connection.removeEventListener(SQLEvent.COMMIT, onCommit);
			connection.removeEventListener(SQLErrorEvent.ERROR, onCommitErr);
			//complite unit vs result
			if(TRACE_DEBUG) trace('baseDao sequence complited '+getCurrentUnit().dao.toString());
			var tu:TransactionUnit=getCurrentUnit(true);
			if(tu.type==TransactionUnit.TYPE_WRITE){
				tu.dao.executeResult(RESULT_COMLETED,resultId,resultRows);
			}
			runNext();
		}
		private static function onCommitErr(evt:SQLErrorEvent):void{
			connection.removeEventListener(SQLEvent.COMMIT, onCommit);
			connection.removeEventListener(SQLErrorEvent.ERROR, onCommitErr);
			if(TRACE_DEBUG) trace('baseDao commit err!!!! '+getCurrentUnit().dao.toString()+' err:'+evt.error.message);
			lastErr=evt.errorID;
			lastErrMsg=evt.error.message;
			connection.addEventListener(SQLEvent.ROLLBACK, onRollback);
			connection.addEventListener(SQLErrorEvent.ERROR, onRollbackErr);
			if(connection.inTransaction){
				connection.rollback();
			}else{
				onRollback(null);
			}
			//execLate();
		}
		
		
		private static function seqItemResult(evt:SQLEvent):void{
			var stmt:SQLStatement=evt.target as SQLStatement; 
			stmt.removeEventListener(SQLEvent.RESULT, seqItemResult);
			stmt.removeEventListener(SQLErrorEvent.ERROR, seqItemError);
			
			//save result
			var res:SQLResult=stmt.getResult();
			resultId=res.lastInsertRowID;
			resultRows=res.rowsAffected;
			resultData=res.data;

			sequenceIdx++;
			nextSequenceItem();
		}
		
		public static var lastErr:int;
		[Bindable]
		public static var lastErrMsg:String='';
		private static function seqItemError(evt:SQLErrorEvent):void{
			var stmt:SQLStatement=evt.target as SQLStatement; 
			stmt.removeEventListener(SQLEvent.RESULT, seqItemResult);
			stmt.removeEventListener(SQLErrorEvent.ERROR, seqItemError);

			trace('baseDao sequenceStatement '+sequenceIdx.toString() +' error. dao: '+getCurrentUnit().dao.toString()+' err:'+evt.error.details+'; SQL: '+stmt.text);
			//add listener
			lastErr=evt.errorID;
			lastErrMsg=evt.error.details+'; SQL: '+stmt.text;
			connection.addEventListener(SQLEvent.ROLLBACK, onRollback);
			connection.addEventListener(SQLErrorEvent.ERROR, onRollbackErr);
			if(connection.inTransaction){
				connection.rollback();
			}else{
				onRollback(null);
			}
		}
		private static function onRollback(evt:SQLEvent):void{
			connection.removeEventListener(SQLEvent.ROLLBACK, onRollback);
			connection.removeEventListener(SQLErrorEvent.ERROR, onRollbackErr);
			if(lastErr!=3119){
				//complite unit vs sql err & start next unit
				var tu:TransactionUnit=getCurrentUnit(true);
				if(tu.type==TransactionUnit.TYPE_WRITE){
					tu.dao.executeResult(RESULT_FAULT,0,0,lastErrMsg);
				}
				runNext();
				return;
			}else{
				//??????
				if(TRACE_DEBUG) trace('baseDao sequenceStatement  Write lock!!!! '+getCurrentUnit().dao.toString());
				execLate();
			}
		}
		private static function onRollbackErr(evt:SQLErrorEvent):void{
			if(TRACE_DEBUG) trace('baseDao Rollback error!!!! '+evt.error.message);
			connection.removeEventListener(SQLEvent.ROLLBACK, onRollback);
			connection.removeEventListener(SQLErrorEvent.ERROR, onRollbackErr);
			rollbackLate();
		}
		
		
		private static function onBeginErr(event:SQLErrorEvent):void{
			if(TRACE_DEBUG) trace('baseDao onBegin error '+event.error.message);
			lastErrMsg=event.error.message;
			connection.removeEventListener(SQLEvent.BEGIN, onBegin);
			connection.removeEventListener(SQLErrorEvent.ERROR, onBeginErr);
			execLate();
		}

		private static function getCurrentUnit(shift:Boolean=false):TransactionUnit{
			var tu:TransactionUnit;
			if(queue.length>0){
				if(shift){
					tu=queue.shift() as TransactionUnit;
				}else{
					tu=queue[0] as TransactionUnit;
				}
			}
			return tu;
		}

		private static var wait:int=0;
		private static var attempt:int=0;
		private static var timer:Timer;
		
		private static function execLate():void{
			if(!getCurrentUnit()){
				wait=0;
				attempt=0;
				isBusy=false;
				return;
			}
			if(TRACE_DEBUG) trace('baseDAO.execLate wait:'+wait.toString()+'; starts dao: '+ getCurrentUnit().dao.toString());//+DebugUtils.getObjectMemoryHash(this));
			var tu:TransactionUnit=getCurrentUnit();
			if (wait>=MAX_WAITE || tu.dao.asyncFaultMode==FAULT_IGNORE){
				//max wait reached
				tu=getCurrentUnit(true);
				//complite unit vs write_lock err
				if(tu.type==TransactionUnit.TYPE_WRITE){
					tu.dao.executeResult(RESULT_FAULT_LOCKED,0,0,'Блокировка записи');
				}
				
				//clean up
				wait=0;
				attempt=0;
				if(!getCurrentUnit()){
					isBusy=false;
					return;
				}
			}
			if(!timer){
				timer=new Timer(getTimeout(),1);
			}else{
				timer.reset();
			}
			timer.addEventListener(TimerEvent.TIMER,onTimer);
			var sleep:int=getTimeout();
			wait+=sleep;
			timer.delay=sleep;
			attempt++;
			timer.start();
		}
		
		private static function onTimer(e:Event):void{
			timer.removeEventListener(TimerEvent.TIMER,onTimer);
			if(TRACE_DEBUG)  trace('baseDao restart on timer: '+ getCurrentUnit().dao.toString());
			runNext(false);
		}

		private static var rollbackTimer:Timer;
		private static function rollbackLate():void{
			if(!rollbackTimer){
				rollbackTimer=new Timer(getTimeout(),1);
			}else{
				rollbackTimer.reset();
				rollbackTimer.delay=getTimeout();
			}
			rollbackTimer.addEventListener(TimerEvent.TIMER,onRollbackTimer);
			rollbackTimer.start();
		}
		private static function onRollbackTimer(e:Event):void{
			rollbackTimer.removeEventListener(TimerEvent.TIMER,onRollbackTimer);
			if(TRACE_DEBUG)  trace('baseDao restart rollback on timer');
			if(connection.inTransaction){
				connection.addEventListener(SQLEvent.ROLLBACK, onRollback);
				connection.addEventListener(SQLErrorEvent.ERROR, onRollbackErr);
				connection.rollback();
			}else{
				execLate();
			}
		}

		private static function getTimeout():int{
			var timeout:int=0;
			while (timeout<TIMEOUT_MIN){
				timeout=Math.random()*(TIMEOUT_MAX+TIMEOUT_MIN*attempt);
			}
			return timeout;
		}


		/****************** instance *****************************/
		
		
		
		protected var sqlConnection:SQLConnection;
		private var asyncCnn:SQLConnection;
		public var asyncFaultMode:int=FAULT_REPIT;
		public var execOnItem:Object;

		//raw result from last Select
		protected var lastResult:Array;
		private var isRunning:Boolean=false;

		public function BaseDAO(){
			sqlConnection = Context.getAttribute("sqlConnection");
			asyncCnn = Context.getAttribute("asyncConnection");
		}

		protected function fillRow(source:Object,dest:DBRecord):void{
			for (var prop:String in source){
				if(dest.hasOwnProperty(prop)){
					if(prop.substr(0,3)=='is_'){
						dest[prop]=Boolean(source[prop]);
					}else if(prop.indexOf('date')!=-1){
						if(source[prop]) dest[prop]=new Date(source[prop]);
					}else if(prop.indexOf('time')!=-1){
						if(source[prop]) dest[prop]=new Date(source[prop]);
					}else{
						dest[prop]=source[prop];
					}
				}
			}
			dest.loaded = true;
		}
		
		/**
		 *runs any statement to fetch data
		 * sync
		 *   
		 * @param sql
		 * @param params
		 * @param silent
		 * @param startRow
		 * @param pageSize
		 * @return true on success
		 * 
		 */
		public function runSelect(sql:String, params:Array=null, silent:Boolean=false, startRow:int=0, pageSize:int=0):Boolean{
			var stmt:SQLStatement = new SQLStatement();
			stmt.sqlConnection = sqlConnection;
			stmt.text = sql;
			//trace(sql);
			if (params){
				for (var i:int=0; i<params.length; i++){
					stmt.parameters[i] = params[i];
				}
			}
			try{
				stmt.execute();
			}catch(err:SQLError){
				lastResult=null;
				if(err.errorID!=3119){
					if(TRACE_DEBUG) trace('BaseDAO.runSelect err: '+err.details+'; sql: '+stmt.text)
					Alert.show('Ошибка чтения данных: ' +err.details+'; sql: '+stmt.text); 
				}else{
					trace('BaseDAO.runSelect lock error; sql: '+stmt.text)
					if(!silent) Alert.show('Ошибка чтения данных. Данные блокированы другим процессом. Повторите попытку попозже. sql: '+stmt.text);
				}
				return false;
			}
			var result:Array = stmt.getResult().data;
			if (result == null) result=[];
			if (pageSize != 0){
				result = result.slice(startRow, pageSize);
			}
			lastResult=result;
			return true;
		}

		/**
		 *execute INSERT, UPDATE or DELETE use sync connection 
		 * use to fill temp tables 4 sync selects
		 * @param sql
		 * @param params
		 * 
		 */
		public function executeSync(sql:String, params:Array=null, silent:Boolean=true):Boolean{
			var stmt:SQLStatement = prepareStatement(sql,params);
			stmt.sqlConnection = sqlConnection;
			try{
				stmt.execute();
			}catch(err:SQLError){
				lastResult=null;
				if(err.errorID!=3119){
					if(TRACE_DEBUG) trace('BaseDAO.executeSync err: '+err.details+'; sql: '+stmt.text)
					Alert.show('Ошибка : ' +err.details+'; sql: '+stmt.text); 
				}else{
					trace('BaseDAO.runSelect lock error; sql: '+stmt.text)
					if(!silent) Alert.show('Ошибка. Данные блокированы другим процессом. Повторите попытку попозже. sql: '+stmt.text);
				}
				return false;
			}
			return true;
		}

		public function get rawList():ArrayCollection{
			return lastResult?new ArrayCollection(lastResult):null;
		}

		public function get itemsArray():Array{
			if(!lastResult) return null;
			var ac:Array = new Array();
			for (var j:int=0; j<lastResult.length; j++){
				ac.push(processRow(lastResult[j]));
			}
			return ac;			
		}
		
		public function get itemsList():ArrayCollection{
			if(!lastResult) return null;
			return new ArrayCollection(itemsArray);
		}

		public function get item():Object{
			if(!lastResult || lastResult.length==0) return null;
			return processRow(lastResult[0]);
		}
	
		protected function prepareStatement(sql:String, params:Array=null):SQLStatement{
			var stmt:SQLStatement = new SQLStatement();
			//stmt.sqlConnection = asyncCnn;
			stmt.text = sql;
			if (params){
				for (var i:int=0; i<params.length; i++){
					stmt.parameters[i] = params[i];
				}
			}
			return stmt;
		}

		/**
		 *execute INSERT, UPDATE or DELETE use async connection 
		 * @param sql
		 * @param params
		 * 
		 */
		protected function execute(sql:String, params:Array=null, item:Object=null):void{
			if(isRunning) throw new Error('BaseDao.execute while isRunning=true');
			//if(sequenceMode) throw new Error('BaseDao.execute in sequenceMode');

			if(TRACE_DEBUG) trace('baseDao About to write dao: '+ this.toString()+DebugUtils.getObjectMemoryHash(this));
			isRunning=true;
			execOnItem=item;
			var stmt:SQLStatement=prepareStatement(sql,params);
			BaseDAO.write(this,[stmt]);
		}

		protected function executeSequence(statements:Array):void{
			if(TRACE_DEBUG) trace('baseDao About to run sequence dao: '+ this.toString()+DebugUtils.getObjectMemoryHash(this));
			isRunning=true;
			asyncFaultMode=FAULT_REPIT;
			BaseDAO.write(this,statements);
		}

		protected function executeResult(result:int,lastId:int,lastRows:int,errMsg:String=''):void{
			isRunning=false;
			if(result==RESULT_COMLETED){
				if(TRACE_DEBUG) trace('BaseDAO.executeResult complited, dao: '+ this.toString()+DebugUtils.getObjectMemoryHash(this));
				if(execOnItem && execOnItem is DBRecord){
					(execOnItem as DBRecord).changed=false;
					(execOnItem as DBRecord).loaded=true;
				}
				dispatchEvent(new AsyncSQLEvent(AsyncSQLEvent.RESULT_COMLETED,lastId,lastRows,execOnItem));
			}else if(result==RESULT_FAULT_LOCKED){
				if(TRACE_DEBUG) trace('BaseDAO.executeResult locked dao: '+ this.toString()+DebugUtils.getObjectMemoryHash(this));
				dispatchEvent(new AsyncSQLEvent(AsyncSQLEvent.RESULT_FAULT_LOCKED,0,0,execOnItem,errMsg));
			}else{
				if(TRACE_DEBUG) trace('BaseDAO.executeResult error: '+errMsg+' dao: '+ this.toString()+DebugUtils.getObjectMemoryHash(this));
				dispatchEvent(new AsyncSQLEvent(AsyncSQLEvent.RESULT_FAULT,0,0,execOnItem,errMsg));
			}
			execOnItem=null;
		}

		public function analyzeDatabase():void{
			CursorManager.setBusyCursor();
			try{
				sqlConnection.analyze();
			}catch (error:SQLError){
				Alert.show('Ошибка обслуживания базы данных: ' + error.message);
			}
			CursorManager.removeBusyCursor();
		}

		public function vacuumDatabase():void{
			CursorManager.setBusyCursor();
			try{
				sqlConnection.compact();
			}catch (error:SQLError){
				Alert.show('Ошибка обслуживания базы данных: ' + error.message);
			}
			CursorManager.removeBusyCursor();
		}
		
		public function cleanDatabase(tillDate:Date):void{
			var sequence:Array=[];
			var stmt:SQLStatement;
			var sql:String;
			var params:Array;

			if(!tillDate) return;

			//clean temps
			sql='DELETE FROM tmp_orders';
			sequence.push(prepareStatement(sql));
			sql='DELETE FROM tmp_print_group';
			sequence.push(prepareStatement(sql));
			//get orders to kill
			sql='INSERT INTO tmp_orders(id)'+
				' SELECT o.id'+ 
				' FROM orders o'+
				' INNER JOIN sources_sync ss ON o.source=ss.id AND o.sync!=ss.sync'+
				' WHERE o.state_date < ?';
			sequence.push(prepareStatement(sql,[tillDate]));
			//get printgroups to kill
			sql='INSERT INTO tmp_print_group(id)'+
				' SELECT pg.id'+
				' FROM print_group pg'+
				' INNER JOIN tmp_orders t ON t.id=pg.order_id';
			sequence.push(prepareStatement(sql));
			//clean files
			sql='DELETE FROM print_group_file WHERE print_group IN (SELECT id FROM tmp_print_group)';
			sequence.push(prepareStatement(sql));
			//clean print_group
			sql='DELETE FROM print_group WHERE id IN (SELECT id FROM tmp_print_group)';
			sequence.push(prepareStatement(sql));
			//clean order extra_info
			sql='DELETE FROM order_extra_info WHERE id IN (SELECT id FROM tmp_orders)';
			sequence.push(prepareStatement(sql));
			//clean suborder extra_info
			sql='DELETE FROM order_extra_info WHERE id IN (SELECT so.id FROM tmp_orders t INNER JOIN suborders so ON so.order_id=t.id)';
			sequence.push(prepareStatement(sql));
			//clean lost extra_info
			sql="DELETE FROM order_extra_info WHERE EXISTS (SELECT 1 FROM tmp_orders t WHERE order_extra_info.id LIKE t.id || '.%' )";
			sequence.push(prepareStatement(sql));
			//clean suborder
			sql='DELETE FROM suborders WHERE order_id IN (SELECT id FROM tmp_orders)';
			sequence.push(prepareStatement(sql));
			//clean extra state
			sql='DELETE FROM order_extra_state WHERE id IN (SELECT id FROM tmp_orders)';
			sequence.push(prepareStatement(sql));
			sql='DELETE FROM order_exstate_prolong WHERE id IN (SELECT id FROM tmp_orders)';
			sequence.push(prepareStatement(sql));
			//clean state_log
			sql='DELETE FROM state_log WHERE order_id IN (SELECT id FROM tmp_orders)';
			sequence.push(prepareStatement(sql));
			//clean state_log
			sql='DELETE FROM tech_log WHERE print_group IN (SELECT id FROM tmp_print_group)';
			sequence.push(prepareStatement(sql));
			//clean orders
			sql='DELETE FROM orders WHERE id IN (SELECT id FROM tmp_orders)';
			sequence.push(prepareStatement(sql));
			//clean temps
			sql='DELETE FROM tmp_orders';
			sequence.push(prepareStatement(sql));
			sql='DELETE FROM tmp_print_group';
			sequence.push(prepareStatement(sql));

			executeSequence(sequence);
		}
		

		public function createTempTables():void{
			//orders temp table
			var sql:String="CREATE TEMP TABLE tmp_orders (" +
				" id         VARCHAR( 50 )  PRIMARY KEY," +
				" source     INTEGER        DEFAULT ( 0 )," +
				" src_id     VARCHAR( 50 )  DEFAULT ( ' ' )," +
				" src_date   DATETIME," +
				" data_ts    VARCHAR2(20),"+
				" state      INT            DEFAULT ( 100 )," +
				" state_max  INT            DEFAULT ( 0 )," +
				" state_date DATETIME," +
				" ftp_folder VARCHAR( 50 )," +
				" fotos_num  INTEGER( 5 )," +
				" sync       INTEGER," +
				" reload     INTEGER( 3 )   DEFAULT ( 0 )," +
				" is_new     INTEGER( 3 )   DEFAULT ( 0 )," +
				" is_preload INTEGER( 1 )   DEFAULT ( 0 )" +  
				")";
			var stmt:SQLStatement = new SQLStatement();
			stmt.sqlConnection = sqlConnection;
			stmt.text = sql; 
			stmt.execute();
			stmt.sqlConnection=asyncCnn;
			stmt.execute();

			//print groups temp table
			sql="CREATE TEMP TABLE tmp_print_group (" +
				" id         VARCHAR( 50 )  PRIMARY KEY," +
				" order_id   VARCHAR( 50 ) ,"+
				" state      INT	DEFAULT ( 100 )," +
				" state_max  INT	DEFAULT ( 0 )" +
				")";
			stmt= new SQLStatement();
			stmt.sqlConnection = sqlConnection;
			stmt.text = sql; 
			stmt.execute();
			stmt.sqlConnection=asyncCnn;
			stmt.execute();

			//orders spy temp table
			sql="CREATE TEMP TABLE tmp_orders_spy (" +
				" id         VARCHAR( 50 )  PRIMARY KEY," +
				" state      INT," +
				" start_date DATETIME," +
				" state_date DATETIME," +
				" reset      INT DEFAULT (0)," +
				" reset_date DATETIME," +
				" max_date   DATETIME" +
				")";
			stmt= new SQLStatement();
			stmt.sqlConnection = sqlConnection;
			stmt.text = sql; 
			stmt.execute();
			stmt.sqlConnection=asyncCnn;
			stmt.execute();

			/*
			//tech log temp table
			sql="CREATE TEMP TABLE tmp_tech_log (" +
				   " id          INTEGER         PRIMARY KEY AUTOINCREMENT," +
				   " print_group VARCHAR( 50 )   NOT NULL," +
				   " book_num    INTEGER         NOT NULL DEFAULT ( 0 )," +
				   " page_num    INTEGER         NOT NULL DEFAULT ( 0 )," +
				   " src_id      INTEGER         NOT NULL DEFAULT ( 0 )," +
				   " log_date    DATETIME 		 NOT NULL" +
				")";
			stmt = new SQLStatement();
			stmt.sqlConnection = sqlConnection;
			stmt.text = sql; 
			stmt.execute();
			stmt.sqlConnection=asyncCnn;
			stmt.execute();
			*/
		}

		public function clearTempTables():void{
			var sql:String='DELETE FROM tmp_orders';
			var stmt:SQLStatement = new SQLStatement();
			stmt.sqlConnection = sqlConnection;
			stmt.text = sql; 
			stmt.execute();
			stmt.sqlConnection=asyncCnn;
			stmt.execute();

			sql='DELETE FROM tmp_print_group';
			stmt= new SQLStatement();
			stmt.sqlConnection = sqlConnection;
			stmt.text = sql; 
			stmt.execute();
			stmt.sqlConnection=asyncCnn;
			stmt.execute();

			/*
			sql='DELETE FROM tmp_tech_log';
			stmt= new SQLStatement();
			stmt.sqlConnection = sqlConnection;
			stmt.text = sql; 
			stmt.execute();
			stmt.sqlConnection=asyncCnn;
			stmt.execute();
			*/
		}
		
		protected function processRow(row:Object):Object{
			//throw new Error("You need to override processRow() in your concrete DAO");
			return row;
		}

		public function save(item:Object):void{
			throw new Error("You need to override save() in your concrete DAO");
		}
	}
}