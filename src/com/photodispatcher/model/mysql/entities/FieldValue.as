/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.services.DictionaryService;
	
	import flash.events.Event;
	
	import org.granite.tide.Tide;

    [Bindable]
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.FieldValue")]
    public class FieldValue extends FieldValueBase {
		public static const PRINT_FAMILY:int=1;
		public static const ORDER_FAMILY:int=2;
		
		private static var synonymMap:Object;

		public static function initSynonymMap():DbLatch{
			var dict:DictionaryService=Tide.getInstance().getContext().byType(DictionaryService,true) as DictionaryService;
			var latch:DbLatch= new DbLatch();
			latch.debugName='FieldValue.initSynonymMap';
			latch.addEventListener(Event.COMPLETE, onLoad);
			latch.addLatch(dict.getFieldValueSynonims());
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
					var subMap:Object;
					var fv:FieldValue;
					var fa:Array;
					for each(fv in a){
						if(fv){
							subMap=newMap[fv.src_type.toString()];
							if(!subMap){
								subMap= new Object();
								newMap[fv.src_type.toString()]=subMap;
							}
							fa=subMap[fv.synonym] as Array;
							if(!fa){
								fa=[];
								subMap[fv.synonym]=fa;
							}
							fa.push(fv);
						}
					}
					synonymMap=newMap;
				}
			}
		}

		/**
		 * parses print properties from path
		 * @param sourceType
		 * @return array of FieldValue 
		 * 
		 */
		public static function translatePath(sourceType:int, path:String):Array{
			if(!synonymMap){
				throw new Error('Ошибка инициализации FieldValue.initSynonymMap',OrderState.ERR_APP_INIT);
				return;
			}
			var result:Array=[];
			if(!path) return result;
			var map:Object=synonymMap[sourceType.toString()];
			if(!map) return result;
			
			var parse:String=path;
			var synonym:String;
			var re:RegExp;
			var idx:int;
			for (synonym in map){
				if(!parse) break;
				if(synonym){
					re=new RegExp(synonym,'gi');
					idx=parse.search(re);
					if(idx!=-1){
						result=result.concat(map[synonym]);
						parse=parse.replace(re,'');
					}
				}
			}
			return result;
		}
		
		/**
		 * translate word 2 value
		 * @param 
		 * @return FieldValue 
		 * 
		 */
		public static function translateWord(sourceType:int, word:String, field:String):FieldValue{
			if(!synonymMap){
				throw new Error('Ошибка инициализации FieldValue.initSynonymMap',OrderState.ERR_APP_INIT);
				return;
			}
			//var result:FieldValue;
			if(!word || !field) return null;
			var map:Object=synonymMap[sourceType.toString()];
			if(!map) return null;
			var fa:Array=map[word];
			if(fa){
				var fv:FieldValue;
				for each(fv in fa){
					if(fv && fv.field==field) return fv;
				}
			}
			return null;
		}

    }
}