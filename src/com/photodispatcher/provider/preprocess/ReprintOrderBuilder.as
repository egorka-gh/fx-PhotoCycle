package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.OrderBuildEvent;
	import com.photodispatcher.event.OrderBuildProgressEvent;
	import com.photodispatcher.factory.PrintGroupBuilder;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrintGroupFile;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.entities.TechReject;
	import com.photodispatcher.model.mysql.entities.TechRejectItem;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.model.mysql.services.TechRejecService;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	
	import mx.collections.ArrayCollection;
	
	import org.granite.tide.Tide;
	
	public class ReprintOrderBuilder extends OrderBuilderBase{
		
		public function ReprintOrderBuilder(logStates:Boolean=true){
			super();
			this.logStates=logStates;
		}

		override public function stop():void{
			super.stop();
			if(builder){
				builder.stop();
				builder.removeEventListener(OrderBuildEvent.BUILDER_ERROR_EVENT,onBuilderError);
				builder.removeEventListener(OrderBuildEvent.ORDER_PREPROCESSED_EVENT, onOrderPreprocessed);
				builder.removeEventListener(ProgressEvent.PROGRESS, onPreprocessProgress);
			}
			builder=null;
			//restore rejects state (uncapture)
			setRejectsState(OrderState.REPRINT_WAITE);
			rejects=null;
		}

		override protected function startBuild():void{
			//load order
			rejects=null;
			srcPGs=[];
			loadOrder(lastOrder.id);
		}
		
		override protected function releaseWithError(error:int, msg:String):void{
			//restore rejects state (uncapture)
			if(error==OrderState.ERR_FILE_SYSTEM){
				//has no source images, cancel 
				setRejectsState(OrderState.PREPROCESS_INCOMPLETE);
			}else{
				setRejectsState(OrderState.REPRINT_WAITE);
			}
			rejects=null;
			super.releaseWithError(error, msg);
		}
		
		override protected function releaseComplite():void{
			super.releaseComplite();
			rejects=null;
		}
		
		
		
		private var rejects:ArrayCollection;
		private var srcPGs:Array;
		
		private function get orderService():OrderService{
			return Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
		}

		private function get rejectService():TechRejecService{
			return Tide.getInstance().getContext().byType(TechRejecService,true) as TechRejecService;
		}
		
		private function reportProgress(caption:String='',ready:Number=0, total:Number=0):void{
			dispatchEvent(new OrderBuildProgressEvent((caption?(lastOrder.id+' '+caption):''),ready,total));
		}

		private function loadOrder(orderId:String):void{
			if(!orderId){
				builderError('Internal error. Empty order id.');
				return;
			}
			//var svc:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
			
			lastOrder.printGroups=null;
			var latch:DbLatch=new DbLatch();
			latch.addEventListener(Event.COMPLETE,onOrderLoad);
			latch.addLatch(orderService.loadOrderFull(orderId));
			latch.start();
			
			rejects=null;
			var rlatch:DbLatch=new DbLatch();
			rlatch.addEventListener(Event.COMPLETE,onRejectsLoad);
			rlatch.addLatch(rejectService.loadByOrder(orderId,OrderState.REPRINT_WAITE));
			rlatch.join(latch);
			rlatch.start();
		}
		private function onOrderLoad(e:Event):void{
			var latch:DbLatch=e.target as DbLatch;
			var order:Order;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onOrderLoad);
				if(latch.complite) order=latch.lastDataItem as Order;
			}
			if(!order || !order.printGroups){
				//releaseWithError(OrderState.ERR_READ_LOCK,'Заказ не найден '+lastOrder.id);
				return;
			}
			/*
			var pgs:ArrayCollection=new ArrayCollection();
			for each( var pg:PrintGroup in order.printGroups){
				if(!pg.is_reprint) pgs.addItem(pg);
			}
			order.printGroups=pgs;
			*/
			lastOrder.state=OrderState.PRN_REPRINT;
			lastOrder=order;
		}

		private function onRejectsLoad(e:Event):void{
			var latch:DbLatch=e.target as DbLatch;
			var order:Order;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onRejectsLoad);
				if(!latch.complite){
					releaseWithError(OrderState.ERR_READ_LOCK,latch.error);
					return;
				}
				rejects=latch.lastDataAC;
			}
			if(forceStop) return;
			if(!rejects || rejects.length==0){
				if(logStates) StateLog.log(lastOrder.state,lastOrder.id,'','Нет перепечаток к обработке (1)');
				releaseComplite();
				return;
			}
			if(!lastOrder || !lastOrder.printGroups || lastOrder.printGroups.length==0){
				if(logStates) StateLog.log(lastOrder.state,lastOrder.id,'','Нет групп печати (1)');
				releaseComplite();
				return;
			}
			
			//fill/recreate source printgroups 
			if(!fillSrcPgs()) return;
			if(!srcPGs || srcPGs.length==0){
				if(logStates) StateLog.log(lastOrder.state,lastOrder.id,'','Нет групп печати (2)');
				releaseComplite();
				return;
			}
			
			//capture rejects
			for each(var reject:TechReject in rejects){
				var dt:Date= new Date();
				reject.state=OrderState.REPRINT_CAPTURED;
				reject.state_date=dt;
			}
			latch= new DbLatch();
			latch.addEventListener(Event.COMPLETE,oncaptureState);
			latch.addLatch(rejectService.captureState(rejects));
			latch.start();
			reportProgress('Захват на обработку');
		}
		private function oncaptureState(e:Event):void{
			var latch:DbLatch=e.target as DbLatch;
			var order:Order;
			if(!latch) return;
			latch.removeEventListener(Event.COMPLETE,oncaptureState);
			if(forceStop) return;
			if(!latch.complite){
				releaseWithError(OrderState.ERR_READ_LOCK,latch.error);
				return;
			}
			rejects=latch.lastDataAC;
			if(!rejects || rejects.length==0){
				if(logStates) StateLog.log(lastOrder.state,lastOrder.id,'','Нет перепечаток к обработке (2)');
				releaseComplite();
				return;
			}
			
			//mark reprints
			markReprints();
			//create reprint groups
			createReprint();
		}

		private function fillSrcPgs():Boolean{
			var srcArr:Array= lastOrder.printGroups.toArray();
			if(!srcArr) return false;
			
			var pg:PrintGroup;
			var pgf:PrintGroupFile;
			var newPg:PrintGroup;
			var newPgf:PrintGroupFile;
			
			var orderPath:String='';
			var orderWrkPath:String='';
			srcPGs=[];
			
			var src:Source=Context.getSource(lastOrder.source);
			if(!src){
				releaseWithError(OrderState.ERR_READ_LOCK,'Не определен источник заказа');
				return false;
			}
				
			orderPath=src.getPrtFolder()+File.separator+lastOrder.ftp_folder;
			orderWrkPath=src.getWrkFolder()+File.separator+lastOrder.ftp_folder;
			
			var pgPath:String='';
			var builder:PrintGroupBuilder= new PrintGroupBuilder();
			for each (pg in srcArr){
				if(pg && !pg.is_reprint && pg.files && pg.files.length>0){
					newPg=pg.clone();
					newPg.id=pg.id;
					//if(newPg.is_pdf){
					if(pg.book_type==BookSynonym.BOOK_TYPE_BOOK || pg.book_type==BookSynonym.BOOK_TYPE_JOURNAL || pg.book_type==BookSynonym.BOOK_TYPE_LEATHER){
						//recreate files
						if(!builder.recreateFromFilesystem(lastOrder,newPg)){
							releaseWithError(OrderState.ERR_FILE_SYSTEM,'Ошибка заполнения группы печати '+pg.id);
							return false;
						}
						pgPath=orderWrkPath+File.separator+newPg.path;
						//extend path
						for each(pgf in newPg.files){
							if(pgf) pgf.fullPath=pgPath+File.separator+pgf.file_name;//not needed
						}
					}else{
						/*
						newPg.bookTemplate=BookSynonym.getTemplateByPg(pg);
						if(!newPg.bookTemplate){
							releaseWithError(OrderState.ERR_PREPROCESS,'Не определен шаблон для '+ pg.id);
							return false;
						}
						*/
						pgPath=orderPath+File.separator+newPg.path;
						//clone files
						for each(pgf in pg.files){
							if(pgf){
								newPgf=pgf.clone();
								if(pgPath) newPgf.fullPath=pgPath+File.separator+pgf.file_name;//not needed
								newPg.addFile(newPgf);
							}
						}
					}
					srcPGs.push(newPg);
				}
			}
			return true;
		}

		private function markReprints():void{
			for each(var reject:TechReject in rejects){
				if(reject.items){
					for each(var ritem:TechRejectItem in reject.items){
						var pg:PrintGroup=pgById(ritem.pg_src); 
						if(pg){
							if(ritem.thech_unit==TechReject.UNIT_SHEET){
								markFile(pg, ritem.book, ritem.sheet);
								setActivity(pg,reject);
								pg.addReject(ritem.book, ritem.sheet, ritem.thech_unit, reject.activity);
							}else{
								// UNIT_BOOK or UNIT_BLOCK or UNIT_COVER
								markFile(pg, ritem.book);
								setActivity(pg,reject);
								pg.addReject(ritem.book, -1, ritem.thech_unit, reject.activity);
								if(ritem.thech_unit==TechReject.UNIT_BOOK){
									pg=pgBypg(pg);
									markFile(pg, ritem.book);
									setActivity(pg,reject);
									if(pg) pg.addReject(ritem.book, -1, ritem.thech_unit, reject.activity);
								}
							}
						}
					}
				}
			}
		}
		
		private function pgById(pgId:String):PrintGroup{
			if(!pgId) return null;
			var p:PrintGroup;
			for each(p in srcPGs){
				if(p.id==pgId) return p;
			}
			return null;
		}

		private function pgBypg(pg:PrintGroup):PrintGroup{
			if(!pg) return null;
			var p:PrintGroup;
			for each(p in srcPGs){
				if(pg.id!=p.id && pg.sub_id==p.sub_id) return p;
			}
			return null;
		}

		private function markFile(pg:PrintGroup, book:int, sheet:int=-1):void{
			if(!pg) return;
			if(book<=0) return;
			for each (var pgf:PrintGroupFile in pg.files){
				if(pgf.book_num==book){
					if(sheet==-1 || sheet==pgf.page_num){
						pgf.reprint=true;
						if(sheet!=-1) break;
					}
				}
			}
		}
		
		private function setActivity(pg:PrintGroup, tr:TechReject):void{
			if(!pg || !tr || (!tr.sa_type_name && !tr.sa_remark)) return;
			if(pg.staffActivityCaption) return;
			pg.staffActivityCaption='';
			if(tr.sa_type_name) pg.staffActivityCaption=tr.sa_type_name;
			if(tr.sa_remark){
				if(pg.staffActivityCaption) pg.staffActivityCaption+=' ';
				pg.staffActivityCaption+=tr.sa_remark;
			}
		}
		
		private var builder:ReprintBuilder;
		
		protected function createReprint():void{
			if(forceStop) return;
			//clone order
			if(logStates){
				var logStr:String='Формирование перепечатки';
				var reject:TechReject=rejects.getItemAt(0) as TechReject;
				if(reject){
					if(reject.sa_type_name) logStr=logStr+' '+reject.sa_type_name;
					if(reject.sa_remark) logStr=logStr+' '+reject.sa_remark;
				}
				StateLog.log(OrderState.PRN_REPRINT,lastOrder.id,'',logStr);
			}
			var o:Order= new Order();
			o.id=lastOrder.id;
			o.source=lastOrder.source;
			o.ftp_folder=lastOrder.ftp_folder;
			o.printGroups=new ArrayCollection(srcPGs);
			//start bulder
			builder=new ReprintBuilder();
			//builder.reprintActivity=activity;
			builder.startingPgIdx=lastOrder.printGroups.length;
			//listen
			builder.addEventListener(OrderBuildEvent.BUILDER_ERROR_EVENT,onBuilderError);
			builder.addEventListener(OrderBuildEvent.ORDER_PREPROCESSED_EVENT, onOrderPreprocessed);
			builder.addEventListener(ProgressEvent.PROGRESS, onPreprocessProgress);
			//start
			builder.build(o);
		}
		private function onPreprocessProgress(e:OrderBuildProgressEvent):void{
			dispatchEvent(e.clone());
		}
		private function onBuilderError(evt:OrderBuildEvent):void{
			if(builder){
				builder.removeEventListener(OrderBuildEvent.BUILDER_ERROR_EVENT,onBuilderError);
				builder.removeEventListener(OrderBuildEvent.ORDER_PREPROCESSED_EVENT, onOrderPreprocessed);
				builder.removeEventListener(ProgressEvent.PROGRESS, onPreprocessProgress);
			}
			builder=null;
			if(forceStop) return;
			releaseWithError(evt.err,evt.err_msg);
			dispatchEvent(new OrderBuildProgressEvent());
		}
		private function onOrderPreprocessed(evt:OrderBuildEvent):void{
			if(builder){
				builder.removeEventListener(OrderBuildEvent.BUILDER_ERROR_EVENT,onBuilderError);
				builder.removeEventListener(OrderBuildEvent.ORDER_PREPROCESSED_EVENT, onOrderPreprocessed);
				builder.removeEventListener(ProgressEvent.PROGRESS, onPreprocessProgress);
			}
			var newPGroups:Array;
			if(builder.lastOrder && builder.lastOrder.printGroups) newPGroups=builder.lastOrder.printGroups.toArray();
			builder=null;
			//if(forceStop) return;
			
			if(evt.err<0){
				//completed vs error
				if(!forceStop) releaseWithError(evt.err,evt.err_msg);
			}else{
				//add generated pgs to rejects
				
				//finalise reprints
				setRejectsState(OrderState.PRN_REPRINT,newPGroups);
				if(!forceStop) releaseComplite();
			}
			dispatchEvent(new OrderBuildProgressEvent());
		}
		
		private function setRejectsState(state:int, newPGroups:Array=null):void{
			if(!rejects || rejects.length==0) return;
			for each(var reject:TechReject in rejects){
				var dt:Date=new Date();
				reject.state=state;
				reject.state_date= dt;
				
				//unused info
				//actual reject info stored in PrintGroupReject 
				//create printgroup links 
				if(newPGroups && newPGroups.length>0 && reject.items){
					reject.pgroups=null;
					for each(var ritem:TechRejectItem in reject.items){
						var pgReprint:PrintGroup=ArrayUtil.searchItem('reprint_id',ritem.pg_src,newPGroups) as PrintGroup;
						if(pgReprint){
							reject.addPrintgroupLink(ritem.pg_src,pgReprint.id);
							if(ritem.thech_unit==TechReject.UNIT_BOOK && pgReprint.book_part!=BookSynonym.BOOK_PART_BLOCKCOVER){
								//finde related cover or block
								var p:PrintGroup;
								var srcPgId:String;
								for each(p in srcPGs){
									if(p.book_part!=pgReprint.book_part && pgReprint.sub_id==p.sub_id){
										srcPgId=p.id;
										break;
									}
								}
								if(srcPgId){
									pgReprint=ArrayUtil.searchItem('reprint_id',srcPgId,newPGroups) as PrintGroup;
									if(pgReprint) reject.addPrintgroupLink(srcPgId,pgReprint.id);
								}

							}
						}
					}
				}
				
			}
			var latch:DbLatch= new DbLatch();
			//latch.addEventListener(Event.COMPLETE,oncaptureState);
			latch.addLatch(rejectService.updateRejectBatch(rejects));
			latch.start();
		}

	}
}