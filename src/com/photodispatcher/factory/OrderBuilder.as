package com.photodispatcher.factory{
	import com.photodispatcher.model.AttrJsonMap;
	import com.photodispatcher.model.Order;
	import com.photodispatcher.model.dao.AttrJsonMapDAO;
	import com.photodispatcher.model.mysql.entities.Source;
	
	public class OrderBuilder{
		
		public function build(source:Source, raw:Array):Array{
			if(!source || !raw || raw.length==0) return [];
			
			var result:Array=[];
			var order:Order;
			//var attDao:AttrJsonMapDAO= new AttrJsonMapDAO();
			//var jMap:Array=attDao.getOrderMapBySourceType(source.type_id);
			var jMap:Array=AttrJsonMapDAO.getOrderJson(source.type);
			var ejMap:Array=AttrJsonMapDAO.getOrderExtraJson(source.type);
			if(!jMap) return null;
			for each (var jo:Object in raw){
				if(jo){
					order=new Order();
					//var src_id:int;
					var o:Object;
					var ajm:AttrJsonMap;
					var val:Object;
					var d:Date;
					
					//regular data
					for each(o in jMap){
						ajm=o as AttrJsonMap;
						if(ajm){
							if(order.hasOwnProperty(ajm.field)){
								//params array
								val=getRawVal(ajm.json_key, jo);
								if(val){
									if(ajm.field.indexOf('date')!=-1){
										//convert date
										d=parseDate(val.toString());
										order[ajm.field]=d;
									}else{
										order[ajm.field]=val;
									}
								}
							}
						}
					}
					
					//extra info
					if(ejMap && ejMap.length>0){
						for each(o in ejMap){
							ajm=o as AttrJsonMap;
							if(ajm){
								if(order.hasOwnProperty(ajm.field)){
									//params array
									val=getRawVal(ajm.json_key, jo);
									if(val){
										if(ajm.field.indexOf('date')!=-1){
											//convert date
											d=parseDate(val.toString());
											order[ajm.field]=d;
										}else{
											order[ajm.field]=val;
										}
									}
								}
							}
						}
					}

					result.push(order);
				}
			}
			return result;
		}
		
		//calc_data.=>type:cover.value
		//calc_data indexed array
		//=>type:cover - search in array object vs proverty type==cover
		//.value - gets from founded object property value
		private function getRawVal(key:String, jo:Object):Object{
			if(!key) return null; 
			var path:Array=key.split('.');
			var value:Object=jo;
			var obj:Object;
			
			for each(var subkey:String in path){
				obj=searchRawValInArray(subkey,value);
				if(obj){
					value=obj;
				}else{
					if (value.hasOwnProperty(subkey)){
						value=value[subkey];
					}else{
						return null;
					}
				}
			}
			if (value!=jo){
				return value;
			}else{
				return null;
			}
		}
		
		private function searchRawValInArray(searchKey:String, array:Object):Object{
			if(!searchKey || searchKey.substr(0,2)!='=>') return null;
			searchKey=searchKey.substr(2);
			if(!searchKey) return null;
			var arr:Array= (array as Array);
			if(!arr || arr.length==0) return null;
			var pArr:Array=searchKey.split(':');
			if (pArr.length!=2) return null;
			var key:String=pArr[0];
			var val:String=pArr[1];
			var o:Object;
			for each(o in arr){
				if(o.hasOwnProperty(key) && o[key]==val){
					return o;
				}
			}
			return null;
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