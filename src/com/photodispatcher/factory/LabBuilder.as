package com.photodispatcher.factory{
	import com.photodispatcher.model.Source;
	import com.photodispatcher.model.SourceType;
	import com.photodispatcher.print.LabBase;
	import com.photodispatcher.print.LabFuji;
	import com.photodispatcher.print.LabNoritsu;
	import com.photodispatcher.print.LabNoritsuNHF;
	import com.photodispatcher.print.LabPlotter;
	import com.photodispatcher.print.LabVirtual;
	import com.photodispatcher.print.LabXerox;
	
	import mx.collections.ArrayCollection;

	public class LabBuilder	{

		public static function build(source:Source):LabBase{
			if (!source) return null;
			switch(source.type_id){
				case SourceType.LAB_NORITSU:
					return new LabNoritsu(source);
					break;
				case SourceType.LAB_FUJI:
					return new LabFuji(source);
					break;
				case SourceType.LAB_XEROX:
					return new LabXerox(source);
					break;
				case SourceType.LAB_PLOTTER:
					return new LabPlotter(source);
					break;
				case SourceType.LAB_NORITSU_NHF:
					return new LabNoritsuNHF(source);
					break;
				case SourceType.LAB_VIRTUAL:
					return new LabVirtual(source);
					break;
				default:
					return null;
					break;
			}
		}

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

	}
}