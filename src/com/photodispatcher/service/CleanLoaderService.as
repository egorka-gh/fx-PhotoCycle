package com.photodispatcher.service{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.AppConfig;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderLoad;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.services.OrderLoadService;
	
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
	public class CleanLoaderService extends EventDispatcher{
		
		[Bindable]
		public static var busy:Boolean; 

		[Bindable]
		public var state:String='';
		public var hasErr:Boolean;
		public var err:String;
		[Bindable]
		public var complited:int;

		private var progressTotal:int;
		private var config:AppConfig; 
		
		public function CleanLoaderService(){
			super(null);
		}
		
		private var lastRun:Date;
		private var timer:Timer;
		
		public function schedule():void{
			config=Context.config;
			if(!config || !config.clean_fs || config.clean_fs_days<=0)  return;
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

		public function cleanFileSystem():void{
			if(busy) return;
			complited=0;
			hasErr=false;
			err='';
			state='';
			folders2kill=[];
			//check config
			config=Context.config;
			if(!config || !config.clean_fs || config.clean_fs_days<=0 ){
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
		
		private var _orderService:OrderLoadService;
		private function get orderService():OrderLoadService{
			if(!_orderService) _orderService=Tide.getInstance().getContext().byType(OrderLoadService,true) as OrderLoadService;
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
			progressTotal=0;
			if(config.clean_fs_limit<=0) config.clean_fs_limit=100;
			//progress
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,0, progressTotal));
			state='Подготовка удаления';
			//get orders to clean
			var latch:DbLatch=new DbLatch(true);
			latch.addEventListener(Event.COMPLETE, onOrdersloaded);
			latch.addLatch(orderService.load4CleanFS(config.clean_fs_days, config.clean_fs_limit));
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
				complite();
				return;
			}
			
			var wrkFolder:File;
			var source:Source;
			var path:String; 
			
			var order:OrderLoad;
			var folder:File;
			var orderAdded:Boolean;
			for each (order in orders){
				orderAdded=false;
				if(order && order.ftp_folder){
					source=Context.getSource(order.source);
					if(source){
						path=source.getWrkFolder();
						if(checkFolder(path)) wrkFolder= new File(path);
						if(wrkFolder){
							folder=wrkFolder.resolvePath(order.ftp_folder);
							if(folder.exists && folder.isDirectory){
								folder=folder.parent;
								if(folder.exists && folder.isDirectory && folder.nativePath!=wrkFolder.nativePath){
									orderAdded=true;
									folders2kill.push(new CleanFileHolder(folder,order.id));
								}
							}
						}
					}
				}
				if(!orderAdded && order && order.id) markKilled(order.id);
			}
			startKill();
		}
		
		private function markKilled(orderId:String):void{
			var latch:DbLatch=new DbLatch(true);
			latch.addEventListener(Event.COMPLETE, onOrderMarked);
			latch.addLatch(orderService.markKilled(orderId));
			latch.start();
		}
		private function onOrderMarked(event:Event):void{
			var latch:DbLatch= event.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onOrderMarked);
				if(!latch.complite){
					state='Ошибка базы данных: '+latch.lastError;
				}
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
				complite();
				return;
			}
			currFolder=folders2kill.pop() as CleanFileHolder;
			if(!currFolder || !currFolder.file || !currFolder.file.exists || !currFolder.file.isDirectory){
				if(currFolder && currFolder.orderId){
					complited++;
					markKilled(currFolder.orderId);
				}
				killNextFolder();
				return;
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
				if(currFolder.orderId) markKilled(currFolder.orderId);
			}
			killNextFolder();
		}


	}
	
	
}