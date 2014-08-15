/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.globalization.DateTimeStyle;
	
	import mx.collections.ArrayCollection;
	import mx.collections.ArrayList;
	
	import pl.maliboo.ftp.FTPFile;
	
	import spark.components.gridClasses.GridColumn;
	import spark.formatters.DateTimeFormatter;

    [Bindable]
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.Order")]
    public class Order extends OrderBase {
		public static const ERROR_COUNTER_LIMIT:int=2;
		public static const BILL_TYPE_TXT:int=0;
		public static const BILL_TYPE_HTML:int=1;

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

		
		
		//remote source state (4 check if canceled) runtime
		public var src_state:String;
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
		
		override public function set state(value:int):void{
			if(super.state != value) state_name= OrderState.getStateName(value);
			super.state = value;
			state_date= new Date();
			if(value!=OrderState.ERR_READ_LOCK && 
				value!=OrderState.ERR_WRITE_LOCK && 
				//_state!=OrderState.ERR_FILE_SYSTEM &&
				//_state!=OrderState.ERR_FTP &&
				value!=OrderState.ERR_WEB){
				if(value<0 && (lastErrCode==value || lastErrCode==0)) errCount++;
			}
		}
		override public function get state():int{
			return super.state;
		}
		
		public function get hasSuborders():Boolean{
			return (suborders && suborders.length>0);
		}

		public function addSuborder(so:SubOrder):void{
			if(!suborders){
				suborders=new ArrayCollection;
			}
			var eso:SubOrder= ArrayUtil.searchItem('sub_id',so.sub_id,suborders.toArray()) as SubOrder;
			if(eso){
				eso.prt_qty++;
			}else{
				suborders.addItem(so);
			}
		}
		public function removeSuborder(so:SubOrder):void{
			if(!suborders || suborders.length==0) return;
			var i:int=suborders.getItemIndex(so);
			if(i!=-1){
				suborders.removeItemAt(i);
			}
		}
		public function resetSuborders():void{
			suborders=new ArrayCollection();
		}

		public function get isFtpQueueComplete():Boolean{
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
			//extra
			if(this.extraInfo){
				raw.calc_type=extraInfo.calc_type;
				raw.corner_type=extraInfo.corner_type;
				raw.cover=extraInfo.cover;
				raw.endpaper=extraInfo.endpaper;
				raw.format=extraInfo.format;
				raw.interlayer=extraInfo.interlayer;
				raw.kaptal=extraInfo.kaptal;
			}
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
			var so:SubOrder;
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
			//extra
			order.extraInfo= new OrderExtraInfo();
			order.extraInfo.calc_type=raw.calc_type;
			order.extraInfo.corner_type=raw.corner_type;
			order.extraInfo.cover=raw.cover;
			order.extraInfo.endpaper=raw.endpaper;
			order.extraInfo.format=raw.format;
			order.extraInfo.interlayer=raw.interlayer;
			order.extraInfo.kaptal=raw.kaptal;
			
			var pgRaw:Object;
			var pg:PrintGroup;
			if(raw.hasOwnProperty('printGroups') && raw.printGroups is Array){
				order.printGroups=new ArrayCollection;
				for each(pgRaw in raw.printGroups){
					pg=PrintGroup.fromRaw(pgRaw);
					if(pg) order.printGroups.addItem(pg);
				}
			}
			
			//suborders
			var so:SubOrder;
			if(raw.hasOwnProperty('suborders') && raw.suborders is Array){
				order.suborders=new ArrayCollection;
				for each(pgRaw in raw.suborders){
					so=SubOrder.fromRaw(pgRaw);
					if(so) order.suborders.addItem(so);
				}
			}
			
			return order; 
		}

		public function get interlayer():String{
			if(extraInfo) return extraInfo.interlayer;
			return null;
		}
		public function get endpaper():String{
			if(extraInfo) return extraInfo.endpaper;
			return null;
		}
    }
}