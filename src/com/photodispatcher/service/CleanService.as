package com.photodispatcher.service{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.AppConfig;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.services.OrderService;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	
	import mx.collections.ArrayCollection;
	
	import org.granite.tide.Tide;
	
	[Event(name="complete", type="flash.events.Event")]
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
		private var totalSources:int;
		private var config:AppConfig; 
		
		public function CleanService(){
			super(null);
		}
		
		public function cleanFileSystem():void{
			complited=0;
			hasErr=false;
			err='';
			state='';
			//check config
			config=Context.config;
			if(!config.clean_fs || config.clean_fs_state<=0 || config.clean_fs_days<=0){
				complite();
				return;
			}
			
			//get sources
			sources=Context.getSources();
			if(!sources){
				complite();
				return;
			}
			
			totalSources=sources.length;
			
			if(config.clean_fs_limit<=0) config.clean_fs_limit=500;
			
			busy=true;
			cleanNextFS();
		}
		
		
		private function complite():void{
			busy=false;
			if(!hasErr) state='Завершено, удалено '+complited.toString();
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		private function releaseErr(errMsg:String):void{
			hasErr=true;
			err=errMsg;
			state=errMsg;
			complite();
		}
		
		private function cleanNextFS():void{
			//progress
			state='Удалено ' +complited.toString();
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,(totalSources-sources.length), totalSources));

			if(sources.length==0){
				//complite
				busy=false;
				complite();
				return;
			}

			currSource=sources.pop() as Source;
			if(!currSource){
				cleanNextFS();
				return;
			}
			
			state=state+'. Обработка '+currSource.name;
			
			//check source folders
			var wrkPath:String=currSource.getWrkFolder();
			var prnPath:String=currSource.getPrtFolder();
			if(!checkFolder(wrkPath) && !checkFolder(prnPath)){
				cleanNextFS();
				return;
			}
			
			//get orders to clean
			var latch:DbLatch=new DbLatch(true);
			latch.addEventListener(Event.COMPLETE, onOrdersload);
			latch.addLatch(orderService.load4CleanFS(currSource.id, config.clean_fs_state, config.clean_fs_days, config.clean_fs_limit));
			latch.start();
		}
		
		private function onOrdersload(event:Event):void{
			var latch:DbLatch= event.target as DbLatch;
			var orders:ArrayCollection;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onOrdersload);
				if(!latch.complite){
					releaseErr('Ошибка базы данных: '+latch.lastError);
					return;
				}
				orders=latch.lastDataAC;
			}
			if(!orders || orders.length==0){
				cleanNextFS();
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

			var done:Array=[];
			var deleted:int=0;
			var order:Order;
			var folder:File;
			var delErr:Boolean;
			var wrkDeleted:Boolean;
			//state='Удалено ' +deleted.toString()+' ('+orders.length.toString()+')';
			//dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,done.length, orders.length));
			for each (order in orders){
				delErr=false;
				wrkDeleted=false;
				if(order && order.ftp_folder){
					if(wrkFolder){
						folder=wrkFolder.resolvePath(order.ftp_folder);
						if(folder.exists && folder.isDirectory){
							try{
								folder.deleteDirectory(true);
								deleted++;
								wrkDeleted=true;
							}catch(error:Error){
								delErr=true;
							}
						}
					}
					if(!delErr && prnFolder){
						folder=prnFolder.resolvePath(order.ftp_folder);
						if(folder.exists && folder.isDirectory){
							try{
								folder.deleteDirectory(true);
								if(!wrkDeleted) deleted++;
							}catch(error:Error){
								delErr=true;
							}
						}
					}
					if(!delErr) done.push(order.id);
				}
				//state='Удалено ' +deleted.toString()+' ('+orders.length.toString()+')';
				//dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,done.length, orders.length));
			}
			complited+=deleted;
			if(done.length>0){
				latch=new DbLatch(true);
				latch.addEventListener(Event.COMPLETE, onOrdersSave);
				latch.addLatch(orderService.markCleanFS(done));
				latch.start();
			}else{
				cleanNextFS();
			}
		}
		private function onOrdersSave(event:Event):void{
			var latch:DbLatch= event.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onOrdersSave);
				if(!latch.complite){
					releaseErr('Ошибка базы данных: '+latch.lastError);
					return;
				}
			}
			cleanNextFS();
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
	}
}