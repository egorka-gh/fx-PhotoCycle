package com.photodispatcher.model.mysql.entities{
	import mx.collections.IList;
	
	import org.granite.reflect.Field;
	import org.granite.reflect.Type;
	
	[Bindable]
	public class BookKit extends OrderBook{
		
		/*
		public var orderId:String;
		public var subId:String='';
		public var book:int;
		public var state:int;
		public var state_date:Date;
		*/

		public var disabled:Boolean;
		
		public function BookKit(){
			sub_id='';
		}

		override public function get state():int{
			return 	super.state;
		}

		public override function set state(value:int):void{
			super.state = value;
			if(coverBook) coverBook.state=value;
			if(blockBook) blockBook.state=value;
		}

		
		private var _coverBook:OrderBook;
		public function get coverBook():OrderBook{
			return _coverBook;
		}
		public function set coverBook(value:OrderBook):void{
			if(value && blockBook && (value.order_id!=blockBook.order_id || value.sub_id!=blockBook.sub_id || value.book!=blockBook.book)){
				_coverBook=null;
			}else{
				_coverBook = value;
			}
			if(_coverBook){
				order_id=_coverBook.order_id;
				sub_id=_coverBook.sub_id;
				book=_coverBook.book;
				if(blockBook){
					state=Math.min(blockBook.state,_coverBook.state);
					if(!blockBook.state_date || blockBook.state_date.time>_coverBook.state_date.time){
						state_date=_coverBook.state_date;
					}
				}else{
					state=_coverBook.state;
					state_date=_coverBook.state_date;
				}
			}
			if(!sub_id) sub_id='';
		}

		private var _blockBook:OrderBook;
		public function get blockBook():OrderBook{
			return _blockBook;
		}
		public function set blockBook(value:OrderBook):void{
			if(value && coverBook && (value.order_id!=coverBook.order_id || value.sub_id!=coverBook.sub_id || value.book!=coverBook.book)){
				_blockBook=null;
			}else{
				_blockBook = value;
			}
			if(_blockBook){
				order_id=_blockBook.order_id;
				sub_id=_blockBook.sub_id;
				book=_blockBook.book;
				if(coverBook){
					state=Math.min(blockBook.state,_coverBook.state);
					if(!coverBook.state_date || coverBook.state_date.time>_blockBook.state_date.time){
						state_date=_blockBook.state_date;
					}
				}else{
					state=_blockBook.state;
					state_date=_blockBook.state_date;
				}
			}
			if(!sub_id) sub_id='';
		}
		
		public function toOrderBook():OrderBook{
			var result:OrderBook= new OrderBook();
			
			var type:Type= Type.forClass(OrderBook);
			var props:Array=type.properties;
			if(!props || props.length==0) return result;
			var prop:Field;
			for each(prop in props){
				//exclude childs
				if(this[prop.name] && !(this[prop.name] is IList)) result[prop.name]=this[prop.name];
			}

			return result;
		}
		
	}
}