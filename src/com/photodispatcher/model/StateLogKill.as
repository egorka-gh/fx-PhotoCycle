package com.photodispatcher.model{
	public class StateLogKill extends DBRecord{
		//database props
		[Bindable]
		public var id:int;
		[Bindable]
		public var order_id:String;
		[Bindable]
		public var pg_id:String;
		[Bindable]
		public var state:int;
		[Bindable]
		public var state_date:Date;
		[Bindable]
		public var comment:String
		
		//ref
		[Bindable]
		public var state_name:String;

	}
}