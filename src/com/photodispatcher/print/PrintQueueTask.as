package com.photodispatcher.print
{	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	
	[Event(name="complete", type="flash.events.Event")]
	public class PrintQueueTask extends EventDispatcher
	{
		
		protected var items:Array;
		protected var itemsReady:Array;
		protected var queue:Array;
		
		public function getItemsReady():Array {
			
			return itemsReady;
			
		}
		
		public function PrintQueueTask(items:Array)
		{
			super();
			
			if(items == null || items.length == 0){
				throw new Error("printGroups == null || printGroups.length == 0");
			}
			
			this.items = items.concat();
			this.itemsReady = [];
		}
		
		protected function prepareQueueItems():void {
			
			throw new Error('Override');
			
		}
		
		public function execute():void {
			
			prepareQueueItems();
			startNext();
			
		}
		
		protected var currentItem:*;
		
		protected function startNext():void
		{
			
			if(queue.length > 0){
				
				currentItem = queue.shift();
				startCurrent();
				
			} else {
				
				dispatchEvent(new Event(Event.COMPLETE));
				
			}
			
		}
		
		protected function startCurrent():void {
			
			
			
		}
		
		protected function finishCurrent():void {
			
			itemsReady.push(currentItem);
			currentItem = null;
			startNext();
			
		}
		
	}
}