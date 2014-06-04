package com.photodispatcher.service.barcode{
	import flash.net.SharedObject;

	[Bindable]
	public class ComInfo{
		public static const COM_TYPE_NONE:int=0;
		public static const COM_TYPE_BARREADER:int=1;
		public static const COM_TYPE_VALVE:int=2;
		public static const COM_TYPE_CONTROLLER:int=3;
		public static const COM_TYPE_CAPTIONS:Array=['Отключен','Сканер ШК','Клапан','Контроллер']; 
		
		public static const COM_NUMS:Array=['1','2','3','4','5','6','7','8','9']; 
		public static const COM_BAUDS:Array=['2400','4800','7200','9600','14400','19200','38400','57600','115200','128000']; 
		public static const COM_DATABITS:Array=['8','7','6','5','4']; 
		public static const COM_STOPBITS:Array=['1','2']; 
		public static const COM_PARITYS:Array=['none','even','odd']; 
		public static const COM_SUFFIX:Array=[13,10,3]; 
		
		public static const KEY_TYPE:String='comm_type';
		public static const KEY_COM:String='comm_num';
		public static const KEY_PORT:String='net_port';
		public static const KEY_BAUD:String='comm_baud';
		public static const KEY_DATABITS:String='comm_databits';
		public static const KEY_STOPBITS:String='comm_stopbits';
		public static const KEY_PARITY:String='comm_parity';
		public static const KEY_SUFFIX:String='comm_suffix';
		public static const KEY_DOUBLE_SCAN_GAP:String='comm_dblscangap';
		
		public var type:int=COM_TYPE_NONE;

		private var _num:String;
		public function get num():String{
			return _num;
		}
		public function set num(value:String):void{
			_num = value;
			label='COM'+_num;
		}

		public var label:String='COM?';
		public var baud:String=COM_BAUDS[0];
		public var databits:String=COM_DATABITS[0];
		public var stopbits:String=COM_STOPBITS[0];
		public var parity:String=COM_PARITYS[0];
		public var suffix:int=10; //LF default
		public var proxy:Socket2Com;
		public var doubleScanGap:int=ComReader.DOUBLE_SCAN_GAP;

		public static function save(arr:Array):void{
			var so:SharedObject=SharedObject.getLocal('comm_ports','/');
			var coms:Array=[];
			var comport:ComInfo;
			if (arr){
				for each(comport in arr){
					if(comport.type!=COM_TYPE_NONE && comport.num){
						coms.push(comport.toRaw());
					}
				}
			}
			so.data['comm_ports']=coms;
			so.flush();
		}

		public static function load():Array{
			var so:SharedObject=SharedObject.getLocal('comm_ports','/');
			var coms:Array=[];
			var arr:Array;
			var o:Object;
			var comport:ComInfo;
			if(so.data['comm_ports'] && so.data['comm_ports'] is Array){
				arr=so.data['comm_ports'];
				for each (o in arr){
					comport= new ComInfo;
					comport.fromRaw(o);
					if(comport.type!=COM_TYPE_NONE && comport.num){
						coms.push(comport);
					}
				}
			}
			return coms;
		}
		
		
		public function getCoonfig():String{
			var result:String='\n';
			/*
			comm_baud3=9600
			comm_databits3=7
			comm_stopbits3=2
			comm_parity3=odd
			*/
			if(type!=COM_TYPE_NONE && num){
				result+=(KEY_PORT+num+'='+(SerialProxy.PROXY_PORT_BASE+int(num)).toString()+'\n');
				if(baud) result+=(KEY_BAUD+num+'='+baud+'\n');
				if(databits) result+=(KEY_DATABITS+num+'='+databits+'\n');
				if(stopbits) result+=(KEY_STOPBITS+num+'='+stopbits+'\n');
				if(parity) result+=(KEY_PARITY+num+'='+parity+'\n');
			}			
			return result;
		}
		
		public function toRaw():Object{
			var result:Object= new Object;
			if(type!=COM_TYPE_NONE && num){
				result[KEY_TYPE]=type;
				result[KEY_COM]=num;
				if(baud) result[KEY_BAUD]=baud;
				if(databits) result[KEY_DATABITS]=databits;
				if(stopbits) result[KEY_STOPBITS]=stopbits;
				if(parity) result[KEY_PARITY]=parity;
				if(suffix) result[KEY_SUFFIX]=suffix;
				if(doubleScanGap) result[KEY_DOUBLE_SCAN_GAP]=doubleScanGap;
			}
			return result;
		}
		
		public function fromRaw(value:Object):void{
			if(value.hasOwnProperty(KEY_TYPE)) type=value[KEY_TYPE];
			if(value.hasOwnProperty(KEY_COM)) num=value[KEY_COM];
			if(value.hasOwnProperty(KEY_BAUD)) baud=value[KEY_BAUD];
			if(value.hasOwnProperty(KEY_DATABITS)) databits=value[KEY_DATABITS];
			if(value.hasOwnProperty(KEY_STOPBITS)) stopbits=value[KEY_STOPBITS];
			if(value.hasOwnProperty(KEY_PARITY)) parity=value[KEY_PARITY];
			if(value.hasOwnProperty(KEY_SUFFIX)) suffix=value[KEY_SUFFIX];
			if(value.hasOwnProperty(KEY_DOUBLE_SCAN_GAP)) doubleScanGap=value[KEY_DOUBLE_SCAN_GAP];
		}

	}
}