package com.photodispatcher.factory{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.mysql.entities.AttrJsonMap;
	import com.photodispatcher.model.mysql.entities.MailPackage;
	import com.photodispatcher.model.mysql.entities.MailPackageBarcode;
	import com.photodispatcher.model.mysql.entities.MailPackageProperty;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.util.JsonUtil;
	import com.photodispatcher.util.StrUtil;
	
	import mx.collections.ArrayCollection;

	public class MailPackageBuilder{

		public static function build(source:int, raw:Object):MailPackage{
			if(!source || !raw ) return null;
			
			var result:MailPackage= new MailPackage();
			result.source=source;
			var src:Source= Context.getSource(source);
			if(src) result.source_name=src.name;
			var mpMap:Array= AttrJsonMap.getMailPackageJson();
			var mppMap:Array= AttrJsonMap.getMailPackagePropJson();
			
			//parce package
			var o:Object;
			var ajm:AttrJsonMap;
			var val:Object;
			var d:Date;
			for each(o in mpMap){
				ajm=o as AttrJsonMap;
				if(ajm){
					if(result.hasOwnProperty(ajm.field)){
						//params array
						val=JsonUtil.getRawVal(ajm.json_key, raw);
						if(val){
							if(ajm.field.indexOf('date')!=-1){
								//convert date
								d=JsonUtil.parseDate(val.toString());
								result[ajm.field]=d;
							}else{
								if(val is String){
									result[ajm.field]=StrUtil.siteCode2Char(val.toString());
								}else{
									result[ajm.field]=val;
								}
							}
						}
					}
				}
			}
			if(raw.hasOwnProperty('orders')){
				var orders_num:int=0;
				for(var s:String in raw.orders) orders_num++;
				result.orders_num= orders_num;
			}
			
			//build prorerties
			var props:Array=[];
			var prop:MailPackageProperty;
			var barcodes:Array=[];
			for each(ajm in mppMap){
				val=JsonUtil.getRawVal(ajm.json_key, raw);
				if(val){
					prop= new MailPackageProperty();
					prop.source=source;
					prop.id=result.id;
					prop.property=ajm.field;
					prop.property_name=ajm.field_name;
					if(val is String){
						prop.value=StrUtil.siteCode2Char(val.toString());
					}else{
						prop.value=val.toString();
					}
					props.push(prop);
					//barcode?
					if(prop.property=='sl_delivery_code'){
						var bar:MailPackageBarcode= new MailPackageBarcode();
						bar.source=source;
						bar.id=result.id;
						bar.barcode=prop.value;
						bar.bar_type=MailPackageBarcode.TYPE_SITE;
						barcodes.push(bar);
					}
				}
			}
			
			result.properties= new ArrayCollection(props);
			result.barcodes= new ArrayCollection(barcodes);
			return result;
		}
		

	}
}