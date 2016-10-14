package com.photodispatcher.tech{
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	
	[Bindable]
	public class TechBook{
		
		public function TechBook(book:int, printGroupId:String=''){
			this.book=book;
			this.printGroupId=printGroupId;
			checkState= PrintGroup.CHECK_STATUS_NONE;
		}
		
		public var printGroupId:String;
		public var book:int;
		public var checkState:int;
		public var isRejected:Boolean;
		
	}
}