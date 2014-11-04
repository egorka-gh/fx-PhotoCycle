package com.photodispatcher.factory{
	import com.photodispatcher.model.mysql.entities.AttrJsonMap;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderExtraInfo;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.OrderTemp;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.SubOrder;
	
	public class OrderBuilder{

		public static function build(source:Source, raw:Array, forSync:Boolean=false):Array{
			if(!source || !raw || raw.length==0) return [];
			
			var result:Array=[];
			var order:Object;// :Order;
			var einfo:OrderExtraInfo;
			var src_id:int;
			var syncDate:Date= new Date();
			//var jMap:Array=AttrJsonMapDAO.getOrderJson(source.type);
			//var ejMap:Array=AttrJsonMapDAO.getOrderExtraJson(source.type);
			var jMap:Array= AttrJsonMap.getOrderJson(source.type);
			var ejMap:Array=AttrJsonMap.getOrderExtraJson(source.type);
			if(!jMap) return null;
			for each (var jo:Object in raw){
				if(jo){
					src_id=0;
					if(forSync){
						order=new OrderTemp();
						order.source=source.id;
						order.state=OrderState.WAITE_FTP;
						order.state_date=syncDate;
					}else{
						order=new Order();
					}
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
									if(forSync && ajm.field=='src_id'){
										//create id
										//removes subNumber (-#) for fotokniga
										if (val is String){
											src_id=cleanId(val as String);
										}else{
											src_id=int(val);
										}
										if(src_id) order.id=source.id.toString()+'_'+src_id.toString();
									}

								}
							}
						}
					}
					
					if(!forSync){
						einfo=new OrderExtraInfo();
						//extra info
						if(ejMap && ejMap.length>0){
							for each(o in ejMap){
								ajm=o as AttrJsonMap;
								if(ajm){
									if(einfo.hasOwnProperty(ajm.field)){
										//params array
										val=getRawVal(ajm.json_key, jo);
										if(val){
											if(ajm.field.indexOf('date')!=-1){
												//convert date
												d=parseDate(val.toString());
												einfo[ajm.field]=d;
											}else{
												einfo[ajm.field]=val;
											}
										}
									}
								}
							}
						}
						if(!einfo.isEmpty) order.extraInfo=einfo;
						//parse suborders
						if (source.type==SourceType.SRC_FBOOK && jo.hasOwnProperty('items') && jo.items is Array){
							var subMap:Array=AttrJsonMap.getSubOrderJson(source.type);
							var subRaw:Array= jo.items as Array;
							var subOrder:SubOrder;
							if(subRaw && subRaw.length>0 && subMap && subMap.length>0){
								for each(var so:Object in subRaw){
									subOrder = new SubOrder();
									for each(ajm in subMap){
										if(subOrder.hasOwnProperty(ajm.field)){
											//params array
											val=getRawVal(ajm.json_key, so);
											if(val!=null){
												if(ajm.field.indexOf('date')!=-1){
													//convert date
													d=parseDate(val.toString());
													subOrder[ajm.field]=d;
												}else{
													subOrder[ajm.field]=val;
												}
											}
										}
									}
									if(subOrder.native_type==1){
										//foto print, reset root ftp folder
										order.ftp_folder=subOrder.ftp_folder;
									}else{
										order.addSuborder(subOrder);
									}
								}
							}
							if(!order.ftp_folder) order.ftp_folder=order.id;
						}

					}
					if(!forSync || order.id) result.push(order); //skip if id empty
				}
			}
			return result;
		}
		
		//calc_data.=>type:cover.value
		//calc_data indexed array
		//=>type:cover - search in array object vs proverty type==cover
		//.value - gets from founded object property value
		private static function getRawVal(key:String, jo:Object):Object{
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
		
		private static function searchRawValInArray(searchKey:String, array:Object):Object{
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
		
		
		private static function parseDate(s:String):Date{
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
		
		private static function cleanId(src_id:String):int{
			//removes subNumber (-#) for fotokniga
			var a:Array=src_id.split('-');
			var sId:String;
			if(!a || a.length==0){
				sId=src_id;
			}else{
				sId=a[0];
			}
			return int(sId);
		}

	}		
}