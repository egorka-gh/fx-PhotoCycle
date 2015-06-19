package com.photodispatcher.util{
	import flash.net.InterfaceAddress;
	import flash.net.NetworkInfo;
	import flash.net.NetworkInterface;
	
	public class NetUtil{
		public static function getIP():String{
			var netInterfaces:Vector.<NetworkInterface>=NetworkInfo.networkInfo.findInterfaces();
			if(!netInterfaces || netInterfaces.length==0) return null;
			var addresses:Vector.<InterfaceAddress>=netInterfaces[0].addresses;
			if(!addresses || addresses.length==0) return null;
			return addresses[0].address;
		}
		
		/*
		public static function getClientIPAddress (version:String):String {
			var ni:NetworkInfo = NetworkInfo.networkInfo;
			var interfaceVector:Vector.<NetworkInterface> = ni.findInterfaces();
			var currentNetwork:NetworkInterface;
			
			for each (var networkInt:NetworkInterface in interfaceVector) {
				if (networkInt.active) {
					for each (var address:InterfaceAddress in networkInt.addresses) {
						if (address.ipVersion == version) {
							return address.address;
						}
					}
				}
			}
			return "";
		}
		*/
	}
}