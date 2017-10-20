/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.globalization.DateTimeStyle;
	import flash.utils.Dictionary;
	
	import mx.collections.ArrayCollection;
	import mx.collections.ArrayList;
	
	import pl.maliboo.ftp.FTPFile;
	
	import spark.components.gridClasses.GridColumn;
	import spark.formatters.DateTimeFormatter;

    [Bindable]
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.Order")]
    public class Order extends OrderBase {

		public static const TAG_REPRINT:String='reject';

		public static const ERROR_COUNTER_LIMIT:int=2;
		public static const BILL_TYPE_TXT:int=0;
		public static const BILL_TYPE_HTML:int=1;

		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			
			var col:GridColumn= new GridColumn('source_name');
			col.headerText='Источник'; result.addItem(col);
			col= new GridColumn('state_name'); col.headerText='Статус'; result.addItem(col); 
			col= new GridColumn('id'); result.addItem(col);
			col= new GridColumn('groupId');  col.headerText='Группа'; result.addItem(col);
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
			col= new GridColumn('src_date'); col.headerText='Размещен'; col.formatter=fmt;  result.addItem(col);
			fmt=new DateTimeFormatter(); fmt.dateStyle=fmt.timeStyle=DateTimeStyle.SHORT; 
			col= new GridColumn('state_date'); col.headerText='Дата статуса'; col.formatter=fmt;  result.addItem(col);
			col= new GridColumn('ftp_folder'); col.headerText='Ftp Папка'; result.addItem(col);
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

		/*
		runtime
		available ftp sources 4 order  
		site send appKeys array (command order)   
		*/
		public var ftpAppKeys:Array;
		/*
		runtime
		can change remote state (site state)
		holder for 'allow_to_change_status'  
		*/
		public var canChangeRemoteState:Boolean=true;
		
		/**
		 * runtime subid 4 otk
		 */
		public var otkSubid:String;
		
		/**
		 * runtime bookkits 4 otk 
		 * keeps bookkits only 4 current subid 
		 * expected 
		 * coverBooks && blockBooks lenthes are equal
		 * and books are ordered by book num 
		 */
		public var otkBookKits:ArrayCollection;
		public function fillBookKits(coverBooks:Array, blockBooks:Array):void{
			otkBookKits=null;
			if(!coverBooks && !blockBooks ) return;
			if(coverBooks.length==0 && blockBooks.length==0) return;
			var len:int=0;
			if(coverBooks) len=coverBooks.length;
			if(blockBooks) len=Math.max(len, blockBooks.length);
			var res:Array= new Array(len);
			var k:BookKit;
			for (var i:int = 0; i < len; i++){
				k=new BookKit();
				if(coverBooks && i<coverBooks.length) k.coverBook=coverBooks[i] as OrderBook;
				if(blockBooks && i<blockBooks.length) k.blockBook=blockBooks[i] as OrderBook;
				res[i]=k;
			}
			otkBookKits=new ArrayCollection(res);
		}
		
		
		//remote source state (4 check if canceled or set remote state) runtime
		public var src_state:String;
		//err state comment runtime
		public var errStateComment:String;
		
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
		 * unused 
		 */
		//public var bdCheckComplete:Boolean=false;
		
		/**
		 * runtime
		 *map vs ftp file structure (filename arrays maped by parent folder)
		 */
		public var fileStructure:Dictionary;
		
		/**
		 * runtime
		 * orderLoad.files  (OrderFiles)
		 */
		public var files:ArrayCollection;
		
		public function get isFileStructureOk():Boolean{
			if(!fileStructure) return false;
			for (var key:String in fileStructure){
				if(key) return true;
			}
			return false;
		}
		
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
		
		private var savedState:int;
		public function saveState():void{
			if(state>0) savedState=state;
		}
		public function restoreState():void{
			if(savedState>0) state=savedState;
		}
		
		override public function set state(value:int):void{
			if(super.state != value) state_name= OrderState.getStateName(value);
			super.state = value;
			state_date= new Date();
			if(value<0 &&
				value!=OrderState.ERR_READ_LOCK && 
				value!=OrderState.ERR_WRITE_LOCK && 
				value!=OrderState.ERR_LOCK_FAULT && 
				value!=OrderState.ERR_FTP_NOT_READY && 
				//_state!=OrderState.ERR_FILE_SYSTEM &&
				//_state!=OrderState.ERR_FTP &&
				value!=OrderState.ERR_WEB){
					if(lastErrCode!=value || lastErrCode==0) errCount=0;
					errCount++;
					lastErrCode=value;
			}
		}
		override public function get state():int{
			return super.state;
		}
		
		public function get hasSuborders():Boolean{
			return (suborders && suborders.length>0);
		}

		public function get hasPhotoSuborder():Boolean{
			if(!hasSuborders) return false;
			//look for photo suborders 
			for each(var so:SubOrder in suborders){
				if(so.native_type==1) return true;
			}
			return false;
		}
		
		public function removePhotoSuborder():void{
			if(!hasSuborders) return;
			var so:SubOrder;
			var newso:Array=[];
			for each(so in suborders){
				if(so.native_type!=1) newso.push(so);
			}
			suborders= new ArrayCollection(newso);
		}

		public function addSuborder(so:SubOrder):void{
			if(!suborders){
				suborders=new ArrayCollection;
			}
			var eso:SubOrder= ArrayUtil.searchItem('sub_id',so.sub_id,suborders.toArray()) as SubOrder;
			if(eso){
				eso.prt_qty++;
			}else{
				//reassign id
				so.order_id=this.id;
				so.fillId();
				suborders.addItem(so);
			}
		}
		public function getSuborder(subId:String):SubOrder{
			if(!hasSuborders || !subId) return null;
			return ArrayUtil.searchItem('sub_id',subId,suborders.toArray()) as SubOrder;
		}
		/*
		public function removeSuborder(so:SubOrder):void{
			if(!suborders || suborders.length==0) return;
			var i:int=suborders.getItemIndex(so);
			if(i!=-1){
				suborders.removeItemAt(i);
			}
		}
		*/
		
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

		public function get humanId():String{
			var arr:Array=id.split('_');
			if(source_code && arr && arr.length>1){
				return source_code+arr[1];
			}else{
				return id;
			}
		}
		
		/*
		public function getBooks(bookPart:int):ArrayCollection{
			var arr:Array=[];
			if(books){
				 for each(var b:OrderBook in books){
					 if(b.book_part==bookPart) arr.push(b);
				 }
			}
			return new ArrayCollection(arr);
		}

		public function getBooksReject():ArrayCollection{
			var arr:Array=[];
			if(books){
				for each(var b:OrderBook in books){
					if(b.is_reject) arr.push(b);
				}
			}
			return new ArrayCollection(arr);
			
		}
		*/

	}
}