package com.photodispatcher.factory{
	import com.akmeful.card.data.CardProject;
	import com.akmeful.fotocalendar.data.FotocalendarProject;
	import com.akmeful.fotokniga.book.data.Book;
	import com.akmeful.magnet.data.MagnetProject;
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.mysql.entities.BookPgTemplate;
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.model.mysql.entities.FieldValue;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.PrintGroupFile;
	import com.photodispatcher.model.mysql.entities.Roll;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.SubOrder;
	import com.photodispatcher.provider.fbook.FBookProject;
	import com.photodispatcher.provider.fbook.model.PageData;
	import com.photodispatcher.util.StrUtil;
	import com.photodispatcher.util.UnitUtil;
	
	import flash.filesystem.File;
	import flash.geom.Point;
	import flash.utils.Dictionary;
	
	import mx.collections.ArrayCollection;
	import mx.collections.ArrayList;
	import mx.collections.ListCollectionView;
	import mx.controls.Alert;
	
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
		public function build(source:Source, map:Dictionary, orderId:String, preview:Boolean=false):Array{
			var pg:PrintGroup;
			var cpg:PrintGroup;
			var fpg:PrintGroup;
			var pgf:PrintGroupFile;
			var o:Object;
			var af:Array;
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
					bookSynonym=BookSynonym.translatePath(path,source.type);
					//if(!bookSynonym && preview) bookSynonym=BookSynonym.translateAlias( Path(path,source.type);
					if (bookSynonym){
						//reset book_type 4 preview 
						if(preview && bookSynonym.book_type==BookSynonym.BOOK_TYPE_JOURNAL) bookSynonym.book_type=BookSynonym.BOOK_TYPE_BOOK;
						//parse files & book params
						pg=parseBookFiles(af);
						//covers group
						cpg=bookSynonym.createPrintGroup(path, BookSynonym.BOOK_PART_COVER, pg.butt);
						if(cpg){
							//cover group
							if(pg.height){
								cpg.height=pg.height;
								//бывший костыль if(cpg.book_type==BookSynonym.BOOK_TYPE_BOOK) cpg.height+=8; теперь -height_add
								cpg.height=cpg.height+2*cpg.bookTemplate.height_add;
								//BUGGGGG
								//cpg.bookTemplate.sheet_len=UnitUtil.mm2Pixels300(cpg.height);
							}
							fillCovers(pg,cpg);
							if(cpg.files){
								cpg.book_num=pg.book_num;
								cpg.file_num=cpg.files.length;
								resultMap[path+'~'+cpg.book_part+'~'+cpg.key()]=cpg;
							}
						}
						//insert group
						cpg=bookSynonym.createPrintGroup(path, BookSynonym.BOOK_PART_INSERT);
						if(cpg){
							fillInsert(pg,cpg);
							if(cpg.files){
								cpg.book_num=pg.book_num;
								cpg.file_num=cpg.files.length;
								resultMap[path+'~'+cpg.book_part+'~'+cpg.key()]=cpg;
							}
						}
						//sheets group
						cpg=bookSynonym.createPrintGroup(path, BookSynonym.BOOK_PART_BLOCK);
						if(cpg){
							fillSheets(pg,cpg, preview);
							if(cpg.files){
								cpg.book_num=pg.book_num;
								cpg.file_num=cpg.files.length;
								resultMap[path+'~'+cpg.book_part+'~'+cpg.key()]=cpg;
							}
						}
					}else{
						//parse pg from path by parts
						//TODO check if read completed
						//var afv:Array=dicDAO.translatePath(source.type_id,path);
						var afv:Array=FieldValue.translatePath(source.type,path);
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
									if(source.type!= SourceType.SRC_FOTOKNIGA){
										if(fpg && fpg.files && fpg.files.length>0){
											(fpg.files[0] as PrintGroupFile).prt_qty=1;
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
			for each (o in resultMap){
				pg= o as PrintGroup;
				if(pg) resultArr.push(pg);
			}
			//sort, 4 book preserve book_part order
			resultArr.sortOn(['path','book_part'],[Array.CASEINSENSITIVE,Array.NUMERIC]);
			//postprocess
			var prints:int;
			for (var i:int = 0; i < resultArr.length; i++){
				pg= resultArr[i] as PrintGroup;
				if(pg){
					pg.order_id=orderId;
					pg.id=orderId+'_'+(i+1).toString();
					//calc prints qtt
					prints=0;
					if(pg.book_type==0){
						//photo print
						for each(pgf in pg) prints+=pgf.prt_qty>0?pgf.prt_qty:1;
					}else{
						//book
						prints=pg.book_num*pg.sheet_num;
					}
					pg.prints=prints;
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
			//TODO bug if ???_.... <3chars
			var prop:String=fileName.split('_')[0];
			f.prt_qty=int(prop.substr(0,prop.length-2));
			if(f.prt_qty==0) f.prt_qty=1;
			//var dic:DictionaryDAO=new DictionaryDAO();
			//var fv:FieldValue=dic.translateWord(0,prop.substr(-1,1),'correction');
			var fv:FieldValue=FieldValue.translateWord(0,prop.substr(-1,1),'correction');
			if(fv) pg.correction=fv.value;
			//fv=dic.translateWord(0,prop.substr(-2,1),'cutting');
			fv=FieldValue.translateWord(0,prop.substr(-2,1),'cutting');
			if(fv) pg.cutting=fv.value;
			
			pg.addFile(f);
			return pg;
		}
		
		private function isBookFile(name:String):Boolean{
			var ext:String=StrUtil.getFileExtension(name);
			if(!ALLOWED_EXTENSIONS[ext]) return false;
			//check pattern
			var re:RegExp=/\d{3}-\d{2}/g;
			var result:Boolean=re.test(name) && re.lastIndex==6;
			return result;
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
					//var ext:String=StrUtil.getFileExtension(fileName);
					//if(ALLOWED_EXTENSIONS[ext]){
					if(isBookFile(fileName)){
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
							if(f.book_num>0) f.isCustom=true;
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
			if(res.files){
				for each (f in res.files){
					//set print qtty
					f.prt_qty=1;//f.book_num==0?res.book_num:1;
					//add caption 4 annotate
					var txt:String;
					//book
					txt=(f.book_num==0?PrintGroupFile.CAPTION_BOOK_NUM_HOLDER:StrUtil.lPad(f.book_num.toString(),2))+'('+StrUtil.lPad(res.book_num.toString(),2)+')';
					//sheet
					txt=txt+'-'+StrUtil.lPad(f.page_num.toString(),2)+'('+StrUtil.lPad(res.pageNumber.toString(),2)+')';
					//butt
					if(res.butt && f.page_num==0){
						txt=txt+' t'+res.butt.toString();
					}
					f.caption=txt;
				}
				//sort by book / sheet
				//res.getFiles().sortOn(['book_num','page_num'],[Array.NUMERIC,Array.NUMERIC]);
			}
			return res;
		}
		
		private function fillCovers(pg:PrintGroup, dst:PrintGroup):void{
			if(!pg.files) return;
			var f:PrintGroupFile;
			for each(f in pg.files){
				if (f && (f.page_num==0 || 
					(dst.book_type==BookSynonym.BOOK_TYPE_JOURNAL && !dst.bookTemplate.is_sheet_ready && dst.is_pdf && (f.page_num==1 || f.page_num==pg.pageNumber)))){
					dst.addFile(f);
				}
			}
			//set sheets number
			dst.sheet_num=1;
			if(dst.book_type==BookSynonym.BOOK_TYPE_JOURNAL && dst.is_pdf && !dst.bookTemplate.is_sheet_ready) dst.sheet_num=2;
			//sort 
			if(dst.files){
				var arr:Array=dst.files.toArray();
				arr.sortOn(['book_num','page_num'],[Array.NUMERIC,Array.NUMERIC]);
				dst.files= new ArrayCollection(arr);
			}
		}
		
		private function fillInsert(pg:PrintGroup, dst:PrintGroup):void{
			if(!pg.files) return;
			//var res:Array=[];
			var f:PrintGroupFile;
			for each(f in pg.files){
				if (f && f.page_num==0){
					dst.addFile(f);
				}
			}
			//set sheets number
			dst.sheet_num=1;
			//sort 
			if(dst.files){
				var arr:Array=dst.files.toArray();
				arr.sortOn(['book_num','page_num'],[Array.NUMERIC,Array.NUMERIC]);
				dst.files= new ArrayCollection(arr);
			}
		}
		
		private function fillSheets(pg:PrintGroup, dst:PrintGroup, preview:Boolean):void{
			if(!pg.files) return;
			var f:PrintGroupFile;
			for each(f in pg.files){
				if (f && f.page_num!=0 
					&& !(dst.book_type==BookSynonym.BOOK_TYPE_JOURNAL && dst.is_pdf && !dst.bookTemplate.is_sheet_ready && (f.page_num==1 || f.page_num==pg.pageNumber))){
					dst.addFile(f);
				}
			}
			if(!dst.files || dst.files.length==0) return; 
			
			//detect sheets number
			var pageMax:int=0;
			var pageMin:int=int.MAX_VALUE;
			for each(f in dst.files){
				pageMax=Math.max(pageMax,f.page_num);
				pageMin=Math.min(pageMin,f.page_num);
			}
			dst.sheet_num=pageMax-pageMin+1;
			if (dst.is_pdf && !dst.bookTemplate.is_sheet_ready){
				dst.sheet_num=dst.sheet_num/2;
				if(dst.is_duplex && !preview){
					if(dst.book_type==BookSynonym.BOOK_TYPE_BOOK) dst.sheet_num++; //blank page
					//duplex so
					dst.sheet_num=dst.sheet_num/2;
				}
			}
			
			//sort by book / sheet
			if(dst.files){
				var arr:Array=dst.files.toArray();
				arr.sortOn(['book_num','page_num'],[Array.NUMERIC,Array.NUMERIC]);
				dst.files= new ArrayCollection(arr);
			}
		}
		
		public function buildFromSuborders(order:Order):Array{
			var result:Array=[];
			if(!order || !order.suborders || order.suborders.length==0) return result;
			var pgNum:int=1;
			if(order.printGroups) pgNum=order.printGroups.length+1;
			var so:SubOrder;
			var proj:FBookProject;
			var page:PageData;
			var paper:int;
			var coverPixels:Point;
			var slicePixels:Point;
			var blockPixels:Point;
			var bookSynonym:BookSynonym;
			
			var pgCover:PrintGroup;
			var pgBody:PrintGroup;
			//var pg:PrintGroup;
			var pgf:PrintGroupFile;
			for each(so in order.suborders){
				proj=so.project;
				if(proj && so.state<OrderState.CANCELED){
					//reset vars
					paper=0;
					coverPixels=proj.getPixelSise(BookSynonym.BOOK_PART_COVER);
					blockPixels=proj.getPixelSise(BookSynonym.BOOK_PART_BLOCK);
					slicePixels=proj.getPixelSise(BookSynonym.BOOK_PART_INSERT);
					pgCover=null;
					pgBody=null;
					bookSynonym=null;
					
					//set suborder project type
					so.proj_type=proj.bookType;
					//save alias
					so.alias=proj.printAlias;
					
					if (proj.bookType==BookSynonym.BOOK_TYPE_BCARD){
						//set print qtty 4 Card project
						var bcp:CardProject=proj.project as CardProject;
						so.prt_qty= so.prt_qty*bcp.getTemplate().formatPageCount;
					}
					
					//try to use print alias
					bookSynonym=BookSynonym.translateAlias(proj.printAlias);
					if(!bookSynonym){
						//detect paper
						var fv:FieldValue=FieldValue.translateWord(SourceType.SRC_FBOOK,proj.paperId,'paper');
						if(fv){
							paper=int(fv.value);
						}else{
							//TODO hardcoded matovaja
							paper=11;
						}
					}
					//try to finde by pape & format 4 book
					//if(!bookSynonym && proj.bookType==BookSynonym.BOOK_TYPE_BOOK && !proj.isPageSliced(0)) bookSynonym=BookSynonymDAO.guess(paper, coverPixels, blockPixels);
					if(!bookSynonym) bookSynonym=BookSynonym.guess(paper, coverPixels, blockPixels, slicePixels);
					if(!bookSynonym){
						//build
						bookSynonym= new BookSynonym();
						bookSynonym.templates=new ListCollectionView(new ArrayList());
						var pt:BookPgTemplate;
						if (proj.bookType==BookSynonym.BOOK_TYPE_BOOK ||
							proj.bookType==BookSynonym.BOOK_TYPE_JOURNAL ||
							proj.bookType==BookSynonym.BOOK_TYPE_LEATHER){
							//crete block template
							pt= new BookPgTemplate();
							pt.book_part=BookSynonym.BOOK_PART_BLOCK;
							pt.paper=paper;
							//get width by roll
							pt.width=Roll.getStandartWidth(int(Math.min(blockPixels.x,blockPixels.y)));
							//by real size
							if(pt.width==0) pt.width=UnitUtil.pixels2mm300(Math.min(blockPixels.x,blockPixels.y));
							pt.height=UnitUtil.pixels2mm300(Math.max(blockPixels.x,blockPixels.y));
							//set template size
							pt.sheet_len=blockPixels.x;
							pt.sheet_width=blockPixels.y;
							bookSynonym.templates.addItem(pt);
							
							if(coverPixels || slicePixels){
								//crete cover template
								pt= new BookPgTemplate();
								if(proj.isPageSliced(0)){
									pt.book_part=BookSynonym.BOOK_PART_INSERT;
									coverPixels=slicePixels;
								}else{
									pt.book_part=BookSynonym.BOOK_PART_COVER;
								}
								pt.paper=paper;
								//get width by roll
								pt.width=Roll.getStandartWidth(int(Math.min(coverPixels.x,coverPixels.y)));
								//by real size
								if(pt.width==0) pt.width=UnitUtil.pixels2mm300(Math.min(coverPixels.x,coverPixels.y));
								pt.height=UnitUtil.pixels2mm300(Math.max(coverPixels.x,coverPixels.y));
								//set template size
								pt.sheet_len=coverPixels.x;
								pt.sheet_width=coverPixels.y;
								bookSynonym.templates.addItem(pt);
							}
						}else{
							//crete block template by first page
							pt= new BookPgTemplate();
							pt.book_part=BookSynonym.BOOK_PART_BLOCK;
							pt.paper=paper;
							//get width by roll
							pt.width=Roll.getStandartWidth(int(Math.min(blockPixels.x,blockPixels.y)));
							//by real size
							if(pt.width==0) pt.width=UnitUtil.pixels2mm300(Math.min(blockPixels.x,blockPixels.y));
							pt.height=UnitUtil.pixels2mm300(Math.max(blockPixels.x,blockPixels.y));
							//set template size
							pt.sheet_len=blockPixels.x;
							pt.sheet_width=blockPixels.y;
							bookSynonym.templates.addItem(pt);
						}
					}
					//create print gruops
					if (proj.bookType==BookSynonym.BOOK_TYPE_BOOK ||
						proj.bookType==BookSynonym.BOOK_TYPE_JOURNAL ||
						proj.bookType==BookSynonym.BOOK_TYPE_LEATHER){
						//cover
						pgCover=bookSynonym.createPrintGroup(so.ftp_folder, BookSynonym.BOOK_PART_COVER, UnitUtil.pixels2mm300(proj.buttWidth()));
						if(pgCover){
							pgCover.order_id=order.id;
							pgCover.path=so.ftp_folder;
							pgCover.book_type=proj.bookType; 
							pgCover.book_num=so.prt_qty;
							pgCover.height=UnitUtil.pixels2mm300(Math.max(coverPixels.x,coverPixels.y));
							//pgCover.bookTemplate.sheet_len=Math.max(coverPixels.x,coverPixels.y);
						}else{
							//insert? 
							pgCover=bookSynonym.createPrintGroup(so.ftp_folder, BookSynonym.BOOK_PART_INSERT);
							if(pgCover){
								pgCover.order_id=order.id;
								pgCover.path=so.ftp_folder;
								pgCover.book_type=proj.bookType; 
								pgCover.book_num=so.prt_qty;
							}
						}
					}
					//block
					pgBody=bookSynonym.createPrintGroup(so.ftp_folder, BookSynonym.BOOK_PART_BLOCK);
					pgBody.order_id=order.id;
					pgBody.path=so.ftp_folder;
					pgBody.book_type=proj.bookType; 
					pgBody.book_num=so.prt_qty;
					
					//fill
					for each(page in proj.projectPages){
						if(page){
							//add file
							pgf= new PrintGroupFile();
							if(!proj.isPageSliced(page.pageNum)){
								pgf.file_name=page.outFileName();
							}else{
								pgf.file_name=page.outFileName(1); //first & only one slice
							}
							//pgf.page_num=page.pageNum;
							//pgf.caption=PrintGroupFile.CAPTION_BOOK_NUM_HOLDER+'-'+StrUtil.lPad(page.pageNum.toString(),2);
							pgf.page_num=page.sheetNum;
							pgf.caption=PrintGroupFile.CAPTION_BOOK_NUM_HOLDER+'-'+StrUtil.lPad(page.sheetNum.toString(),2);
							pgf.book_num=0;
							pgf.prt_qty=1;
							if(proj.isPageCover(page.pageNum)){
								if(pgCover){
									if(pgCover.butt){
										//add butt to caption
										pgf.caption=pgf.caption+' t'+pgCover.butt.toString();
									}
									pgCover.addFile(pgf);
								}
							}else{
								pgBody.addFile(pgf);
							}
						}
					}
					
					//add to order
					if(pgCover && pgCover.files && pgCover.files.length>0){
						pgCover.sub_id=so.sub_id;
						pgCover.id=order.id+'_'+pgNum.toString();
						pgCover.sheet_num=pgCover.files.length;
						pgCover.prints=pgCover.book_num*pgCover.sheet_num;
						if(!order.printGroups) order.printGroups=new ArrayCollection();
						order.printGroups.addItem(pgCover);
						result.push(pgCover);
						pgNum++;
					}
					if(pgBody.files && pgBody.files.length>0){
						pgBody.sub_id=so.sub_id;
						pgBody.id=order.id+'_'+pgNum.toString();
						pgBody.sheet_num=pgBody.files.length;
						pgBody.prints=pgBody.book_num*pgBody.sheet_num;
						if(!order.printGroups) order.printGroups=new ArrayCollection();
						order.printGroups.addItem(pgBody);
						result.push(pgBody);
						pgNum++;
					}
				}
			}
			return result;
		}
		
		public function buildPreview(order:Order):Boolean{
			if(!order) return false;
			if(!order.printGroups || order.printGroups.length==0) return false;
			var src:Source=Context.getSource(order.source);
			if(!src) return false;
			//check
			if(!Context.getAttribute('workFolder')){
				Alert.show('Не задана рабочая папка');
				return false;
			}
			var pg:PrintGroup=order.printGroups[0] as PrintGroup;
			var bookSynonym:BookSynonym;
			if(!pg) return false;

			//build file list
			var fName:String=src.getWrkFolder()+File.separator+order.ftp_folder+File.separator+pg.path;
			var fl:File=new File(fName);
			if(!fl.exists || !fl.isDirectory){
				Alert.show('Папка заказа не найдена');
				return false;
			}
			var rootDir:File=fl;
			var a:Array=rootDir.getDirectoryListing();
			var fNames:Array=[];
			for each(fl in a){
				if(!fl.isDirectory) fNames.push(fl.name);
			}
			//parse files & book params
			var ppg:PrintGroup=parseBookFiles(fNames);
			if(!ppg) return false;
			
			//try get synonym
			try{
				bookSynonym=BookSynonym.translatePath(pg.path,src.type);
			} catch(error:Error){
				trace('buildPreview err: '+error.message);
			}
			var template:BookPgTemplate;
			if(!bookSynonym){
				template=new BookPgTemplate;
				template.is_pdf=false;
				template.is_sheet_ready= false;
			}
			for each(pg in order.printGroups){
				if(pg.book_type!=0){
					//build book prview
					//reset book_type 4 preview 
					if(pg.book_type==BookSynonym.BOOK_TYPE_JOURNAL) pg.book_type=BookSynonym.BOOK_TYPE_BOOK;
					if(pg.book_part==BookSynonym.BOOK_PART_BLOCK){
						if(bookSynonym){
							pg.bookTemplate=bookSynonym.blockTemplate;
						}else{
							pg.bookTemplate=template;
						}
						fillSheets(ppg, pg, true);
					}else if(pg.book_part==BookSynonym.BOOK_PART_COVER || pg.book_part==BookSynonym.BOOK_PART_INSERT){
						if(bookSynonym){
							pg.bookTemplate=bookSynonym.coverTemplate;
						}else{
							pg.bookTemplate=template;
						}
						fillInsert(ppg,pg);
					}

					//pg.book_num=ppg.book_num;
					pg.pageNumber=ppg.pageNumber;
					pg.file_num=pg.files.length;
				}
				
			}
			return true;
		}
	}
}