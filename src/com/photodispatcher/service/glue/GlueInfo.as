package com.photodispatcher.service.glue{
	import com.photodispatcher.interfaces.ISimpleLogger;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.model.mysql.entities.BookSynonymGlue;
	import com.photodispatcher.model.mysql.entities.Layerset;
	import com.photodispatcher.model.mysql.entities.OrderExtraInfo;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.model.mysql.services.PrintGroupService;
	import com.photodispatcher.model.mysql.services.TechPickerService;
	import com.photodispatcher.tech.picker.EndpaperSet;
	import com.photodispatcher.tech.picker.InterlayerSet;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	import org.granite.tide.Tide;
	
	[Bindable]
	[Event(name="complete", type="flash.events.Event")]
	public class GlueInfo extends EventDispatcher{
		
		public static const MODE_CHECK:int=0;
		public static const MODE_GETCOMMAND:int=1;

		protected static var interlayerSet:InterlayerSet;
		protected static var templateSet:Array;
		protected static var endpaperSet:InterlayerSet;

		public static function init():DbLatch{
			//load picker config
			var initLatch:DbLatch= new DbLatch();
			//initLatch.addEventListener(Event.COMPLETE, onInitLatch);
			interlayerSet= new InterlayerSet();
			endpaperSet= new EndpaperSet();
			initLatch.join(interlayerSet.init(-1));
			initLatch.join(endpaperSet.init(-1));
			var latch:DbLatch= new DbLatch();
			latch.addEventListener(Event.COMPLETE, onTeplatesLoad);
			var svc:TechPickerService=Tide.getInstance().getContext().byType(TechPickerService,true) as TechPickerService;
			latch.addLatch(svc.loadLayersets(Layerset.LAYERSET_TYPE_TEMPLATE, -1));
			initLatch.join(latch);
			latch.start();

			initLatch.start();
			return initLatch;
		}
		private static function onTeplatesLoad(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(!latch) return;
			latch.removeEventListener(Event.COMPLETE,onTeplatesLoad);
			if(latch.complite){
				templateSet=latch.lastDataArr;
			}
		}

		
		public function GlueInfo(mode:int=MODE_CHECK){
			super(null);
			this.mode=mode;
		}
		
		public var mode:int;
		public var hasErr:Boolean;
		public var errMsg:String;

		public var printGroupId:String;
		public var printGroup:PrintGroup;
		public var extraInfo:OrderExtraInfo;

		public var inerlayer:Layerset;
		public var template:Layerset;
		public var endPaper:Layerset;

		
		public var glueCommand:BookSynonymGlue;
		public var glueSheetsNum:int;

		public var loger:ISimpleLogger;

		protected function log(msg:String):void{
			if(loger) loger.log(msg);
		}

		public function load(pgId:String):DbLatch{
			printGroupId=pgId;
			var latch:DbLatch= new DbLatch();
			if(!pgId){
				latch.releaseError('Ошибка вызова');
				latch.start();
				return latch;
			}
			log('GlueInfo start load '+pgId);
			hasErr=false;
			glueSheetsNum=0;
			glueCommand=null;
			printGroup=null;
			extraInfo=null;
			inerlayer=null;
			template=null;
			endPaper=null;
			
			var svc:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
			latch.addLatch(svc.loadExtraIfoByPG(pgId));
			latch.addEventListener(Event.COMPLETE,onOrderFinde);
			
			//load pg
			var latchR:DbLatch= new DbLatch();
			var svcPG:PrintGroupService=Tide.getInstance().getContext().byType(PrintGroupService,true) as PrintGroupService;
			latchR.addEventListener(Event.COMPLETE,onPgLoad);
			latchR.addLatch(svcPG.loadById(pgId));
			latchR.start();
			latch.join(latchR);
			latch.start();
			return latch;
		}
		protected function onPgLoad(e:Event):void{
			var latch:DbLatch=e.target as DbLatch;
			log('GlueInfo printGroup loaded');
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onPgLoad);
				if(latch.complite){
					printGroup=latch.lastDataItem as PrintGroup;
				}
			}
		}
		protected function onOrderFinde(e:Event):void{
			var latch:DbLatch=e.target as DbLatch;
			log('GlueInfo ExtraInfo loaded');
			var ei:OrderExtraInfo;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onOrderFinde);
				extraInfo=latch.lastDataItem as OrderExtraInfo;
			}
			checkResult();
			log('GlueInfo complite');
			dispatchEvent(new Event(Event.COMPLETE));
		}

		protected function checkResult():Boolean{
			if(!printGroup){
				hasErr=true;
				errMsg='Не найдена группа печати';
			}
			if(!hasErr && !extraInfo){
				hasErr=true;
				errMsg='Нет доп информации по заказу';
			}
			
			if(!hasErr && !interlayerSet){
				hasErr=true;
				errMsg='Ошибка инициализации';
			}
			
			//checkget interlayer
			//check interlayer
			if(!hasErr){ 
				inerlayer=interlayerSet.getBySynonym(extraInfo.interlayer);
				//if(currExtraInfo.interlayer && !currInerlayer){
				if(!inerlayer){
					hasErr=true;
					errMsg='Неопределен тип прослойки "'+extraInfo.interlayer+'"';
				}
			}
			
			var bs:BookSynonym;
			if(!hasErr){
				bs=BookSynonym.getBookSynonymByPg(printGroup);
				if(!bs){
					hasErr=true;
					errMsg='Неопределен шаблон книги для "'+printGroup.alias+'"';
				}else{
					//detect glue command
					glueCommand=bs.getGlueCmd(printGroup.paper, inerlayer.id);
					if(!glueCommand || !glueCommand.glue_cmd_name){
						hasErr=true;
						errMsg='Неопределена команда склейки "'+printGroup.paper_name +'"-"'+inerlayer.name+'"';
					}
				}
			}
			if(hasErr){
				return false;
			}
			
			//calc sheets
			glueSheetsNum=printGroup.sheet_num;
			//interlayer
			if(inerlayer.sequenceMiddle) glueSheetsNum=glueSheetsNum+(printGroup.sheet_num-1)*inerlayer.sequenceMiddle.length;
			//template book start/end or endpaper
			glueSheetsNum+=glueCommand.add_layers;
			
			return true;
		}


	}
}