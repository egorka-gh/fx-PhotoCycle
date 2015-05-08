package com.photodispatcher.service{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.AppConfig;
	import com.photodispatcher.model.mysql.entities.Lab;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.services.LabService;
	import com.photodispatcher.model.mysql.services.OrderService;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.utils.Timer;
	
	import mx.collections.ArrayCollection;
	
	import org.granite.tide.Tide;
	
	import spark.formatters.DateTimeFormatter;
	
	[Event(name="complete", type="flash.events.Event")]
	[Event(name="schedule", type="flash.events.Event")]
	[Event(name="progress", type="flash.events.ProgressEvent")]
	public class CleanService extends EventDispatcher{
		
		[Bindable]
		public static var busy:Boolean; 

		[Bindable]
		public var currSource:Source;
		[Bindable]
		public var state:String='';
		public var hasErr:Boolean;
		public var err:String;
		[Bindable]
		public var complited:int;

		private var sources:Array;
		private var progressTotal:int;
		private var config:AppConfig; 
		
		public function CleanService(){
			super(null);
		}
		
		private var lastRun:Date;
		private var timer:Timer;
		
		public function schedule():void{
			config=Context.config;
			if(!config || !config.clean_fs || config.clean_fs_state<=0 || config.clean_fs_days<=0)  return;
			if(!timer){
				timer=new Timer(10*60000,0);
				timer.addEventListener(TimerEvent.TIMER, onTimer);
			}
			if(!timer.running) timer.start();
		}
		private function onTimer(evt:TimerEvent):void{
			trace('CleanService attempt start schedule');
			var currDate:Date=new Date();
			//runs today?
			if(lastRun && lastRun.date==currDate.date) return;
			//check hour
			if(currDate.hours<config.clean_fs_hour) return;
			if (busy) return;
			//run
			lastRun=currDate;
			dispatchEvent(new Event('schedule'));  
			trace('CleanService clean started');
			cleanFileSystem();
		}
		
		public function stopSchedule():void{
			if(!timer) return;
			timer.reset();
		}
		
		private var folders2kill:Array;
		private var orderIds:Array;

		public function cleanFileSystem():void{
			if(busy) return;
			complited=0;
			hasErr=false;
			err='';
			state='';
			orderIds=[];
			folders2kill=[];
			//check config
			config=Context.config;
			if(!config || !config.clean_fs || config.clean_fs_state<=0 || (config.clean_fs_days<=0 && config.clean_nr_days<=0)){
				complite();
				return;
			}
			
			busy=true;
			prepareFS();
		}
		
		
		private function complite():void{
			busy=false;
			if(!hasErr){
				state='Удалено папок '+complited.toString();
				lastRun= new Date();
				var fmt:DateTimeFormatter= new DateTimeFormatter();
				fmt.dateTimePattern='dd.MM.yy HH:mm';
				state=state+' (' +fmt.format(lastRun)+')';
			}
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		private function releaseErr(errMsg:String):void{
			hasErr=true;
			err=errMsg;
			state=errMsg;
			complite();
		}
		
		private var _orderService:OrderService;
		private function get orderService():OrderService{
			if(!_orderService) _orderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
			return _orderService;
		}
			
		private function checkFolder(path:String):Boolean{
			if(!path) return false;
			var result:Boolean=false;
			var file:File;
			try{
				file= new File(path);
				result=file.exists && file.isDirectory;
			}catch(error:Error){
				return false;
			}
			return result;
		}
		
		private function prepareFS():void{
			//get sources
			sources=Context.getSources();
			if(!sources ||sources.length==0){
				prepareNoritsu();
				return;
			}
			progressTotal=sources.length;
			if(config.clean_fs_limit<=0) config.clean_fs_limit=500;
			prepareNextSource();
		}

		private function prepareNextSource():void{
			//progress
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,(progressTotal-sources.length), progressTotal));
			
			if(sources.length==0){
				//complite
				prepareNoritsu();
				return;
			}
			
			currSource=sources.pop() as Source;
			if(!currSource){
				prepareNextSource();
				return;
			}
			
			state='Подготовка '+currSource.name;
			
			//check source folders
			var wrkPath:String=currSource.getWrkFolder();
			var prnPath:String=currSource.getPrtFolder();
			if(!checkFolder(wrkPath) && !checkFolder(prnPath)){
				prepareNextSource();
				return;
			}
			
			//get orders to clean
			var latch:DbLatch=new DbLatch(true);
			latch.addEventListener(Event.COMPLETE, onOrdersloaded);
			latch.addLatch(orderService.load4CleanFS(currSource.id, config.clean_fs_state, config.clean_fs_days, config.clean_fs_limit));
			latch.start();
		}
		private function onOrdersloaded(event:Event):void{
			var latch:DbLatch= event.target as DbLatch;
			var orders:ArrayCollection;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onOrdersloaded);
				if(!latch.complite){
					releaseErr('Ошибка базы данных: '+latch.lastError);
					return;
				}
				orders=latch.lastDataAC;
			}
			if(!orders || orders.length==0){
				prepareNextSource();
				return;
			}
			var wrkFolder:File;
			var prnFolder:File;
			var path:String=currSource.getWrkFolder();
			if(checkFolder(path)) wrkFolder= new File(path);
			if(path!=currSource.getPrtFolder()){
				path=currSource.getPrtFolder();
				if(checkFolder(path)) prnFolder= new File(path);
			}
			
			var order:Order;
			var folder:File;
			var orderAdded:Boolean;
			for each (order in orders){
				if(order && order.ftp_folder){
					orderAdded=false;
					if(wrkFolder){
						folder=wrkFolder.resolvePath(order.ftp_folder);
						if(folder.exists && folder.isDirectory){
							orderAdded=true;
							folders2kill.push(new CleanFileHolder(folder,order.id));
						}
					}
					if(prnFolder){
						folder=prnFolder.resolvePath(order.ftp_folder);
						if(folder.exists && folder.isDirectory){
							if(orderAdded){
								folders2kill.push(new CleanFileHolder(folder));
							}else{
								folders2kill.push(new CleanFileHolder(folder,order.id));
							}
						}
					}
				}
			}
			prepareNextSource();
		}

		
		private function prepareNoritsu():void{
			state='Подготовка папок Норитсу';
			//check config
			if(!config || config.clean_nr_days<=0){
				startKill();
				return;
			}
			
			//get labs
			var svc:LabService=Tide.getInstance().getContext().byType(LabService,true) as LabService;
			var latch:DbLatch= new DbLatch(true);
			latch.addEventListener(Event.COMPLETE,onLabsLoad);
			latch.addLatch(svc.loadList());
			latch.start();
		}

		private function onLabsLoad(event:Event):void{
			var latch:DbLatch= event.target as DbLatch;
			var orders:ArrayCollection;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onLabsLoad);
				if(!latch.complite){
					releaseErr('Ошибка базы данных: '+latch.lastError);
					return;
				}
				var labs:Array=latch.lastDataArr;
				if(!labs || labs.length==0){
					startKill();
					return;
				}
				
				//get hot folders
				var lab:Lab;
				var labFolders:Array=[];
				for each(lab in labs){
					if(lab && lab.is_active && (lab.src_type==3 || lab.src_type==8)){
						if(lab.hot && checkFolder(lab.hot)) labFolders.push(lab.hot);
						if(lab.hot_nfs && checkFolder(lab.hot_nfs)) labFolders.push(lab.hot_nfs);
					}
				}
				if(labFolders.length==0){
					startKill();
					return;
				}
				
				//get folders to kill
				var path:String;
				var rootFile:File;
				var file:File;
				var listing:Array;
				var killAfter:Date= new Date();
				//killAfter= new Date(killAfter.fullYear, killAfter.month, killAfter.date-(config.clean_nr_days-1));
				//move to midnight
				killAfter= new Date(killAfter.fullYear, killAfter.month, killAfter.date);
				//offset
				killAfter= new Date(killAfter.time-24*60*60*1000*(config.clean_nr_days-1));
				for each(path in labFolders){
					try{
						rootFile = new File(path);
						listing=rootFile.getDirectoryListing();
						if(listing){
							for each(file in listing){
								if(file && file.exists && file.isDirectory && file.creationDate.time<killAfter.time){
									folders2kill.push(new CleanFileHolder(file));
								}
							}
						}
					}catch(error:Error){}
				}
				
				startKill();
			}
		}

		
		private function startKill():void{
			if(!folders2kill || folders2kill.length==0){
				complite();
				return;
			}
			state='Удаление папок';
			progressTotal=folders2kill.length;
			killNextFolder();
		}
		
		private var currFolder:CleanFileHolder;

		private function killNextFolder():void{
			//progress
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,(progressTotal-folders2kill.length), progressTotal));
			if(!folders2kill || folders2kill.length==0){
				//complited
				//save orders
				if(orderIds.length>0){
					var latch:DbLatch=new DbLatch(true);
					latch.addEventListener(Event.COMPLETE, onOrdersSaved);
					latch.addLatch(orderService.markCleanFS(orderIds));
					latch.start();
				}else{
					complite();
				}
				return;
			}
			currFolder=folders2kill.pop() as CleanFileHolder;
			if(!currFolder || !currFolder.file || !currFolder.file.exists || !currFolder.file.isDirectory){
				killNextFolder();
			}
			
			try{
				currFolder.file.addEventListener(Event.COMPLETE, onDeleted);
				currFolder.file.addEventListener(IOErrorEvent.IO_ERROR, onDeleted);
				currFolder.file.deleteDirectoryAsync(true);
			}catch(error:Error){
				killNextFolder();
			}
		}
		
		private function onDeleted(evt:Event):void{
			if(!currFolder) return;
			currFolder.file.removeEventListener(Event.COMPLETE, onDeleted);
			currFolder.file.removeEventListener(IOErrorEvent.IO_ERROR, onDeleted);
			if(evt is IOErrorEvent){
				//??
			}else{
				complited++;
				if(currFolder.orderId) orderIds.push(currFolder.orderId);
			}
			killNextFolder();
		}

		private function onOrdersSaved(event:Event):void{
			var latch:DbLatch= event.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onOrdersSaved);
				if(!latch.complite){
					releaseErr('Ошибка базы данных: '+latch.lastError);
					return;
				}
			}
			complite();
		}

	}
	
	
}