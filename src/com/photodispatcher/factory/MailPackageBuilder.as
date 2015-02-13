package com.photodispatcher.factory{
	import com.photodispatcher.model.mysql.entities.AttrJsonMap;
	import com.photodispatcher.model.mysql.entities.MailPackage;
	import com.photodispatcher.model.mysql.entities.MailPackageBarcode;
	import com.photodispatcher.model.mysql.entities.MailPackageProperty;
	import com.photodispatcher.util.JsonUtil;
	
	import mx.collections.ArrayCollection;

	public class MailPackageBuilder{

		public static function build(source:int, raw:Object):MailPackage{
			if(!source || !raw ) return null;
			
			var result:MailPackage= new MailPackage();
			result.source=source;
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
								result[ajm.field]=val;
							}
						}
					}
				}
			}
			if(raw.hasOwnProperty('orders') && raw.orders is Array){
				result.orders_num= (raw.orders as Array).length;
			}
			
			//build prorerties
			var props:Array=[];
			var prop:MailPackageProperty;
			var barcodes:Array=[];
			for each(ajm in mpMap){
				val=JsonUtil.getRawVal(ajm.json_key, raw);
				if(val){
					prop= new MailPackageProperty();
					prop.source=source;
					prop.id=result.id;
					prop.property=ajm.field;
					prop.property_name=ajm.field_name;
					prop.value=val.toString();
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