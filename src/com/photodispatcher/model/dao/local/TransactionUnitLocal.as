package com.photodispatcher.model.dao.local{

	public class TransactionUnitLocal{
		public static const TYPE_READ:int=0;
		public static const TYPE_WRITE:int=1;

		public var type:int;
		public var dao:LocalDAO;
		public var sequence:Array;
		
		public function TransactionUnitLocal(dao:LocalDAO, sequence:Array, type:int=TYPE_WRITE){
			this.dao=dao;
			this.sequence=sequence;
			this.type=type;
		}
	}
}