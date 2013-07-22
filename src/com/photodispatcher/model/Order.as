package com.photodispatcher.model{
	import com.photodispatcher.model.dao.OrderStateDAO;
	import com.photodispatcher.print.LabBase;
	import com.photodispatcher.util.ArrayUtil;
	
	import pl.maliboo.ftp.FTPFile;

	public class Order extends DBRecord{
		public static const ERROR_COUNTER_LIMIT:int=2;
		public static const BILL_TYPE_TXT:int=0;
		public static const BILL_TYPE_HTML:int=1;

		
		//remote source state (4 check if canceled) runtime
		public var src_state:String;

		/**
		 *not populateted from database
		 * used as runtime holder 
		 */
		public var printGroups:Array;
		/**
		 * runtime 
		 */
		public var ftpQueue:Array;
		/**
		 * runtime 
		 */
		public var ftpForwarded:Boolean=false;

		/**
		 * runtime
		 *map to hold print states by print groups (lab view) 
		 */
		public var printStates:Object;

		/**
		 * runtime
		 * is order checked in bd, used in PrintManager 
		 */
		public var bdCheckComplete:Boolean=false;

		/**
		 * runtime
		 * post to lab (used in PrintManager) 
		 */
		//public var destinationLab:LabBase;

		/**
		 * runtime
		 * process err count  
		 */
		private var errCount:int=0;
		/**
		 * runtime
		 * last error 
		 */
		private var lastErrCode:int=0;
		
		public function resetErrCounter():void{
			errCount=0;
			lastErrCode=0;
		}
		
		public function get exceedErrLimit():Boolean{
			return errCount>=ERROR_COUNTER_LIMIT;
		}
		public function setErrLimit():void{
			errCount=ERROR_COUNTER_LIMIT;
		}

		//database props
		[Bindable]
		public var id:String;
		[Bindable]
		public var source:int;
		//[Bindable]
		//public var dt_date:Date=new Date();
		[Bindable]
		public var src_id:String;
		[Bindable]
		public var src_date:Date=new Date();
		[Bindable]
		public var ftp_folder:String;
		[Bindable]
		public var local_folder:String;
		
		[Bindable]
		public var bill:String;
		[Bindable]
		public var bill_type:int=BILL_TYPE_TXT;
		
		
		protected var _state:int=OrderState.FTP_WAITE_SUBORDER;
		[Bindable]
		public function get state():int{
			return _state;
		}
		public function set state(value:int):void{
			state_date= new Date();
			if(_state != value) state_name= OrderStateDAO.getStateName(value);
			_state = value;
			if(_state!=OrderState.ERR_READ_LOCK && 
				_state!=OrderState.ERR_WRITE_LOCK && 
				//_state!=OrderState.ERR_FILE_SYSTEM &&
				//_state!=OrderState.ERR_FTP &&
				_state!=OrderState.ERR_WEB){
				if(_state<0 && (lastErrCode==_state || lastErrCode==0)) errCount++;
			}
		}

		[Bindable]
		public var fotos_num:int;
		[Bindable]
		public var state_date:Date;
		public var sync:int;
		public var is_preload:Boolean;

		public var suborders:Array;

		public function get hasSuborders():Boolean{
			return (suborders && suborders.length>0);
		}

		/*
		public function resetPreprocess():void{
			var pg:PrintGroup;
			if(printGroups){
				for each(pg in printGroups){
					if(pg.book_type!=0) pg.restoreFiles();
				}
			}
			
			var so:Suborder;
			if(suborders){
				for each(so in suborders){
					so.printGroups=null;
				}
			}
		}
		*/

		public function addSuborder(so:Suborder):void{
			if(!suborders){
				suborders=[];
			}
			var eso:Suborder= ArrayUtil.searchItem('sub_id',so.sub_id,suborders) as Suborder;
			if(eso){
				eso.prt_qty++;
			}else{
				suborders.push(so);
			}
		}
		public function removeSuborder(so:Suborder):void{
			if(!suborders || suborders.length==0) return;
			var i:int=suborders.indexOf(so);
			if(i!=-1){
				suborders.splice(i,1);
			}
		}
		public function resetSuborders():void{
			suborders=[];
		}

		/*
		public function mergeSuborders():void{
			var so:Suborder;
			var pg:PrintGroup;
			if(suborders && suborders.length>0){
				for each(so in suborders){
					if(so.printGroups){
						for each(pg in so.printGroups){
							pg.id=id+'_'+(printGroups.length+1).toString();
							printGroups.push(pg);
						}
						so.printGroups=null;
					}
				}
			}
		}
		*/
		
		//ref
		[Bindable]
		public var source_name:String;
		[Bindable]
		public var state_name:String;
		
		public function get isFtpQueueComplete():Boolean{
			//if(state!=OrderState.FTP_LOAD) return false;
			if (!ftpQueue || ftpQueue.length==0) return true;
			var ftpFile:FTPFile;
			for each(var o:Object in ftpQueue){
				ftpFile=o as FTPFile;
				if(ftpFile && ftpFile.loadState<FTPFile.LOAD_COMPLETE){
					return false;
				}
			}
			return true;
		}

		public function get ftpQueueHasErr():Boolean{
			//if(state!=OrderState.FTP_LOAD) return false;
			if (!ftpQueue || ftpQueue.length==0) return false;
			var ftpFile:FTPFile;
			for each(ftpFile in ftpQueue){
				if(ftpFile && ftpFile.loadState==FTPFile.LOAD_ERR){
					return true;
				}
			}
			return false;
		}

		
		public function toRaw():Object{
			//serialize props 4 build only 
			var raw:Object= new Object;

			raw.id=id;
			raw.source=source;
			//raw.source_name=source_name;
			raw.ftp_folder=ftp_folder;
			raw.state=state;
			raw.errCount=errCount;
			//raw.state_date=state_date;
			var arr:Array=[];
			var pg:PrintGroup;
			if(printGroups){
				for each(pg in printGroups){
					if(pg) arr.push(pg.toRaw());
				}
			}
			raw.printGroups=arr;

			//suborders
			var so:Suborder;
			arr=[];
			if(suborders){
				for each(so in suborders){
					if(so) arr.push(so.toRaw());
				}
			}
			raw.suborders=arr;

			return raw;
		}

		public static function fromRaw(raw:Object):Order{
			if(!raw) return null;
			var order:Order= new Order();
			order.id=raw.id;
			order.source=raw.source;
			//raw.source_name=source_name;
			order.ftp_folder=raw.ftp_folder;
			order.state=raw.state;
			order.errCount=raw.errCount;
			//raw.state_date=state_date;
			
			var pgRaw:Object;
			var pg:PrintGroup;
			if(raw.hasOwnProperty('printGroups') && raw.printGroups is Array){
				order.printGroups=[];
				for each(pgRaw in raw.printGroups){
					pg=PrintGroup.fromRaw(pgRaw);
					if(pg) order.printGroups.push(pg);
				}
			}
			
			//suborders
			var so:Suborder;
			if(raw.hasOwnProperty('suborders') && raw.suborders is Array){
				order.suborders=[];
				for each(pgRaw in raw.suborders){
					so=Suborder.fromRaw(pgRaw);
					if(so) order.suborders.push(so);
				}
			}
			
			return order; 
		}

	}
}