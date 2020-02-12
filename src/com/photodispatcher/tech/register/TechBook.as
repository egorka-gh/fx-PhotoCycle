package com.photodispatcher.tech.register{
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	
	[Bindable]
	public class TechBook{
		
		public function TechBook(book:int, printGroupId:String=''){
			this.book=book;
			this.printGroupId=printGroupId;
			checkState= PrintGroup.CHECK_STATUS_NONE;
		}

		public var barcode:String;
		
		public var order:Order;
		public var orderId:String;
		public var subId:String;
		public var printGroupId:String;
		public var book:int;
		public var checkState:int;
		public var isRejected:Boolean;
		
		public var sheetsTotal:int;
		public var sheetsFeeded:int;
		public var sheetsDone:int;
		public var sheetsPushed:int;
		
		public var thickness:Number;

		public function get skipGlue():Boolean{
			return sheetsTotal == 1;
		}

	}
	
}