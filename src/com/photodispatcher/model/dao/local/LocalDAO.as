package com.photodispatcher.model.dao.local{
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
	import flash.filesystem.File;
	import flash.utils.Timer;
	import flash.utils.describeType;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Alert;
	import mx.managers.CursorManager;
	
	import spark.components.gridClasses.GridColumn;
	
	[Event(name="asyncSQLEvent", type="com.photodispatcher.event.AsyncSQLEvent")]
	[Event(name="complete", type="flash.events.Event")]
	public class LocalDAO extends EventDispatcher{
		public static const RESULT_COMLETED:int=0;
		public static const RESULT_FAULT:int=1;
		public static const RESULT_FAULT_LOCKED:int=2;

		public static const FAULT_IGNORE:int=0;
		public static const FAULT_REPIT:int=1;

		private static const TRACE_DEBUG:Boolean=false;
		
		private static const TIMEOUT_MIN:int=300;
		private static const TIMEOUT_MAX:int=1000;
		private static const MAX_WAITE:int=10000;

		[ArrayElementType("com.photodispatcher.model.dao.local.TransactionUnitLocal")]
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

		public static function getSyncConnection():SQLConnection{
			return syncConnection;
		}
		
		private static var connection:SQLConnection;
		private static var syncConnection:SQLConnection;

		
		/****************** static *****************************/

		public static function write(dao:LocalDAO, sequence:Array):void{
			if(!dao) return;
			if(!sequence || sequence.length==0){
				//dao.writeComplited vs err
				dao.executeResult(RESULT_COMLETED,0,0);
			}
			
			if(!connection || !connection.connected){
				//dao.writeComplited vs err
				dao.executeResult(RESULT_FAULT,0,0,'Нет подключения к базе данных');
			}
			var tu:TransactionUnitLocal= new TransactionUnitLocal(dao, sequence, TransactionUnitLocal.TYPE_WRITE);
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
				var tu:TransactionUnitLocal=getCurrentUnit(true);
				while(tu){
					if(tu.type==TransactionUnitLocal.TYPE_WRITE && tu.dao){
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
			if(TRACE_DEBUG) trace('baseDao run item '+sequenceIdx.toString()+'; sql:'+stmt.text);
			stmt.execute();
		}

		private static function onCommit(evt:SQLEvent):void{
			connection.removeEventListener(SQLEvent.COMMIT, onCommit);
			connection.removeEventListener(SQLErrorEvent.ERROR, onCommitErr);
			//complite unit vs result
			if(TRACE_DEBUG) trace('baseDao sequence complited ');
			var tu:TransactionUnitLocal=getCurrentUnit(true);
			if(tu.type==TransactionUnitLocal.TYPE_WRITE && tu.dao){
				tu.dao.executeResult(RESULT_COMLETED,resultId,resultRows);
			}
			runNext();
		}
		private static function onCommitErr(evt:SQLErrorEvent):void{
			connection.removeEventListener(SQLEvent.COMMIT, onCommit);
			connection.removeEventListener(SQLErrorEvent.ERROR, onCommitErr);
			if(TRACE_DEBUG) trace('baseDao commit err!!!! '+' err:'+evt.error.message);
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

			trace('baseDao sequenceStatement '+sequenceIdx.toString() +' error.'+' err:'+evt.error.details+'; SQL: '+stmt.text);
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
				var tu:TransactionUnitLocal=getCurrentUnit(true);
				if(tu.type==TransactionUnitLocal.TYPE_WRITE && tu.dao){
					tu.dao.executeResult(RESULT_FAULT,0,0,lastErrMsg);
				}
				runNext();
				return;
			}else{
				//??????
				if(TRACE_DEBUG) trace('baseDao sequenceStatement  Write lock!!!! ');
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

		private static function getCurrentUnit(shift:Boolean=false):TransactionUnitLocal{
			var tu:TransactionUnitLocal;
			if(queue.length>0){
				if(shift){
					tu=queue.shift() as TransactionUnitLocal;
				}else{
					tu=queue[0] as TransactionUnitLocal;
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
			if(TRACE_DEBUG) trace('baseDAO.execLate wait:'+wait.toString()+';');//+DebugUtils.getObjectMemoryHash(this));
			var tu:TransactionUnitLocal=getCurrentUnit();
			if (wait>=MAX_WAITE || !tu.dao || tu.dao.asyncFaultMode==FAULT_IGNORE){
				//max wait reached
				tu=getCurrentUnit(true);
				//complite unit vs write_lock err
				if(tu.type==TransactionUnitLocal.TYPE_WRITE && tu.dao){
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
			if(TRACE_DEBUG)  trace('baseDao restart on timer: ');
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

		public static function recreateBD():void{
			if (syncConnection && syncConnection.connected){
				try{
					syncConnection.close();
				}catch (error:SQLError){}
			}
			if(connection && connection.connected){
				connection.addEventListener(SQLEvent.CLOSE, onAsyncClose);
				connection.close();
			}else{
				onAsyncClose(null);
			}
		}
		private static function onAsyncClose(evt:SQLEvent):void{
			if(connection) connection.removeEventListener(SQLEvent.CLOSE, onAsyncClose);
			var dbFile:File = File.applicationStorageDirectory.resolvePath("local.sqlite");
			if(dbFile.exists){
				try{
					dbFile.deleteFile();
				}catch (error:Error){}
			}
			connect();
		}

		public static function connect():Boolean{
			var dbFile:File = File.applicationStorageDirectory.resolvePath("local.sqlite");
			var dbExists:Boolean=dbFile.exists;
			//create sync connection
			syncConnection= new SQLConnection();
			try{
				syncConnection.open(dbFile);
			}catch (error:SQLError){
					lastErr=error.errorID;
					lastErrMsg='Ошибка открытия локальной базы: ' + error.message;;
				return false;
			}
			trace('Local data base connected');

			if(!dbExists){
				//create tables
				trace('Local data base - fill shema');
				createShema();
			}else{
				//compact
				compact();
			}
			
			//create async connection
			connection= new SQLConnection();
			connection.addEventListener(SQLEvent.OPEN, onOpenAsyncCnn);
			connection.openAsync(dbFile);
			return true;
		}
		
		private static function onOpenAsyncCnn(evt:SQLEvent):void{
			connection.removeEventListener(SQLEvent.OPEN, onOpenAsyncCnn);
			createTempTables();
			var dao:TechPrintGroupDAO= new TechPrintGroupDAO();
			dao.removeOld();
		}
		
		private static function createShema():void{
			var sql:String;
			var stmt:SQLStatement;
			
			sql='CREATE TABLE [tech_print_group] ('+
				 ' [id] VARCHAR(50) NOT NULL,'+
				 ' [tech_type] INTEGER DEFAULT 0,'+
				 ' [start_date] DATETIME,'+
				 ' [end_date] DATETIME,'+
				 ' [books] INTEGER DEFAULT 0,'+ 
				 ' [sheets] INTEGER DEFAULT 0,'+ 
				 ' [start_loged] INTEGER DEFAULT 0,'+ 
				 ' [done] INTEGER DEFAULT 0,'+ 
				 ' CONSTRAINT [] PRIMARY KEY ([id]))';
			stmt= new SQLStatement();
			stmt.sqlConnection = syncConnection;
			stmt.text = sql; 
			stmt.execute();
			
			sql="CREATE TABLE [tech_log] ("+
				 " [id] INTEGER PRIMARY KEY AUTOINCREMENT,"+ 
				 " [print_group] VARCHAR2(50) NOT NULL CONSTRAINT [tech_log_fk_pg] REFERENCES [tech_print_group]([id]) ON DELETE CASCADE,"+ 
				 " [sheet] INTEGER NOT NULL,"+
				 " [src_id] INTEGER NOT NULL DEFAULT '0',"+ 
				 " [log_date] DATETIME NOT NULL)";
			stmt= new SQLStatement();
			stmt.sqlConnection = syncConnection;
			stmt.text = sql; 
			stmt.execute();

			sql="CREATE INDEX [tech_log_pg_idx] ON [tech_log] ([print_group])";
			stmt= new SQLStatement();
			stmt.sqlConnection = syncConnection;
			stmt.text = sql; 
			stmt.execute();
		}
		
		private static function createTempTables():void{
			var sql:String;
			var stmt:SQLStatement;
			//print groups temp table
			sql='CREATE TEMP TABLE [tmp_tech_pg] ('+
							' [id] VARCHAR(50) NOT NULL,'+
							' [start_date] DATETIME,'+
							' [end_date] DATETIME,'+
							' [books] INTEGER DEFAULT 0,'+ 
							' [sheets] INTEGER DEFAULT 0,'+ 
							' [done] INTEGER DEFAULT 0,'+ 
							' CONSTRAINT [] PRIMARY KEY ([id]))';

			//sequence.push(prepareStatement(sql,params));
			//executeSequence(sequence);
			
			stmt= new SQLStatement();
			stmt.sqlConnection = connection;
			stmt.text = sql; 
			//stmt.execute();
			
			var tu:TransactionUnitLocal= new TransactionUnitLocal(null, [stmt], TransactionUnitLocal.TYPE_WRITE);
			queue.push(tu);
			flushQueue();

		}

		private static function compact():void{
			//TODO implement
			//kill older 10 days
			//vacuum?
		}
		
		/****************** instance *****************************/
		public function get sqlConnection():SQLConnection{
			return LocalDAO.getSyncConnection();
		}

		//private var asyncCnn:SQLConnection;
		
		public var asyncFaultMode:int=FAULT_REPIT;
		public var execOnItem:Object;

		//raw result from last Select
		protected var lastResult:Array;
		private var isRunning:Boolean=false;

		public function LocalDAO(){
			//sqlConnection = Context.getAttribute("sqlConnection");
			//asyncCnn = Context.getAttribute("asyncConnection");
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
					if(TRACE_DEBUG) trace('BaseDAO.runSelect err: '+err.message+'; sql: '+stmt.text)
					Alert.show('Ошибка чтения данных: ' +err.message);
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
		 *execute INSERT, UPDATE or DELETE async 
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
			LocalDAO.write(this,[stmt]);
		}

		protected function executeSequence(statements:Array):void{
			if(TRACE_DEBUG) trace('baseDao Push to queue sequence dao: '+ this.toString()+DebugUtils.getObjectMemoryHash(this));
			isRunning=true;
			asyncFaultMode=FAULT_REPIT;
			LocalDAO.write(this,statements);
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


		protected function processRow(row:Object):Object{
			//throw new Error("You need to override processRow() in your concrete DAO");
			return row;
		}

		public function save(item:Object):void{
			throw new Error("You need to override save() in your concrete DAO");
		}
	}
}