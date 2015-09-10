package com.photodispatcher.tech.picker{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.LayerAllocation;
	import com.photodispatcher.model.mysql.entities.FieldValue;
	import com.photodispatcher.service.barcode.FeederController;
	
	import flash.net.SharedObject;
	
	import mx.collections.ArrayCollection;
	import mx.events.CollectionEvent;

	public class TraySetByController extends TraySet{
		
		public function TraySetByController(){
			
		}
		
		public function init(controllers:Array):Boolean{
			_prepared=false;
			if(!controllers) return;
			//loadTrays
			var so:SharedObject=SharedObject.getLocal('tech_tray_c','/');
			var arr:Array=[];
			var i:int;
			if(so.data['tech_tray_c'] && so.data['tech_tray_c'] is Array){
				arr=so.data['tech_tray_c'];
			}
			if(!arr){
				arr=[];
			}else if(arr.length>controllers.length){
				arr.length=controllers.length;
			}
			//init to controllers.length
			for(i=arr.length;i<controllers.length;i++) arr.push(0);
			
			var ac:ArrayCollection=Context.getAttribute('layerValueList') as ArrayCollection;
			if(!ac) return false;
			layers=ac.source;
			if(!layers) return false;

			var tarr:Array=new Array(controllers.length);
			var id:int;
			var la:LayerAllocation;
			for (i= 0; i < controllers.length; i++){
				la= new LayerAllocation();
				la.tray=i;
				la.layer=arr[i];
				la.controller=controllers[i] as FeederController;
				la.layer_name=getLayerName(arr[i]);
				tarr[i]=la;
			}
			
			if(tarys) tarys.removeEventListener(CollectionEvent.COLLECTION_CHANGE, ontTaysChange);
			tarys= new ArrayCollection(tarr);
			tarys.addEventListener(CollectionEvent.COLLECTION_CHANGE, ontTaysChange);
			
			//create layer -> tray map
			var fv:FieldValue;
			curLayerTrayMap=new Object();
			for each(fv in layers){
				curLayerTrayMap[fv.value.toString()]=-1;
			}

			_prepared=true;
			return true;
		}
	}
}