package com.photodispatcher.tech{
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	
	[Bindable]
	public class TechBook{
		
		public function TechBook(book:int){
			this.book=book;
			checkState= PrintGroup.CHECK_STATUS_NONE;
		}
		
		public var book:int;
		public var checkState:int;
		
	}
}