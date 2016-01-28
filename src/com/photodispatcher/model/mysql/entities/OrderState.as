/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.services.OrderStateService;
	
	import flash.events.Event;
	
	import mx.collections.ArrayCollection;
	
	import org.granite.tide.Tide;

    [Bindable]
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.OrderState")]
    public class OrderState extends OrderStateBase {
		//err state
		public static const ERR_PRINT_POST:int=-300;
		public static const ERR_PRINT_POST_FOLDER_NOT_FOUND:int=-301;
		public static const ERR_PRINT_LAB_FOLDER_NOT_FOUND:int=-302;
		public static const ERR_READ_LOCK:int=-309;
		public static const ERR_WRITE_LOCK:int=-310;
		public static const ERR_FTP:int=-311;
		public static const ERR_WEB:int=-312;
		public static const ERR_FILE_SYSTEM:int=-314;
		public static const ERR_PREPROCESS:int=-315;
		public static const ERR_PREPROCESS_REMOTE:int=-316;
		public static const ERR_LOAD_REMOTE:int=-317;//04.04.2013
		public static const ERR_GET_PROJECT:int=-318;//22.05.2013
		public static const ERR_APP_INIT:int=-319;//
		public static const ERR_PRODUCTION_NOT_SET:int=-320;
		public static const ERR_LOCK_FAULT:int=-321;
		public static const ERR_WRONG_STATE:int=-322;
		
		//flow state
		//public static const FTP_RELOAD:int=95;
		public static const FTP_WAITE:int=100;
		public static const FTP_FORWARD:int=101;
		public static const FTP_WEB_CHECK:int=103;
		public static const FTP_WEB_OK:int=104;
		public static const FTP_CAPTURED:int=105;
		public static const FTP_WAITE_SUBORDER:int=107; //22.05.13
		public static const FTP_GET_PROJECT:int=108; //22.05.13
		public static const FTP_LIST:int=109;
		public static const FTP_LOAD:int=110;
		public static const FTP_DEPLOY:int=111;//04.04.2013
		public static const FTP_REMOTE:int=112;//04.04.2013
		
		public static const FTP_INCOMPLITE:int=120;
		public static const FTP_COMPLETE:int=130;
		
		public static const COLOR_CORRECTION_WAITE:int=139;
		public static const COLOR_CORRECTION:int=140;
		
		public static const PREPROCESS_WAITE:int=150;
		//public static const PREPROCESS_DEPLOY:int=124;
		//public static const PREPROCESS_REMOTE:int=125;
		public static const PREPROCESS_FORVARD:int=151;
		public static const PREPROCESS_WEB_CHECK:int=155;
		public static const PREPROCESS_WEB_OK:int=156;
		public static const PREPROCESS_CAPTURED:int=157;
		public static const PREPROCESS_RESIZE:int=160;
		public static const PREPROCESS_PDF:int=165;
		public static const PREPROCESS_INCOMPLETE:int=170;
		public static const PREPROCESS_COMPLETE:int=180;
		
		public static const PRN_WAITE_ORDER_STATE:int=199;
		public static const PRN_WAITE:int=200;
		public static const PRN_QUEUE:int=203;
		public static const PRN_WEB_CHECK:int=205;
		public static const PRN_WEB_OK:int=206;
		public static const PRN_PREPARE:int=209;
		public static const PRN_POST:int=210;
		//public static const PRN_POST_COMPLITE:int=212;
		public static const PRN_CANCEL:int=215;
		public static const PRN_AUTOPRINTLOG:int=220;
		//public static const PRN_POST_FORWARD:int=220;
		public static const PRN_PRINT:int=250;
		public static const PRN_REPRINT:int=251;
		public static const PRN_INPRINT:int=255;
		public static const PRN_COMPLETE:int=300;
		
		public static const CANCELED_OLD:int=310;
		
		public static const TECH_BFOLDING:int=318;
		public static const TECH_FOLDING:int=320;
		public static const TECH_LAMINATION:int=330;
		public static const TECH_COVER_MADE:int=335;
		public static const TECH_PICKING:int=340;
		public static const TECH_GLUING:int=350;
		public static const TECH_CUTTING:int=360;
		public static const TECH_COVER_BLOK_PICKING:int=370;
		public static const TECH_COVER_BLOK_JOIN:int=380;
		public static const TECH_OTK:int=450;
		/*
		public static const PACKAGE_START:int=455;
		public static const PACKAGE_PACKED:int=457;
		public static const PACKAGE_SENDING:int=460;
		*/
		public static const PACKAGE_PACKED:int=460;
		public static const PACKAGE_SEND:int=465;
		public static const PACKAGE_SEND_SITE:int=466;
		public static const CANCELED_SYNC:int=505;
		public static const CANCELED:int=510;
		public static const CANCEL_PACKAGE_JOIN:int=511;
		public static const CANCELED_PRODUCTION:int=515;
		public static const SKIPPED:int=520;
		
		private static var stateMap:Object;
		
		public static function getStateName(id:int):String{
			if(!stateMap){
				throw new Error('Ошибка инициализации OrderState.initSynonymMap',OrderState.ERR_APP_INIT);
				return;
			}
			var os:OrderState;
			if(stateMap) os=stateMap[id.toString()] as OrderState;
			return os?os.name:'';
		}
		
		public static function getStateArray(from:int=-1, to:int=-1, excludeRuntime:Boolean=false):Array{
			if(!stateMap){
				throw new Error('Ошибка инициализации OrderState.initSynonymMap',OrderState.ERR_APP_INIT);
				return;
			}
			var result:Array=[];
			if(from==-1) from=int.MIN_VALUE;
			if(to==-1) to=int.MAX_VALUE;
			if(stateMap){
				var os:OrderState;
				for (var key:Object in stateMap){
					os=stateMap[key] as OrderState;
					if(os && os.id>=from && os.id<to && (!excludeRuntime || os.runtime==0)) result.push(os);
				}
			}
			result.sortOn('id',Array.NUMERIC);
			return result;
		}
		
		public static function getStateList():ArrayCollection{
			if(!stateMap){
				throw new Error('Ошибка инициализации OrderState.initSynonymMap',OrderState.ERR_APP_INIT);
				return;
			}
			var result:ArrayCollection=new ArrayCollection();
			if(stateMap){
				var os:OrderState;
				for (var key:Object in stateMap){
					os=stateMap[key] as OrderState;
					if(os) result.addItem(os);
				}
			}
			return result;
		}
		
		public static function initStateMap():DbLatch{
			var svc:OrderStateService=Tide.getInstance().getContext().byType(OrderStateService,true) as OrderStateService;
			var latch:DbLatch= new DbLatch();
			latch.debugName='OrderState.initStateMap';
			latch.addEventListener(Event.COMPLETE, onLoad);
			latch.addLatch(svc.loadAll());
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
					stateMap=new Object();
					for each(var o:Object in a){
						var s:OrderState= o as OrderState;
						if(s) stateMap[s.id.toString()]=s;
					}
				}
			}
		}


    }
}