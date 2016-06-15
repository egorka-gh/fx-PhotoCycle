/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.services {
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	
	import mx.collections.ArrayCollection;
	
	import org.granite.tide.Tide;

    [RemoteClass(alias="com.photodispatcher.model.mysql.services.OrderService")]
    public class OrderService extends OrderServiceBase {
		
		public function findeById(id:String, byBarcode:Boolean=false):DbLatch{
			if(!id) return null;
			var latch:DbLatch= new DbLatch();
			if ((id.charAt(0) >= 'A' && id.charAt(0) <= 'Z') || (id.charAt(0) >= 'a' && id.charAt(0) <= 'z')){
				//old barcode
				var codeChar:String=id.charAt(0);
				id=id.substr(1);
				//remove leading 0
				if(id.charAt(0)=='0') id=id.substr(1);
				//remove book
				var idx:int=id.indexOf(':');
				if(idx!=-1)	id=id.substring(0,idx);
				latch.addLatch(loadOrderBySrcCode(codeChar,id));
			}else{
				if(!byBarcode){
					//manual search
					id='%'+id+'%';
				}else{
					if(id.length<6) return null;
					/*
					//parse barcode
					var src:int=int(id.substr(0,2));
					id=id.substr(2);
					id=src.toString()+'_'+id.substr(0, id.length-3); //remove book
					*/
					id=PrintGroup.orderIdFromBookBarcode(id);
				}
				latch.addLatch(loadOrder(id));
			}
			return latch;
		}

		public function findeSuborder(id:String, byBarcode:Boolean=false):DbLatch{
			var byPg:Boolean=false;
			var barcode:String=id;
			var latch:DbLatch= new DbLatch();
			var codeChar:String=null;
			
			if(!id){
				latch.complite=false;
				latch.hasError=true;
				latch.error='Не верный ШК';
				return latch;
			}
			if ((id.charAt(0) >= 'A' && id.charAt(0) <= 'Z') || (id.charAt(0) >= 'a' && id.charAt(0) <= 'z')){
				//old barcode
				codeChar=id.charAt(0);
				id=id.substr(1);
				//remove leading 0
				if(id.charAt(0)=='0') id=id.substr(1);
				//remove book
				var idx:int=id.indexOf(':');
				if(idx!=-1)	id=id.substring(0,idx);
				id='%\\_'+id;
			}else{
				if(!byBarcode){
					//manual search
					id='%'+id+'%';
				}else{
					byPg=true;
					id=PrintGroup.idFromBookBarcode(id);
					if(!id){
						latch.complite=false;
						latch.hasError=true;
						latch.error='Не верный ШК :'+barcode;
						return latch;
					}
				}
			}
			if(byPg){
				latch.addLatch(loadSubOrderByPg(id));
			}else{
				latch.addLatch(loadSubOrderByOrder(id,codeChar));
			}
			return latch;
		}

		public static function getLock(key:String):DbLatch{
			if(!key) return null;
			var service:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
			var latch:DbLatch= new DbLatch(true);
			latch.addLatch(service.getLock(key, Context.appID));
			return latch;
		}

		public static function releaseLock(key:String):DbLatch{
			if(!key) return null;
			var service:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
			var latch:DbLatch= new DbLatch(true);
			latch.addLatch(service.releaseLock(key, Context.appID));
			return latch;
		}

		public static function clearSoftLocks():DbLatch{
			var service:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
			var latch:DbLatch= new DbLatch(true);
			latch.addLatch(service.clearLocks());
			return latch;
		}

		public static function getPreprocessLock(orderid:String):DbLatch{
			if(!orderid) return null;
			return getLock('preprocess:'+orderid);
		}
		
		public static function releasePreprocessLock(orderid:String):DbLatch{
			if(!orderid) return null;
			return releaseLock('preprocess:'+orderid);
		}

		public static function getLoadLock(orderid:String):DbLatch{
			if(!orderid) return null;
			return getLock('load:'+orderid);
		}
		
		public static function releaseLoadLock(orderid:String):DbLatch{
			if(!orderid) return null;
			return releaseLock('load:'+orderid);
		}

		public static function getPrnQueueLock():DbLatch{
			return getLock('prnQueue');
		}
		
		public static function releasePrnQueueLock():DbLatch{
			return releaseLock('prnQueue');
		}

    }
    
}
