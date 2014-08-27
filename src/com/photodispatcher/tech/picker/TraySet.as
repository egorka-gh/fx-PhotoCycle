package com.photodispatcher.tech.picker{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.LayerAllocation;
	import com.photodispatcher.model.mysql.entities.FieldValue;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.net.SharedObject;
	
	import mx.collections.ArrayCollection;
	import mx.events.CollectionEvent;

	public class TraySet{
		
		[Bindable]
		public var tarys:ArrayCollection;

		//[Bindable]
		//public var hasEndpaperTray:Boolean;
		
		private var curLayerTrayMap:Object;
		private var layers:Array;

		private var _prepared:Boolean;
		public function get prepared():Boolean{
			return _prepared;
		}

		public function TraySet(){
			_prepared=init();
		}
		
		private function init():Boolean{
			//loadTrays
			var so:SharedObject=SharedObject.getLocal('tech_tray','/');
			var arr:Array;
			if(so.data['tech_tray'] && so.data['tech_tray'] is Array){
				arr=so.data['tech_tray'];
			}
			if(!arr){
				arr=[0,0,0,0,0,0,0,0];
			}else if(arr.length!=8){
				arr.length=8;
			}
			var ac:ArrayCollection=Context.getAttribute('layerValueList') as ArrayCollection;
			if(!ac) return false;
			layers=ac.source;
			if(!layers) return false;
			var tarr:Array=new Array(8);
			var id:int;
			var i:int;
			var la:LayerAllocation;
			for (i= 0; i < 8; i++){
				la= new LayerAllocation();
				la.tray=i;
				la.layer=arr[i];
				//if(la.layer==Layer.LAYER_ENDPAPER) hasEndpaperTray=true;
				la.layer_name=getLayerName(arr[i]);
				tarr[i]=la;
				//tarr[i]=(ArrayUtil.searchItem('value',arr[i],layers) as FieldValue);
			}
			
			//create layer -> tray map
			var fv:FieldValue;
			curLayerTrayMap=new Object();
			for each(fv in layers){
				curLayerTrayMap[fv.value.toString()]=-1;
			}
			tarys= new ArrayCollection(tarr);
			tarys.addEventListener(CollectionEvent.COLLECTION_CHANGE, ontTaysChange);
			return true;
		}
		
		private function ontTaysChange(evt:CollectionEvent):void{
			//save
			var so:SharedObject=SharedObject.getLocal('tech_tray','/');
			var arr:Array=[0,0,0,0,0,0,0,0];
			//var hasEp:Boolean=false;
			//var fv:FieldValue;
			var la:LayerAllocation;
			var i:int;
			var tarr:Array=tarys.source;
			if(!tarr) return;
			for (i= 0; i < tarr.length; i++){
				la=tarr[i] as LayerAllocation;
				if(la){
					arr[i]=la.layer;
					//if(la.layer==Layer.LAYER_ENDPAPER) hasEp=true;
				}
			}
			//hasEndpaperTray=hasEp;
			so.data['tech_tray']=arr;
			so.flush();
		}

		public function getLayerInTray(tray:int):int{
			if(tray==-1) return 0;
			return tarys.getItemAt(tray)['layer'];
		}

		public function getCurrentTray(layer:int):int{
			var tray:int=curLayerTrayMap[layer.toString()];
			if(tray==-1 || tarys.getItemAt(tray)['layer']!=layer){
				//finde first
				tray=ArrayUtil.searchItemIdx('layer',layer,tarys.source);
				curLayerTrayMap[layer.toString()]=tray;
			}
			return tray;
		}

		public function getNextTray(layer:int):int{
			var tray:int=curLayerTrayMap[layer.toString()];
			if(tray==-1){
				//finde first
				tray=ArrayUtil.searchItemIdx('layer',layer,tarys.source);
				curLayerTrayMap[layer.toString()]=tray;
				return tray;
			}
			var i:int;
			var idx:int=tray+1;
			var arr:Array=tarys.source;
			if(!arr) return -1;
			for(i=0;i<arr.length;i++){
				//finde next
				if(idx>=arr.length) idx=0;
				if(arr[idx]['layer']==layer){
					curLayerTrayMap[layer.toString()]=idx;
					return idx;
				}
				idx++;
			}
			curLayerTrayMap[layer.toString()]=-1;
			return -1;
		}
		
		public function getLayerName(layer:int):String{
			var result:String='id: '+layer.toString();
			if(!layers) return result;
			var fv:FieldValue= (ArrayUtil.searchItem('value',layer,layers) as FieldValue);
			if(!fv) return result;
			return fv.label;
		}
		
	}
}