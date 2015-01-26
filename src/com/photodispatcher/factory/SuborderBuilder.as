package com.photodispatcher.factory{
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.SubOrder;
	import com.photodispatcher.model.mysql.entities.SubordersTemplate;
	
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.Dictionary;
	
	import mx.collections.ListCollectionView;

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
		public static function build(source:Source, order:Order):void{
			if(!source || !order || !order.fileStructure) return;
			var path:String;
			var t:SubordersTemplate;
			var o:SubOrder;
			//var result:Array;

			//for profoto type
			if(source.type==SourceType.SRC_PROFOTO){
				order.resetSuborders();
				for (path in order.fileStructure){
					if(path){
						t=SubordersTemplate.translatePath(path,source.type);
						if(t){
							o= new SubOrder();
							o.order_id=order.id;
							o.src_type=t.sub_src_type;
							o.ftp_folder=path;
							/*
							if(!result) result=[];
							result.push(o);
							*/
							order.addSuborder(o);
							delete order.fileStructure[path];
						}
					}
				}
			}
			/*
			//for fotokniga type
			if(source.type==SourceType.SRC_FOTOKNIGA && order.src_id){
				order.resetSuborders();
				//get subOrder id (-#)
				var subId:String; //:int;
				var a:Array=order.src_id.split('-');
				if(a && a.length>=2){
					subId=a[1];
					o= new SubOrder();
					o.order_id=order.id;
					o.sub_id=subId;
					o.src_type=SourceType.SRC_FBOOK;
					if(order.fotos_num>0) o.prt_qty=order.fotos_num;
					order.addSuborder(o);
				}
			}
			*/
			//return result;
		}

		public static function buildFromFileSystem(source:Source, order:Order):String{
			if (!source || !order || !order.hasSuborders) return '';
			//parse profoto only 
			if(source.type!=SourceType.SRC_PROFOTO) return '';
			var rootFolder:File=new File(source.getWrkFolder());
			rootFolder=rootFolder.resolvePath(order.ftp_folder);
			if(!rootFolder.exists || !rootFolder.isDirectory) return 'Папка заказа не найдена: '+rootFolder.nativePath;

			var so:SubOrder;
			var soFolder:File;
			var relFile:File;
			var suborders:ListCollectionView=order.suborders;
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
					var newSo:SubOrder;
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
										//var subId:int=int(txt);
										if(txt){
											newSo=so.clone();
											newSo.sub_id=txt;
											//newSo.fillId();
											//newSo.fillFolder();
											newSo.projectIds.push(newSo.sub_id);
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