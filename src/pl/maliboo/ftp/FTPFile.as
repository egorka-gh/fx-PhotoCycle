package pl.maliboo.ftp{	

	public class FTPFile{
		public static const LOAD_WAIT:int=0;
		public static const LOAD_STARTED:int=1;
		public static const LOAD_COMPLETE:int=2;
		public static const LOAD_ERR:int=-1;
		
		public static const RESIZE_WAIT:int=20;
		public static const RESIZE_PREPARED:int=21;
		public static const RESIZE_STARTED:int=22;
		public static const RESIZE_COMPLETE:int=23;
		public static const RESIZE_ERR:int=25;

		public var _name:String;
		public var _path:String;
		public var _size:int;
		public var _date:String;
		public var _isDir:Boolean;
		public var tag:String;
		public var moveTo:String;
		public var renameTo:String;
		public var data:*;
		
		private var _loadState:int=LOAD_WAIT;
		private var _errCount:int=0;
		
		public function get loadState():int{
			return _loadState;
		}
		public function set loadState(value:int):void{
			if(value<0) _errCount++;
			_loadState = value;
		}
		public function get errCount():int{
			return _errCount;
		}
		public function resetErrCount():void{
			_errCount=0;
		}

		
		public function FTPFile (name:String="",
								path:String="", 
								size:int=0,
								date:String="",
								isDir:Boolean=false,
								tag:String=''){
			_name = name;
			_path = path;
			_size = size;
			_date = date;
			_isDir = isDir;
			this.tag=tag;
		}
		
		public function get fullPath ():String{
			return path+"/"+name;
		}
		
		public function get name ():String{
			return _name;
		}
		
		public function get path ():String{
			return _path;
		}
		
		public function get size ():int{
			return _size;
		}
		
		public function get date ():String{
			return _date;
		}
		public function get isDir ():Boolean{
			return _isDir;
		}
		
		public static function parseFromListEntry (entry:String, dir:String):FTPFile{
			//trace('parse entry ' + entry);
			var file:FTPFile = new FTPFile();
			var fields:Array = entry.split(/ +/g);
			
			var isDir:Boolean = fields[0].charAt(0).toLowerCase() == "d";
			var name:String = fields[8];			
			var path:String = dir;
			var size:int = parseInt(fields[4]);
			var date:String = fields[5]+" "+fields[6]+" "+fields[7];		
			return new FTPFile(name, path, size, date, isDir);
		}
		
		public static function parseFormListing (listing:String, dir:String):Array{
			var list:Array = [];
			var rawList:Array = listing.match(/^.+/gm);
				
			for(var i:int=0; i<rawList.length; i++){
				var temp:FTPFile=parseFromListEntry(rawList[i], dir);
				if(temp.name!=".."&&temp.name!=".")list.push(temp);			
			}	
			list.unshift(new FTPFile("..", "..", 0, null, true));
			return list;
		}

		public function get parentDir():String{
			var i:int=path.lastIndexOf('/');
			if(i==-1){
				return path;
			}else{
				return path.substr(i+1);
			}
		}
	}
}