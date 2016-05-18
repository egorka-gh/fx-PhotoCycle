package com.photodispatcher.interfaces{
	import com.photodispatcher.model.mysql.entities.messenger.CycleMessage;

	public interface IMessageRecipient{
		
		function getMessage(message:CycleMessage):void;
	}
}