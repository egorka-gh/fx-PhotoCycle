package com.photodispatcher.provider.preprocess{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.OrderBuildProgressEvent;
	import com.photodispatcher.event.OrderPreprocessEvent;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrintGroupFile;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.StaffActivity;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.model.mysql.services.StaffActivityService;
	
	import flash.events.Event;
	import flash.events.ProgressEvent;
	
	import mx.collections.ArrayCollection;
	import mx.collections.ListCollectionView;
	
	import org.granite.tide.Tide;
	
	public class ReprintBuilder extends OrderBuilderBase{

		public var reprintActivity:StaffActivity;
		public var startingPgIdx:int;
		private var preprocessTask:PreprocessTask;
		
		//implement full cycle (create & build & save in to database)
		//order - clone of original order vs pringroups 4 reprint only (no existing original pgs!!!!)
		public function ReprintBuilder(){
			super();
		}
		
		override public function stop():void{
			super.stop();
			if(preprocessTask){
				preprocessTask.stop();
				preprocessTask.removeEventListener(OrderPreprocessEvent.ORDER_PREPROCESSED_EVENT, onOrderResize);
				preprocessTask.removeEventListener(ProgressEvent.PROGRESS, onPreprocessProgress);
				preprocessTask=null;
			}
		}
		
		
		override protected function startBuild():void{

			if((!lastOrder.printGroups || lastOrder.printGroups.length==0)){	
				releaseComplite();
				return;
			}
			
			if(startingPgIdx<=0){
				builderError('Не задан стартовый индекс групп печати.');
				return;
			}
			var source:Source=Context.getSource(lastOrder.source);
			if(!source){
				builderError('Internal error. Null source.');
				return;
			}
			

			var pg:PrintGroup;
			var pgf:PrintGroupFile;
			var arrPG:Array=[];
			
			//check pgs by files
			//remove vs no reprint files
			//get reprint pgs
			for each (pg in lastOrder.printGroups){
				if(pg){
					for each (pgf in pg.files){
						if(pgf && pgf.reprint){
							arrPG.push(pg);
							break;
						}
					}
				}
			}

			if((arrPG.length==0)){
				lastOrder.printGroups=null;
				releaseComplite();
				return;
			}
			
			lastOrder.printGroups= new ArrayCollection(arrPG);
			
			//look for pdf pgs and fill simple
			//get reprint files
			var pgIdx:int=startingPgIdx;
			var prints:int;
			var pdfPG:Array=[];
			//var simplePG:Array=[];
			var files:ListCollectionView;
			for each (pg in arrPG){
				if(pg){
					//set pg props
					pgIdx++;
					prints=0;
					pg.is_reprint=true;
					pg.reprint_id=pg.id;
					pg.id=lastOrder.id+'_'+pgIdx.toString();
					pg.prn_queue=0;
					
					if(reprintActivity){
						pg.staffActivityCaption='';
						if(reprintActivity.sa_type_name) pg.staffActivityCaption=reprintActivity.sa_type_name;
						if(reprintActivity.remark){
							if(pg.staffActivityCaption) pg.staffActivityCaption+=' ';
							pg.staffActivityCaption+=reprintActivity.remark;
						}
					}
					
					//if(pg.is_pdf){
					if(pg.book_type==BookSynonym.BOOK_TYPE_BOOK || pg.book_type==BookSynonym.BOOK_TYPE_JOURNAL || pg.book_type==BookSynonym.BOOK_TYPE_LEATHER){
						//books
						pdfPG.push(pg);
					}else{
						//reprint photo & other
						pg.state=OrderState.PRN_WAITE;
						//get files
						files=pg.files;
						pg.resetFiles();
						for each (pgf in files){
							if(pgf && pgf.reprint){
								pgf.print_group=pg.id;
								pg.addFile(pgf);
								prints+=pgf.prt_qty>0?pgf.prt_qty:1;
							}
						}
						pg.file_num=pg.files.length;
						pg.prints=prints;
						pg.book_num=1;
						pg.sheet_num=pg.files.length;
						//simplePG.push(pg);
					}
					
				}
			}

			if(pdfPG.length==0){
				//nothig prepare just save to data base
				saveToDatabase();
				return;
			}

			//build reprints
			preprocessTask=new PreprocessTask(lastOrder,source.getWrkFolder(),source.getPrtFolder(),true,true);
			preprocessTask.addEventListener(OrderPreprocessEvent.ORDER_PREPROCESSED_EVENT, onOrderResize);
			preprocessTask.addEventListener(ProgressEvent.PROGRESS, onPreprocessProgress);
			preprocessTask.run();
		}
		
		private function saveToDatabase():void{
			//save pgs
			for each (var pg:PrintGroup in lastOrder.printGroups){
				if(pg){
					pg.state=OrderState.PRN_WAITE;
				}
			}
			var svc:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
			var latch:DbLatch= new DbLatch(true);
			latch.addEventListener(Event.COMPLETE,onReprint);
			latch.addLatch(svc.addReprintPGroups(lastOrder.printGroups));
			latch.start();
		}
		private function onReprint(e:Event):void{
			var latch:DbLatch=e.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onReprint);
				if(!latch.complite){
					builderError('Ошибка базы данных. '+latch.error);
					return;
				}
			}
			
			if(!reprintActivity){
				releaseComplite();
				return;
			}
			
			//log activity
			//fill activity list
			var activityList:ArrayCollection= new ArrayCollection();
			var sa:StaffActivity;
			for each (var pg:PrintGroup in lastOrder.printGroups){
				if(pg){
					sa=reprintActivity.clone();
					sa.order_id=pg.order_id;
					sa.pg_id=pg.id;
					activityList.addItem(sa);
				}
			}

			if(activityList && activityList.length>0){
				var svc:StaffActivityService=Tide.getInstance().getContext().byType(StaffActivityService,true) as StaffActivityService;
				latch= new DbLatch();
				//latch.addEventListener(Event.COMPLETE,onReprint);
				latch.addLatch(svc.logActivityBatch(activityList));
				latch.start();
			}
			releaseComplite();
		}

		private function onPreprocessProgress(e:OrderBuildProgressEvent):void{
			dispatchEvent(e.clone());
		}

		private function onOrderResize(e:OrderPreprocessEvent):void{
			if(preprocessTask){
				preprocessTask.removeEventListener(OrderPreprocessEvent.ORDER_PREPROCESSED_EVENT, onOrderResize);
				preprocessTask.removeEventListener(ProgressEvent.PROGRESS, onPreprocessProgress);
			}
			preprocessTask=null;
			if(e.err==0){
				saveToDatabase();
			}else{
				releaseWithError(e.err,e.err_msg);
			}
			dispatchEvent(new OrderBuildProgressEvent());
		}

	}
}