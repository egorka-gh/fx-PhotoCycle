package com.photodispatcher.factory{
	import com.akmeful.fotocalendar.data.FotocalendarProject;
	import com.akmeful.fotokniga.book.data.Book;
	import com.photodispatcher.model.BookSynonym;
	import com.photodispatcher.model.FieldValue;
	import com.photodispatcher.model.Order;
	import com.photodispatcher.model.OrderState;
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.PrintGroupFile;
	import com.photodispatcher.model.Source;
	import com.photodispatcher.model.SourceType;
	import com.photodispatcher.model.Suborder;
	import com.photodispatcher.model.dao.BookSynonymDAO;
	import com.photodispatcher.model.dao.DictionaryDAO;
	import com.photodispatcher.model.dao.PrintGroupFileDAO;
	import com.photodispatcher.provider.fbook.FBookProject;
	import com.photodispatcher.provider.fbook.data.PageData;
	import com.photodispatcher.util.StrUtil;
	import com.photodispatcher.util.UnitUtil;
	
	import flash.utils.Dictionary;

	public class PrintGroupBuilder{
		private static const ALLOWED_EXTENSIONS:Object={jpg:true,jpeg:true,png:true,tif:true,tiff:true,bmp:true,gif:true};

		/**
		 * parse PrintGroups from file structure
		 * 
		 * @param source
		 * @param order
		 * @param map
		 * @return array of PrintGroup
		 * trows ERR_READ_LOCK
		 */
		public function build(source:Source, map:Dictionary, orderId:String):Array{
			//var dicDAO:DictionaryDAO=new DictionaryDAO();
			//var synonymDAO:PrintGroupSynonymDAO= new PrintGroupSynonymDAO();
			//var synonymDAO:BookSynonymDAO= new BookSynonymDAO();
			var pg:PrintGroup;
			var cpg:PrintGroup;
			var fpg:PrintGroup;
			var pgf:PrintGroupFile;
			var o:Object;
			var af:Array;
			//var apg:Array;
			var bookSynonym:BookSynonym;
			var resultMap:Object=new Object;
			
			
			if(!source || !map) return [];
			//create pg 4 each file then group by print params
			
			for (var key:Object in map){
				var path:String=key as String;
				if(path){
					//get files
					af=map[path] as Array;
					//parse pg from path, exact synonym
					//bookSynonym=synonymDAO.translatePath(path,source.type_id);
					bookSynonym=BookSynonymDAO.translatePath(path,source.type_id);
					if (bookSynonym){
						//parse files & book params
						pg=parseBookFiles(af);
						//covers group
						cpg=bookSynonym.createPrintGroup(path, BookSynonym.BOOK_PART_COVER, pg.butt);
						if(cpg){
							//cover group
							if(pg.height){
								cpg.height=pg.height;
								cpg.bookTemplate.sheet_len=UnitUtil.mm2Pixels300(pg.height);
							}
							fillCovers(pg,cpg);
							if(cpg.getFiles()){
								cpg.book_num=pg.book_num;
								cpg.file_num=cpg.getFiles().length;
								resultMap[path+'~'+cpg.book_part+'~'+cpg.key()]=cpg;
							}
						}
						//insert group
						cpg=bookSynonym.createPrintGroup(path, BookSynonym.BOOK_PART_INSERT);
						if(cpg){
							fillInsert(pg,cpg);
							if(cpg.getFiles()){
								cpg.book_num=pg.book_num;
								cpg.file_num=cpg.getFiles().length;
								resultMap[path+'~'+cpg.book_part+'~'+cpg.key()]=cpg;
							}
						}
						//sheets group
						cpg=bookSynonym.createPrintGroup(path, BookSynonym.BOOK_PART_BLOCK);
						if(cpg){
							fillSheets(pg,cpg);
							if(cpg.getFiles()){
								cpg.book_num=pg.book_num;
								cpg.file_num=cpg.getFiles().length;
								resultMap[path+'~'+cpg.book_part+'~'+cpg.key()]=cpg;
							}
						}
					}else{
						//parse pg from path by parts
						//TODO check if read completed
						//var afv:Array=dicDAO.translatePath(source.type_id,path);
						var afv:Array=DictionaryDAO.translatePath(source.type_id,path);
						pg=new PrintGroup();
						pg.path=path;
						for each (o in afv){
							var fv:FieldValue=o as FieldValue;
							if(fv){
								if(pg.hasOwnProperty(fv.field)){
									pg[fv.field]=fv.value;
								}
							}
						}
						//scan/parse files
						if(af){
							for each (o in af){
								var s:String=o as String;
								if(s){
									fpg=parseFile(pg,s);
									//TODO use prt_qty only 4 SRC_FOTOKNIGA
									if(source.type_id!= SourceType.SRC_FOTOKNIGA){
										if(fpg && fpg.getFiles() && fpg.getFiles().length>0){
											(fpg.getFiles()[0] as PrintGroupFile).prt_qty=1;
										}
									}
									//put into result map grouped by path & print attr 
									if(fpg){
										var p:PrintGroup= resultMap[path+'~'+fpg.key()] as PrintGroup;
										if(p){
											p.addFile(fpg.files[0] as PrintGroupFile);
										}else{
											resultMap[path+'~'+fpg.key()]=fpg;
										}
									}
								}
							}
						}
					}
				}
			}
			//completed
			var resultArr:Array=[];
			var i:int=1;
			for each (o in resultMap){
				pg= o as PrintGroup;
				if(pg){
					pg.order_id=orderId;
					pg.id=orderId+'_'+i.toString();
					resultArr.push(pg);
					i++;
				}
			}
			return resultArr;
		}

		private function parseFile(pgroup:PrintGroup,fileName:String):PrintGroup{
			if (!pgroup || !fileName) return null;
			//check if valid file type
			var ext:String=StrUtil.getFileExtension(fileName);
			if (!ALLOWED_EXTENSIONS[ext]){
				trace('Invalid file type "'+fileName+'". File skipped');
				return null;
			}
			var pg:PrintGroup=pgroup.clone();
			var f:PrintGroupFile=new PrintGroupFile();
			f.file_name=fileName;
			f.caption=fileName;
			//parse fileName
			var prop:String=fileName.split('_')[0];
			f.prt_qty=int(prop.substr(0,prop.length-2));
			if(f.prt_qty==0) f.prt_qty=1;
			//var dic:DictionaryDAO=new DictionaryDAO();
			//var fv:FieldValue=dic.translateWord(0,prop.substr(-1,1),'correction');
			var fv:FieldValue=DictionaryDAO.translateWord(0,prop.substr(-1,1),'correction');
			if(fv) pg.correction=fv.value;
			//fv=dic.translateWord(0,prop.substr(-2,1),'cutting');
			fv=DictionaryDAO.translateWord(0,prop.substr(-2,1),'cutting');
			if(fv) pg.cutting=fv.value;
			
			pg.addFile(f);
			return pg;
		}

		private function parseBookFiles(files:Array):PrintGroup{
			var res:PrintGroup= new PrintGroup();
			var f:PrintGroupFile;
			var re:RegExp;
			//var books:int=0;
			
			var arr:Array;
			if(!files || files.length==0) return res;
			for each (var fileName:String in files){
				if(fileName){
					//check if valid file type
					var ext:String=StrUtil.getFileExtension(fileName);
					if(ALLOWED_EXTENSIONS[ext]){
						var s:String;
						//remove ext
						s=StrUtil.removeFileExtension(fileName);
						//000-00_309_fit_sh2_5.jpg
						//remove fit siffix
						s=s.replace('_fit','');
						//get book num
						re=/_sh\d+/;
						arr=s.match(re);
						if(arr && arr.length>0){
							var sb:String=arr[0];
							sb=sb.substr(3);
							res.book_num=int(sb);
						}
						//remove _sh substr
						s=s.replace(re,'');
						//000-00_309_5.jpg
						re=/[-_]/;
						arr=s.split(re);
						if(arr && arr.length>1 && arr.length<5){
							//process
							f=new PrintGroupFile();
							f.file_name=fileName;
							//cover lenth
							if(arr.length>=3) res.height=Math.max(res.height,int(arr[2]));
							//butt lenth
							if(arr.length==4) res.butt=Math.max(res.butt,int(arr[3]));
							f.book_num=int(arr[0]);
							f.page_num=int(arr[1]);
							//boks num
							res.book_num=Math.max(res.book_num,f.book_num,1);
							//pages number
							res.pageNumber=Math.max(res.pageNumber,f.page_num);
							res.addFile(f);
						}
					}
				}
			}
			if(res.getFiles()){
				for each (f in res.getFiles()){
					//set print qtty
					f.prt_qty=1;//f.book_num==0?res.book_num:1;
					//add caption 4 annotate
					var txt:String;
					/*
					//book
					txt=(f.book_num==0?PrintGroupFile.CAPTION_BOOK_NUM_HOLDER:StrUtil.lPad(f.book_num.toString(),2))+'/'+StrUtil.lPad(res.book_num.toString(),2);
					//sheet
					txt=txt+'-'+StrUtil.lPad(f.page_num.toString(),2)+'/'+StrUtil.lPad(res.pageNumber.toString(),2);
					*/
					//book
					txt=(f.book_num==0?PrintGroupFile.CAPTION_BOOK_NUM_HOLDER:StrUtil.lPad(f.book_num.toString(),2))+'('+StrUtil.lPad(res.book_num.toString(),2)+')';
					//sheet
					txt=txt+'-'+StrUtil.lPad(f.page_num.toString(),2)+'('+StrUtil.lPad(res.pageNumber.toString(),2)+')';
					//butt
					if(res.butt && f.page_num==0){
						txt=txt+' t'+res.butt.toString();
					}
					/*
					//book
					var txt:String=(f.book_num==0?PrintGroupFile.CAPTION_BOOK_NUM_HOLDER:StrUtil.lPad(f.book_num.toString(),3));
					//sheet
					txt=txt+'-'+StrUtil.lPad(f.page_num.toString(),2);
					//butt
					if(res.butt && f.page_num==0){
						txt=txt+' t'+res.butt.toString();
					}
					*/
					f.caption=txt;
				}
				//sort by book / sheet
				//res.getFiles().sortOn(['book_num','page_num'],[Array.NUMERIC,Array.NUMERIC]);
			}
			return res;
		}

		private function fillCovers(pg:PrintGroup, dst:PrintGroup):void{
			if(!pg.getFiles()) return;
			//var res:Array=[];
			var f:PrintGroupFile;
			for each(f in pg.getFiles()){
				if (f && (f.page_num==0 || (dst.book_type==BookSynonym.BOOK_TYPE_JOURNAL && dst.is_pdf && (f.page_num==1 || f.page_num==pg.pageNumber)))){
					dst.addFile(f);
				}
			}
			//sort 
			if(dst.getFiles()) dst.getFiles().sortOn(['book_num','page_num'],[Array.NUMERIC,Array.NUMERIC]);
		}

		private function fillInsert(pg:PrintGroup, dst:PrintGroup):void{
			if(!pg.getFiles()) return;
			//var res:Array=[];
			var f:PrintGroupFile;
			for each(f in pg.getFiles()){
				if (f && f.page_num==0){
					dst.addFile(f);
				}
			}
			//sort 
			if(dst.getFiles()) dst.getFiles().sortOn(['book_num','page_num'],[Array.NUMERIC,Array.NUMERIC]);
		}

		private function fillSheets(pg:PrintGroup, dst:PrintGroup):void{
			if(!pg.getFiles()) return;
			var f:PrintGroupFile;
			for each(f in pg.getFiles()){
				if (f && f.page_num!=0 && !(dst.book_type==BookSynonym.BOOK_TYPE_JOURNAL && dst.is_pdf && (f.page_num==1 || f.page_num==pg.pageNumber))){
					dst.addFile(f);
				}
			}
			//sort by book / sheet
			if(dst.getFiles()) dst.getFiles().sortOn(['book_num','page_num'],[Array.NUMERIC,Array.NUMERIC]);
		}

		public function buildFromSuborders(order:Order):void{
			if(!order || !order.suborders || order.suborders.length==0) return;
			var pgNum:int=1;
			if(order.printGroups) pgNum=order.printGroups.length+1;
			var so:Suborder;
			var proj:FBookProject;
			var page:PageData;
			var paper:int;
			for each(so in order.suborders){
				if(so){
					proj=so.project;
					if(proj){
						//TODO detect paper
						//TODO add try catch 
						var fv:FieldValue;
						if(proj.type==FotocalendarProject.PROJECT_TYPE){
							//hardcoded matovaia
							fv=DictionaryDAO.translateWord(SourceType.SRC_FBOOK,'1','paper');
						}else if(proj.type==Book.PROJECT_TYPE){
							var prj:Book=proj.project as Book;
							if(prj){
								fv=DictionaryDAO.translateWord(SourceType.SRC_FBOOK,prj.template.paper.id.toString(),'paper');
							}
						}
						if(fv) paper=int(fv.value);
						for each(page in proj.pages){
							//TODO generate pg
							
						}
					}
				}
			}
			
			
		}
	}
}