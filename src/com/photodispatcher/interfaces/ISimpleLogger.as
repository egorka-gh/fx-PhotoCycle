package com.photodispatcher.interfaces{
	
	public interface ISimpleLogger{
		function log(mesage:String, level:int=0):void;
		function clear():void;
	}
}