package com.photodispatcher.factory{
	import com.photodispatcher.model.mysql.entities.AttrJsonMap;
	import com.photodispatcher.model.mysql.entities.OrderFile;
	import com.photodispatcher.model.mysql.entities.OrderLoad;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.util.JsonUtil;

	public class OrderLoadBuilder{

		public static function buildBatch(source:Source, raw:Array):Array{
			if(!source || !raw || raw.length==0) return [];
			
			var result:Array=[];
			var order:OrderLoad;// :Order;
			for each (var jo:Object in raw){
				order=build(source,jo);
				if(order) result.push(order);
			}
			return result;
		}

		public static function build(source:Source, raw:Object):OrderLoad{
			if(!source || !raw) return null;
			var oMap:Array= AttrJsonMap.getOrderLoadJson();
			var ofMap:Array=AttrJsonMap.getOrderLoadFilesJson();
			if(!oMap || !ofMap) return null;

			var order:OrderLoad=new OrderLoad();
			var src_id:int=0;
			var o:Object;
			var ajm:AttrJsonMap;
			var val:Object;
			var d:Date;
			
			//order
			for each(o in oMap){
				ajm=o as AttrJsonMap;
				if(ajm){
					if(order.hasOwnProperty(ajm.field)){
						//params array
						val=JsonUtil.getRawVal(ajm.json_key, raw);
						if(val!=null){
							if(ajm.field.indexOf('date')!=-1){
								//convert date
								d=JsonUtil.parseDate(val.toString());
								order[ajm.field]=d;
							}else{
								order[ajm.field]=val;
							}
							if(ajm.field=='src_id'){
								//create id
								src_id=int(val);
								if(src_id) order.id=source.id.toString()+'_'+src_id.toString();
							}
							
						}
					}
				}
			}
			if(!order.id) return null;  //id empty
			
			//files
			//parse files
			var file:OrderFile;
			if (raw.hasOwnProperty('files') && raw.files is Array){
				var subRaw:Array= raw.files as Array;
				if(subRaw && subRaw.length>0){
					for each(var so:Object in subRaw){
						file = new OrderFile();
						for each(ajm in ofMap){
							if(file.hasOwnProperty(ajm.field)){
								//params array
								val=JsonUtil.getRawVal(ajm.json_key, so);
								if(val!=null){
									if(ajm.field.indexOf('date')!=-1){
										//convert date
										d=JsonUtil.parseDate(val.toString());
										file[ajm.field]=d;
									}else{
										file[ajm.field]=val;
									}
								}
							}
						}
						if(file.file_name){ //skip if file name is empty
							file.order_id=order.id;
							order.addFile(file);
						}
					}
				}
			}
			return order;
		}
		
	}
}