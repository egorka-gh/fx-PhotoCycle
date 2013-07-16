package com.photodispatcher.factory{
	import com.photodispatcher.model.AttrJsonMap;
	import com.photodispatcher.model.Order;
	import com.photodispatcher.model.Source;
	import com.photodispatcher.model.dao.AttrJsonMapDAO;
	
	public class OrderBuilder{
		
		public function build(source:Source, raw:Array):Array{
			if(!source || !raw || raw.length==0) return [];
			
			var result:Array=[];
			var order:Order;
			//var attDao:AttrJsonMapDAO= new AttrJsonMapDAO();
			//var jMap:Array=attDao.getOrderMapBySourceType(source.type_id);
			var jMap:Array=AttrJsonMapDAO.getOrderJson(source.type_id);
			if(!jMap) return null;
			for each (var jo:Object in raw){
				if(jo){
					order=new Order();
					var src_id:int;
					for each(var o:Object in jMap){
						var ajm:AttrJsonMap=o as AttrJsonMap;
						if(ajm){
							if(order.hasOwnProperty(ajm.field)){
								//params array
								var val:Object=getRawVal(ajm.json_key, jo);
								if(ajm.field.indexOf('date')!=-1){
									//convert date
									var d:Date=parseDate(val.toString());
									order[ajm.field]=d;
								}else{
									order[ajm.field]=val;
								}
							}
						}
					}
					result.push(order);
				}
			}
			return result;
		}
		
		private function getRawVal(key:String, jo:Object):Object{
			if(!key) return null; 
			var path:Array=key.split('.');
			var value:Object=jo;
			for each(var subkey:String in path){
				if (value.hasOwnProperty(subkey)){
					value=value[subkey];
				}else{
					return null;
				}
			}
			if (value!=jo){
				return value;
			}else{
				return null;
			}
		}
		
		private function parseDate(s:String):Date{
			//json date, parsed as "2012-05-17 15:52:08"
			var d:Date=new Date();
			if(!s) return d;
			var a1:Array=s.split(' ');
			if(!a1 || a1.length!=2) return d;
			var a2:Array=(a1[0] as String).split('-');
			if(!a2 || a2.length!=3) return d;
			var a3:Array=(a1[1] as String).split(':');
			if(!a3 || a3.length<3) return d;
			return new Date(a2[0],a2[1]-1,a2[2],a3[0],a3[1],a3[2]);
		}
	}		
}