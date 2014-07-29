package com.photodispatcher.factory{
	import com.photodispatcher.model.Order;
	import com.photodispatcher.model.OrderState;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.SourceType;
	import com.photodispatcher.model.Suborder;
	import com.photodispatcher.model.SubordersTemplate;
	
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.Dictionary;

	public class SuborderBuilder{
		
		/**
		 * parse Suborders from file structure
		 * removes folder from file structure if processed
		 * creates Suborder as template (actual Suborders populated from relations.txt, after download)
		 * 
		 * @param source
		 * @param map
		 * @param orderId
		 * 
 		 * @return array of Suborder
		 * 
	  	 * trows ERR_READ_LOCK
		 */
		public static function build(source:Source, map:Dictionary, order:Order):Array{
			if(!source || !map || !order) return [];
			var path:String;
			var t:SubordersTemplate;
			var o:Suborder;
			var result:Array;

			//for profoto type
			if(source.type==SourceType.SRC_PROFOTO){
				for (path in map){
					if(path){
						t=SubordersTemplate.translatePath(path,source.type);
						if(t){
							o= new Suborder();
							o.order_id=order.id;
							o.src_type=t.sub_src_type;
							o.ftp_folder=path;
							if(!result) result=[];
							result.push(o);
							delete map[path];
						}
					}
				}
			}
			//for fotokniga type
			if(source.type==SourceType.SRC_FOTOKNIGA && order.src_id){
				//get subOrder id (-#)
				var subId:int;
				var a:Array=order.src_id.split('-');
				if(a && a.length>=2){
					subId=int(a[1]);
					o= new Suborder();
					o.order_id=order.id;
					o.sub_id=subId;
					o.src_type=SourceType.SRC_FBOOK;
					//o.ftp_folder=order.ftp_folder;
					//o.ftp_folder='';
					if(!result) result=[];
					result.push(o);
				}
			}
			return result;
		}

		public static function buildFromFileSystem(source:Source, order:Order):String{
			if (!source || !order || !order.hasSuborders) return '';
			//parse profoto only 
			if(source.type!=SourceType.SRC_PROFOTO) return '';
			var rootFolder:File=new File(source.getWrkFolder());
			rootFolder=rootFolder.resolvePath(order.ftp_folder);
			if(!rootFolder.exists || !rootFolder.isDirectory) return 'Папка заказа не найдена: '+rootFolder.nativePath;

			var so:Suborder;
			var soFolder:File;
			var relFile:File;
			var suborders:Array=order.suborders;
			order.resetSuborders();
			
			for each(so in suborders){
				if(so){
					soFolder=rootFolder.resolvePath(so.ftp_folder);
					if(!soFolder.exists) return  'Папка подзаказа не найдена: '+soFolder.nativePath; 
					relFile=soFolder.resolvePath('relations.txt');
					if(!relFile.exists) return 'Файл подзаказа не найден: '+relFile.nativePath; 
					//read relations.txt
					var txt:String;
					try{
						var fs:FileStream=new FileStream();
						fs.open(relFile,FileMode.READ);
						txt=fs.readUTFBytes(fs.bytesAvailable);
						fs.close();
					} catch(err:Error){
						return 'Ошибка чтения файла: '+relFile.nativePath;
					}
					txt=txt.replace(File.lineEnding, '\n');
					var lines:Array=txt.split('\n');
					var line:String;
					var newSo:Suborder;
					var poz:int;
					if(lines && lines.length>0){
						//parse last number
						//0000 - Календарь 12 мес._20 × 30_6899.jpg 
						for each (line in lines){
							if(line){
								txt=line;
								poz=txt.lastIndexOf('_');
								if(poz!=-1){
									txt=txt.substr(poz+1);
									poz=txt.lastIndexOf('.');
									if(poz!=-1){
										txt=txt.substring(0,poz);
										var subId:int=int(txt);
										if(subId){
											newSo=so.clone();
											newSo.sub_id=subId;
											//newSo.fillId();
											//newSo.fillFolder();
											order.addSuborder(newSo);
										}else{
											return 'Ошибка определения подзаказа: '+line;
										}
									}
								}
							}
						}
					}
				}
			}
			return '';
		}
	}
}