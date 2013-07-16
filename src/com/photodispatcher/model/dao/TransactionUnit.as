package com.photodispatcher.model.dao{
	public class TransactionUnit{
		public static const TYPE_READ:int=0;
		public static const TYPE_WRITE:int=1;

		public var type:int;
		public var dao:BaseDAO;
		public var sequence:Array;
		
		public function TransactionUnit(dao:BaseDAO, sequence:Array, type:int=TYPE_WRITE){
			this.dao=dao;
			this.sequence=sequence;
			this.type=type;
		}
	}
}