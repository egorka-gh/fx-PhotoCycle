package com.photodispatcher.factory{
	import com.photodispatcher.model.mysql.entities.Lab;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.print.LabFuji;
	import com.photodispatcher.print.LabGeneric;
	import com.photodispatcher.print.LabNoritsu;
	import com.photodispatcher.print.LabNoritsuNHF;
	import com.photodispatcher.print.LabPlotter;
	import com.photodispatcher.print.LabVirtual;
	import com.photodispatcher.print.LabXerox;
	
	import mx.collections.ArrayCollection;

	public class LabBuilder	{

		public static function build(lab:Lab):LabGeneric{
			if (!lab) return null;
			switch(lab.src_type){
				case SourceType.LAB_NORITSU:
					return new LabNoritsu(lab);
					break;
				case SourceType.LAB_FUJI:
					return new LabFuji(lab);
					break;
				case SourceType.LAB_XEROX:
					return new LabXerox(lab);
					break;
				case SourceType.LAB_PLOTTER:
					return new LabPlotter(lab);
					break;
				case SourceType.LAB_NORITSU_NHF:
					return new LabNoritsuNHF(lab);
					break;
				case SourceType.LAB_VIRTUAL:
					return new LabVirtual(lab);
					break;
				default:
					return null;
					break;
			}
		}

		/*
		public static function buildList(sources:Array):ArrayCollection{
			var arr:Array=[];
			if(sources){
				for each(var o:Object in sources){
					var l:LabBase=build(o as Source);
					if(l) arr.push(l);
				}
			}
			return new ArrayCollection(arr);
		}
		*/

	}
}