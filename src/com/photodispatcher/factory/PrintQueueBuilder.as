package com.photodispatcher.factory{
	import com.photodispatcher.model.mysql.entities.PrnQueue;
	import com.photodispatcher.model.mysql.entities.PrnStrategy;
	import com.photodispatcher.print.PrintQueueGeneric;
	import com.photodispatcher.print.PrintQueueManager;
	import com.photodispatcher.print.PrintQueuePartPDF;
	
	public class PrintQueueBuilder{
		
		public static function build(printManager:PrintQueueManager, prnQueue:PrnQueue):PrintQueueGeneric{
		
			if (!printManager || !prnQueue) return null;
			// if(!prnQueue)
			switch(prnQueue.strategy_type){
				case PrnStrategy.STRATEGY_BYPARTPDF:
				case PrnStrategy.STRATEGY_BYPART:
				case PrnStrategy.STRATEGY_BYROLL:
					return new PrintQueuePartPDF(printManager,prnQueue);
					break;
				default:
					return null;
					break;
			}

		}
		
	}
}