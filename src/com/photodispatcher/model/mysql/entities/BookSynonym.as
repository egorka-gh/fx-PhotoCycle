/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.services.BookSynonymService;
	import com.photodispatcher.util.GridUtil;
	import com.photodispatcher.view.itemRenderer.BooleanGridItemEditor;
	import com.photodispatcher.view.itemRenderer.CBoxGridItemEditor;
	
	import flash.events.Event;
	import flash.geom.Point;
	
	import mx.collections.ArrayList;
	import mx.core.ClassFactory;
	
	import org.granite.tide.Tide;
	
	import spark.components.gridClasses.GridColumn;

    [Bindable]
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.BookSynonym")]
    public class BookSynonym extends BookSynonymBase {
		public static const BOOK_TYPE_BOOK:int=1;
		public static const BOOK_TYPE_JOURNAL:int=2;
		public static const BOOK_TYPE_LEATHER:int=3;
		public static const BOOK_TYPE_CALENDAR:int=4;
		public static const BOOK_TYPE_MAGNET:int=5;
		public static const BOOK_TYPE_BCARD:int=6;
		public static const BOOK_TYPE_CANVAS:int=7;
		public static const BOOK_TYPE_CUP:int=8;
		
		public static const BOOK_PART_ANY:int=0;
		public static const BOOK_PART_COVER:int=1;
		public static const BOOK_PART_BLOCK:int=2;
		public static const BOOK_PART_INSERT:int=3;
		public static const BOOK_PART_AU_INSERT:int=4;

		
		public static function gridColumns(short:Boolean=false):ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			col= new GridColumn('synonym'); col.headerText='Имя папки'; result.addItem(col);
			if(!short){
				col= new GridColumn('synonym_type'); col.headerText='Тип синонима'; col.labelFunction=GridUtil.idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
				col= new GridColumn('book_type'); col.headerText='Тип книги'; col.labelFunction=GridUtil.idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
				col= new GridColumn('is_horizontal'); col.headerText='Горизотальная'; col.labelFunction=GridUtil.booleanToLabel; col.itemEditor=new ClassFactory(BooleanGridItemEditor); result.addItem(col);
				col= new GridColumn('lab_type'); col.headerText='Тип лабы'; col.labelFunction=GridUtil.idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			}
			return result;
		}

		private static var synonymMap:Object;
		private static var aliasMap:Object;
		private static var filter:int=0;
		public static function initSynonymMap():DbLatch{
			var svc:BookSynonymService=Tide.getInstance().getContext().byType(BookSynonymService,true) as BookSynonymService;
			var latch:DbLatch= new DbLatch();
			latch.debugName='BookSynonym.initSynonymMap';
			latch.addEventListener(Event.COMPLETE, onLoad);
			latch.addLatch(svc.loadFull());
			latch.start();
			return latch;
		}
		private static function onLoad(event:Event):void{
			var latch:DbLatch= event.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE,onLoad);
				if(latch.complite){
					var a:Array=latch.lastDataArr;
					if(!a) return;
					var newMap:Object=new Object();
					var newAliasMap:Object=new Object();
					var subMap:Object;
					var bs:BookSynonym;
					for each(bs in a){
						if(bs && bs.synonym){
							if(bs.synonym_type==0){
								//add to synonym map
								subMap=newMap[bs.src_type.toString()];
								if(!subMap){
									subMap= new Object();
									newMap[bs.src_type.toString()]=subMap;
								}
								subMap[bs.synonym]=bs;
							}else{
								//add to alias map
								newAliasMap[bs.synonym]=bs;
							}
						}
					}
					synonymMap=newMap;
					aliasMap=newAliasMap;
				}
			}
		}

		/**
		 * 
		 * @param path
		 * @param sourceType
		 * @return BookSynonym
		 */		
		public static function translatePath(path:String, sourceType:int=SourceType.SRC_FOTOKNIGA):BookSynonym{
			if(!path) return null;
			if(!synonymMap){
				throw new Error('Ошибка инициализации BookSynonym.initSynonymMap',OrderState.ERR_APP_INIT);
				return;
			}
			var map:Object=synonymMap[sourceType.toString()];
			if(!map) return null;
			return map[path] as BookSynonym; 
		}
		
		public static function translateAlias(alias:String):BookSynonym{
			if(!alias) return null;
			if(!aliasMap){
				throw new Error('Ошибка инициализации BookSynonym.initSynonymMap',OrderState.ERR_APP_INIT);
				return;
			}
			return aliasMap[alias] as BookSynonym; 
		}
		
		public static function guess(paper:int,coverSize:Point,blockSise:Point,sliceSise:Point):BookSynonym{
			if(!paper || !blockSise) return null;
			if(!synonymMap){
				throw new Error('Ошибка инициализации BookSynonym.initSynonymMap',OrderState.ERR_APP_INIT);
				return;
			}
			var bs:BookSynonym;
			var it:BookPgTemplate;
			var currCover:BookPgTemplate;
			var currSlice:BookPgTemplate;
			var currBlock:BookPgTemplate;
			var fit:Boolean;
			var resultCover:BookPgTemplate;
			var resultSlice:BookPgTemplate;
			var resultBlock:BookPgTemplate;
			var result:BookSynonym;
			
			for each(bs in aliasMap){
				//init templetes
				currCover=null;
				currBlock=null;
				currSlice=null;
				for each(it in bs.templates){
					if(it.book_part==BookSynonym.BOOK_PART_COVER && it.paper==paper && !it.is_pdf) currCover=it;
					if(it.book_part==BookSynonym.BOOK_PART_INSERT && it.paper==paper && !it.is_pdf) currSlice=it;
					if(it.book_part==BookSynonym.BOOK_PART_BLOCK && it.paper==paper && !it.is_pdf) currBlock=it;
				}
				//check template structure
				if( ((currCover && coverSize) || (!currCover && !coverSize)) && 
					((currSlice && sliceSise) || (!currSlice && !sliceSise)) 
					&& currBlock){
					//process synonym
					fit=true;
					//fit?
					if(currCover) fit=currCover.sheet_width>=coverSize.y;//Math.min(coverSize.x,coverSize.y);
					if(fit && currSlice) fit= currSlice.sheet_width>=sliceSise.y && currSlice.sheet_len>=sliceSise.x;
					//if(fit) fit=currBlock.sheet_width>=Math.min(blockSise.x,blockSise.y) && currBlock.sheet_len>=Math.max(blockSise.x,blockSise.y);
					if(fit) fit=currBlock.sheet_width>=blockSise.y && currBlock.sheet_len>=blockSise.x;
					//set result
					if(fit){
						if(result){
							//compare synonyms
							if(currCover) fit=currCover.sheet_width<=resultCover.sheet_width;
							if(fit && currSlice) fit=currSlice.sheet_width<=resultSlice.sheet_width && currSlice.sheet_len<=resultSlice.sheet_len;
							if(fit) fit=currBlock.sheet_width<=resultBlock.sheet_width && currBlock.sheet_len<=resultBlock.sheet_len;
						}
						if(fit){
							result=bs;
							resultCover=currCover;
							resultSlice=currSlice;
							resultBlock=currBlock;
						}
					}
				}
			}
			return result;
		}

		
		
		public function createPrintGroup(path:String, bookPart:int, butt:int=0):PrintGroup{
			var pg:PrintGroup;
			var it:BookPgTemplate;
			if(!templates) return null;
			for each(it in templates){
				if(it && it.book_part==bookPart){
					pg=it.createPrintGroup(path,book_type,butt);
				}
			}
			if(pg) pg.is_horizontal=is_horizontal;
			return pg;
		}
		
		public function get blockTemplate():BookPgTemplate{
			var it:BookPgTemplate;
			for each(it in templates){
				if(it.book_part==BOOK_PART_BLOCK) return it;
			}
			return null;
		}
		
		public function get coverTemplate():BookPgTemplate{
			var it:BookPgTemplate;
			for each(it in templates){
				if(it.book_part==BOOK_PART_COVER || it.book_part==BOOK_PART_INSERT) return it;
			}
			return null;
		}

    }
}