package com.photodispatcher.print
{
	import com.photodispatcher.factory.LabBuilder;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.Lab;
	import com.photodispatcher.model.mysql.entities.LabDevice;
	import com.photodispatcher.model.mysql.services.LabService;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	import mx.collections.ArrayCollection;
	
	import org.granite.tide.Tide;
	
	public class LabConfigManager extends EventDispatcher
	{
		
		private var labNamesMap:Object;
		private var _labs:ArrayCollection = new ArrayCollection();
		
		[Bindable(event="labsChange")]
		public function get labs():ArrayCollection {
			return _labs;
		}
		
		public function LabConfigManager(target:IEventDispatcher=null)
		{
			super(target);
		}
		
		public function init():void{
			
			loadConfig();
			
		}
		
		protected function loadConfig():void
		{
			
			var svc:LabService = Tide.getInstance().getContext().byType(LabService,true) as LabService;
			var latch:DbLatch= new DbLatch();
			latch.addEventListener(Event.COMPLETE,onConfigLoad);
			latch.addLatch(svc.loadAll(false));
			latch.start();
			
		}
		
		protected function onConfigLoad(event:Event):void
		{
			
			var latch:DbLatch= event.target as DbLatch;
			if(!latch) return;
			latch.removeEventListener(Event.COMPLETE,onConfigLoad);
			if(!latch.complite) return;
			var rawLabs:Array=latch.lastDataArr;
			if(!rawLabs) return;
			fillLabs(rawLabs);
			
		}
		
		private function fillLabs(rawLabs:Array):void{
			//fill labs 
			var lab:Lab;
			var dev:LabDevice;
			var result:Array=[];
			
			labNamesMap= new Object();
			
			for each(lab in rawLabs){
				labNamesMap[lab.id.toString()]=lab.name;
				var lb:LabGeneric=LabBuilder.build(lab);
				lb.refresh();
				result.push(lb);
			}
			
			_labs.source=result;
			
			dispatchEvent(new Event("labsChange"));
		}
		
	}
}