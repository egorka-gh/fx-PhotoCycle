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
	public class BaseDAO extends EventDispatcher{

		public static const RESULT_COMLETED:int=0;
		public static const RESULT_FAULT:int=1;
		public static const RESULT_FAULT_LOCKED:int=2;

		public static const FAULT_IGNORE:int=0;
		public static const FAULT_REPIT:int=1;

		private static const TRACE_DEBUG:Boolean=false;
		
		private static const TIMEOUT_MIN:int=300;
		private static const TIMEOUT_MAX:int=1000;
		private static const MAX_WAITE:int=10000;

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
		
		private static function runNext():void{
			wait=0;
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
			if(TRACE_DEBUG) trace('baseDao attempt to start transaction');
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
			if(TRACE_DEBUG) trace('baseDao run item '+sequenceIdx.toString()+ ' dao:'+getCurrentUnit().dao.toString());
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
		
		private static var lastErr:int;
		[Bindable]
		public static var lastErrMsg:String='';
		private static function seqItemError(evt:SQLErrorEvent):void{
			var stmt:SQLStatement=evt.target as SQLStatement; 
			stmt.removeEventListener(SQLEvent.RESULT, seqItemResult);
			stmt.removeEventListener(SQLErrorEvent.ERROR, seqItemError);

			trace('baseDao sequenceStatement '+sequenceIdx.toString() +' error. dao: '+getCurrentUnit().dao.toString()+' err:'+evt.error.message);
			//add listener
			lastErr=evt.errorID;
			lastErrMsg=evt.error.message;
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
			if(TRACE_DEBUG) trace('baseDAO.execLate starts dao: '+ getCurrentUnit().dao.toString());//+DebugUtils.getObjectMemoryHash(this));
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
			runNext();
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
						dest[prop]=new Date(source[prop]);
					}else if(prop.indexOf('time')!=-1){
						dest[prop]=new Date(source[prop]);
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
		protected function runSelect(sql:String, params:Array=null, silent:Boolean=false, startRow:int=0, pageSize:int=0):Boolean{
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
				//sqlConnection.begin(SQLTransactionLockType.IMMEDIATE);
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
				/*
				if(sqlConnection.inTransaction){
					try{
						sqlConnection.rollback();
					}catch(err:Error){}
				}
				*/
				return false;
			}
			/*
			if(sqlConnection.inTransaction){
				try{
					sqlConnection.commit();
				}catch(err:SQLError){}
			}
			*/
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
		
/*old async write 
		protected function asyncTransaction(onBegin:Function,onBeginErr:Function):Boolean{
			//TODO can recive events from prev call asyncCnn.begin, so maintain static write queue
			var result:Boolean=true;
			if(!asyncCnn.inTransaction) {
				asyncCnn.addEventListener(SQLEvent.BEGIN, onBegin);
				asyncCnn.addEventListener(SQLErrorEvent.ERROR, onBeginErr);
				asyncCnn.begin(SQLTransactionLockType.IMMEDIATE);
			}else{
				result=false;
			}
			return result;
		}
		

		private var localTransaction:Boolean;
		private var finalEvent:AsyncSQLEvent;
		
		protected function execute(sql:String, params:Array=null, item:Object=null):void{
			if(isRunning) throw new Error('BaseDao.execute while isRunning=true');
			if(sequenceMode) throw new Error('BaseDao.execute in sequenceMode');
			wait=0;
			lastStatement=null;
			isRunning=true;
			attempt=0;
			var stmt:SQLStatement =prepareStatement(sql,params);
			execOnItem=item;
			lastStatement=stmt;
			//check transaction
			localTransaction=!sequenceMode;
			if(TRACE_DEBUG) trace('baseDao About to write dao: '+ this.toString()+DebugUtils.getObjectMemoryHash(this));
			if(localTransaction){
				if (!asyncTransaction(onTransBegin,onTransBeginErr)){
					//cnn is busy - call late
					execLate();
					return;
				}
			}
		}
		
		private function onTransBegin(event:SQLEvent):void{
			asyncCnn.removeEventListener(SQLEvent.BEGIN, onTransBegin);
			asyncCnn.removeEventListener(SQLErrorEvent.ERROR, onTransBeginErr);
			//run
			lastStatement.addEventListener(SQLEvent.RESULT, execResult);
			lastStatement.addEventListener(SQLErrorEvent.ERROR, execError);
			CursorManager.setBusyCursor();
			lastStatement.execute();
		}
		private function onTransBeginErr(event:SQLErrorEvent):void{
			asyncCnn.removeEventListener(SQLEvent.BEGIN, onTransBegin);
			asyncCnn.removeEventListener(SQLErrorEvent.ERROR, onTransBeginErr);
			execLate();
		}
		
		protected function prepareStatement(sql:String, params:Array=null):SQLStatement{
			var stmt:SQLStatement = new SQLStatement();
			stmt.sqlConnection = asyncCnn;
			stmt.text = sql;
			if (params){
				for (var i:int=0; i<params.length; i++){
					stmt.parameters[i] = params[i];
				}
			}
			return stmt;
		}
		

		private function execResult(e:SQLEvent):void{
			var stmt:SQLStatement=e.target as SQLStatement;
			if(TRACE_DEBUG) trace('baseDao write complite dao: '+ this.toString()+DebugUtils.getObjectMemoryHash(this));
			stmt.removeEventListener(SQLEvent.RESULT, execResult);
			stmt.removeEventListener(SQLErrorEvent.ERROR, execError);
			if(!sequenceMode) CursorManager.removeBusyCursor();
			if(execOnItem && execOnItem is DBRecord){
				(execOnItem as DBRecord).changed=false;
				(execOnItem as DBRecord).loaded=true;
			}
			var res:SQLResult=stmt.getResult();
			finalEvent=new AsyncSQLEvent(AsyncSQLEvent.RESULT_COMLETED,res.lastInsertRowID,res.rowsAffected,execOnItem);
			if(localTransaction && asyncCnn.inTransaction){
				asyncCnn.addEventListener(SQLEvent.COMMIT,onExecEnd);
				asyncCnn.commit();
			}else{
				isRunning=false;
				dispatchEvent(finalEvent);
				finalEvent=null;
			}
		}
		
		private function execError(e:SQLErrorEvent):void{
			var stmt:SQLStatement=e.target as SQLStatement;
			stmt.removeEventListener(SQLEvent.RESULT, execResult);
			stmt.removeEventListener(SQLErrorEvent.ERROR, execError);
			if(TRACE_DEBUG) trace('BaseDAO.execError err: '+e.error.message+'; sql: '+stmt.text)
			if(localTransaction && asyncCnn.inTransaction){
				asyncCnn.rollback();
			}
			if(e.errorID!=3119){
				Alert.show('Ошибка обновления данных: '+e.error.message);
				CursorManager.removeBusyCursor();
				finalEvent=new AsyncSQLEvent(AsyncSQLEvent.RESULT_FAULT,0,0,execOnItem,e.error.message);
				dispatchEvent(finalEvent);
				finalEvent=null;
				isRunning=false;
				return;
			}else{
				if(TRACE_DEBUG) trace('baseDao Write lock'+DebugUtils.getObjectMemoryHash(this));
				if(asyncFaultMode==FAULT_REPIT){
					//rerun
					if(!lastStatement)lastStatement=stmt;
					execLate();
				}else{
					//ignore
					isRunning=false;
					finalEvent=new AsyncSQLEvent(AsyncSQLEvent.RESULT_COMLETED,0,0,execOnItem);
					dispatchEvent(finalEvent);
					finalEvent=null;
				}
			}
		}
		
		private function onExecEnd(e:Event):void{
			if(TRACE_DEBUG) trace('baseDao commit complite dao: '+ this.toString()+DebugUtils.getObjectMemoryHash(this));
			isRunning=false;
			asyncCnn.removeEventListener(SQLEvent.COMMIT,onExecEnd);
			asyncCnn.removeEventListener(SQLEvent.ROLLBACK,onExecEnd);
			dispatchEvent(finalEvent);
			finalEvent=null;
		}

		private var wait:int=0;
		private var attempt:int=0;
		private var timer:Timer;
		private var waitPopup:ModalPopUp;
		private var lastStatement:SQLStatement;

		private function execLate():void{
			if(TRACE_DEBUG) trace('baseDAO.execLate write lock or connection in transaction dao: '+ this.toString()+DebugUtils.getObjectMemoryHash(this));
			if(asyncFaultMode==FAULT_IGNORE && attempt>1){
				isRunning=false;
				return;
			}
			if (wait<MAX_WAITE){
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
			}else{
				//max wait reached
				if(waitPopup && waitPopup.isOpen) waitPopup.close();
				isRunning=false;
				CursorManager.removeBusyCursor();
				lastStatement=null;
				var errMsg:String='Ошибка обновление данных. База данных блокирована более '+MAX_WAITE.toString()+'сек. Обновление данных не выполнено.';
				finalEvent=new AsyncSQLEvent(AsyncSQLEvent.RESULT_FAULT_LOCKED,0,0,execOnItem,errMsg);
				dispatchEvent(finalEvent);
				finalEvent=null;
				var errPopup:ErrorPopup;
				errPopup= new ErrorPopup();
				errPopup.cancelLabel='';
				errPopup.alert=errMsg;
				errPopup.open(null);
			}
		}

		private function onTimer(e:Event):void{
			timer.removeEventListener(TimerEvent.TIMER,onTimer);
			if(TRACE_DEBUG)  trace('baseDao restart on timer: '+ this.toString()+DebugUtils.getObjectMemoryHash(this));
			if(localTransaction){
				if (!asyncTransaction(onTransBegin,onTransBeginErr)){
					//cnn is busy - call late
					execLate();
					return;
				}
			}
		}

		private function getTimeout():int{
			var timeout:int=0;
			while (timeout<TIMEOUT_MIN){
				timeout=Math.random()*(TIMEOUT_MAX+TIMEOUT_MIN*attempt);
			}
			return timeout;
		}
		
		private var sequenceMode:Boolean=false;
		private var sequence:Array;
		private var sequenceIdx:int;
		private var sequenceStatement:SQLStatement;
		
		
		public function executeSequence(statements:Array):void{
			if(TRACE_DEBUG) trace('baseDao About to run Sequence dao: '+ this.toString()+DebugUtils.getObjectMemoryHash(this));
			sequence=statements;
			if(!sequence || sequence.length==0){
				dispatchEvent(new SqlSequenceEvent(SqlSequenceEvent.RESULT_COMLETED));
				return;
			}
			sequenceIdx=0;
			asyncFaultMode=FAULT_REPIT;
			sequenceMode=true;
			localTransaction=false;
			attempt=0;
			if (!asyncTransaction(onSeqTransBegin,onSeqTransBeginErr)){
				//cnn is busy - call late
				executeSequenceLate();
				return;
			}
		}
		
		private function onSeqTransBegin(event:SQLEvent):void{
			asyncCnn.removeEventListener(SQLEvent.BEGIN, onSeqTransBegin);
			asyncCnn.removeEventListener(SQLErrorEvent.ERROR, onSeqTransBeginErr);
			//run
			sequenceIdx=0;
			CursorManager.setBusyCursor();
			executeNext();
		}
		private function onSeqTransBeginErr(event:SQLErrorEvent):void{
			asyncCnn.removeEventListener(SQLEvent.BEGIN, onSeqTransBegin);
			asyncCnn.removeEventListener(SQLErrorEvent.ERROR, onSeqTransBeginErr);
			executeSequenceLate();
		}

		private function executeSequenceLate():void{
			if(TRACE_DEBUG) trace('baseDAO executeSequenceLate write lock or connection in transaction dao: '+ this.toString()+DebugUtils.getObjectMemoryHash(this));
			if(asyncFaultMode==FAULT_IGNORE && attempt>1){
				isRunning=false;
				sequenceMode=false;
				CursorManager.removeBusyCursor();
				return;
			}
			if (wait<MAX_WAITE){
				if(!timer){
					timer=new Timer(getTimeout(),1);
				}else{
					timer.reset();
				}
				timer.addEventListener(TimerEvent.TIMER,onSequenceTimer);
				var sleep:int=getTimeout();
				wait+=sleep;
				timer.delay=sleep;
				attempt++;
				timer.start();
			}else{
				//max wait reached
				isRunning=false;
				sequenceMode=false;
				CursorManager.removeBusyCursor();
				//lastStatement=null;
				var errMsg:String='Ошибка обновление данных. База данных блокирована более '+MAX_WAITE.toString()+'сек. Обновление данных не выполнено.';
				finalEvent=new AsyncSQLEvent(AsyncSQLEvent.RESULT_FAULT_LOCKED,0,0,execOnItem,errMsg);
				dispatchEvent(finalEvent);
				finalEvent=null;
			}
		}
		private function onSequenceTimer(e:Event):void{
			timer.removeEventListener(TimerEvent.TIMER,onSequenceTimer);
			if(TRACE_DEBUG) trace('baseDao restart Sequence on timer: '+ this.toString()+DebugUtils.getObjectMemoryHash(this));
			if (!asyncTransaction(onSeqTransBegin,onSeqTransBeginErr)){
				//cnn is busy - call late
				executeSequenceLate();
				return;
			}
		}


		private function executeNext():void{
			if(sequenceIdx==sequence.length){
				//completed
				sequenceMode=false;
				sequence=null;
				sequenceStatement=null;
				isRunning=false;
				CursorManager.removeBusyCursor();
				//removeEventListener(AsyncSQLEvent.ASYNC_SQL_EVENT,onSequenceItemComplite,false);
				if(asyncCnn.inTransaction){
					asyncCnn.addEventListener(SQLEvent.COMMIT,onSequenceCommit);
					asyncCnn.addEventListener(SQLErrorEvent.ERROR,onSequenceCommitErr);
					asyncCnn.commit();
				}
				return;
			}
			var stmt:SQLStatement=sequence[sequenceIdx] as SQLStatement;
			sequenceStatement=stmt;
			//trace('Run sequence sql: '+stmt.text);
			stmt.addEventListener(SQLEvent.RESULT, seqExecResult);
			stmt.addEventListener(SQLErrorEvent.ERROR, seqExecError);
			stmt.execute();
			sequenceIdx++;
		}
		
		private function seqExecResult(e:SQLEvent):void{
			var stmt:SQLStatement=e.target as SQLStatement;
			stmt.removeEventListener(SQLEvent.RESULT, seqExecResult);
			stmt.removeEventListener(SQLErrorEvent.ERROR, seqExecError);
			if(TRACE_DEBUG) trace('baseDao sequenceStatement '+sequenceIdx.toString() +' complited dao: '+ this.toString()+DebugUtils.getObjectMemoryHash(this));
			executeNext();
		}
		
		private function seqExecError(e:SQLErrorEvent):void{
			var stmt:SQLStatement=e.target as SQLStatement;
			stmt.removeEventListener(SQLEvent.RESULT, seqExecResult);
			stmt.removeEventListener(SQLErrorEvent.ERROR, seqExecError);
			if(TRACE_DEBUG) trace('baseDao sequenceStatement '+sequenceIdx.toString() +' error. dao: '+ this.toString()+DebugUtils.getObjectMemoryHash(this)+' err:'+e.error.message);
			if(asyncCnn.inTransaction) asyncCnn.rollback();
			CursorManager.removeBusyCursor();
			if(e.errorID!=3119){
				isRunning=false;
				Alert.show('Ошибка обновления данных: '+e.error.message);
				dispatchEvent(new AsyncSQLEvent(AsyncSQLEvent.RESULT_FAULT,0,0,null,e.error.message));
				return;
			}else{
				//??????
				if(TRACE_DEBUG) trace('baseDao sequenceStatement '+sequenceIdx.toString() +' Write lock '+DebugUtils.getObjectMemoryHash(this));
				if(asyncFaultMode==FAULT_REPIT){
					executeSequenceLate();
				}else{
					//ignore
					isRunning=false;
					dispatchEvent(new AsyncSQLEvent(AsyncSQLEvent.RESULT_COMLETED));
					finalEvent=null;
				}
			}
		}

		
		private function onSequenceCommit(e:SQLEvent):void{
			asyncCnn.removeEventListener(SQLEvent.COMMIT,onSequenceCommit);
			asyncCnn.removeEventListener(SQLErrorEvent.ERROR,onSequenceCommitErr);
			//dispatchEvent(new SqlSequenceEvent(SqlSequenceEvent.RESULT_COMLETED));
		}

		private function onSequenceCommitErr(e:SQLErrorEvent):void{
			asyncCnn.removeEventListener(SQLEvent.COMMIT,onSequenceCommit);
			asyncCnn.removeEventListener(SQLErrorEvent.ERROR,onSequenceCommitErr);
			if(TRACE_DEBUG) trace('SequenceCommitErr '+e.error.message+DebugUtils.getObjectMemoryHash(this));
			if(asyncCnn.inTransaction) asyncCnn.rollback();
			//dispatchEvent(new SqlSequenceEvent(SqlSequenceEvent.RESULT_FAULT,sequenceStatement,e.error.message));
		}

*/

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

		public function createTempTables():void{
			//orders temp table
			var sql:String="CREATE TEMP TABLE tmp_orders (" +
				" id         VARCHAR( 50 )  PRIMARY KEY," +
				" source     INTEGER        DEFAULT ( 0 )," +
				" src_id     VARCHAR( 50 )  DEFAULT ( ' ' )," +
				" src_date   DATETIME," +
				" state      INT            DEFAULT ( 100 )," +
				" state_max  INT            DEFAULT ( 0 )," +
				" state_date DATETIME," +
				" ftp_folder VARCHAR( 50 )," +
				" fotos_num  INTEGER( 5 )," +
				" sync       INTEGER," +
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
			throw new Error("You need to override processRow() in your concrete DAO");
		}

		public function save(item:Object):void{
			throw new Error("You need to override save() in your concrete DAO");
		}
	}
}