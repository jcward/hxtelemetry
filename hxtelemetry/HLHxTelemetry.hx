package hxtelemetry;

#if hl

typedef StackItem = { id : Int, subs : Map<Int,StackItem> };

@:keep
@:access(hl.Profile)
class HLHxTelemetry {

	public inline static function validate_config(hxt:HxTelemetry):Void {
	}

	public inline static function start_profiler(hxt:HxTelemetry):Int {
		return 0;
	}

	public static function do_advance_frame(hxt:HxTelemetry):Void {
		disable_alloc_tracking(true);
		hxt._writer.sendMessage({"dump":true, "thread_num":hxt._thread_num});
		var stats = hl.Gc.stats();
		var gctotal = Std.int(stats.currentMemory/1024);
		var gcused = gctotal;
		if (hxt._last_gctotal != gctotal) {
			hxt._last_gctotal = gctotal;
			hxt._writer.sendMessage({"name":".mem.total","value":gctotal });
		}
		if (hxt._last_gcused != gcused) {
			hxt._last_gcused = gcused;
			hxt._writer.sendMessage({"name":".mem.used","value":gcused });
		}
		disable_alloc_tracking(false);
	}

	public inline static function disable_alloc_tracking(set_disabled:Bool):Void {
		hl.Profile.enable = !set_disabled;
	}

	static var TYPES = new hl.types.ObjectMap();
	static var SYMBOLS = new hl.types.ObjectMap();
	static var NAMES = new Map<String,Int>();
	static var NAME_ID = 1; // 1-indexed
	static var OBJ_ID = 1;  // Doesn't matter... I think ;)
	static var STACKS : StackItem = { id : 0, subs : new Map() };
	static var pendingStacks : Array<Array<Int>> = [];
	static var pendingNames : Array<String> = [];
	static var STACK_ID = 0; // 0-indexed
	static var ALLOC_DATA = haxe.io.Bytes.alloc(1024);

	static function getTypeNameIdx( t : hl.Type ) {
		var tid : Null<Int> = TYPES.get(t);
		if( tid == null ) {
			var str = Std.string(t);
			tid = getNameIdx(str);
			TYPES.set(t, tid);
		}
		return tid;
	}

	static function getNameIdx( s : String ) {
		var id = NAMES.get(s);
		if( id == null ) {
			pendingNames.push(s);
			id = NAME_ID++;
			NAMES.set(s,id);
		}
		return id;
	}

	static function getSymbolIdx( s : hl.Profile.Symbol ) {
		var sid : Null<Int> = SYMBOLS.get(s);
		if( sid == null ) {
			var str = hl.Profile.resolveSymbol(s);
			sid = getNameIdx(str);
			SYMBOLS.set(s, sid);
		}
		return sid;
	}

	static function getStackIdx( arr : hl.NativeArray<hl.Profile.Symbol> ) {
		var root = STACKS;
		for( i in 0...arr.length ) {
			var sid = getSymbolIdx(arr[i]);
			var next = root.subs[sid];
			if( next == null ) {
				next = { id : -1, subs : new Map() };
				root.subs[sid] = next;
			}
			root = next;
		}
		if( root.id < 0 ) {
			root.id = STACK_ID++;
			pendingStacks.push([for( a in arr ) getSymbolIdx(a)]);
		}
		return root.id;
	}

	public static function dump_telemetry_frame(thread_num:Int,output:haxe.io.Output,write_object:Dynamic->Void) {

		if( output == null )
			return;

		var maxDepth = 0;
		hl.Profile.track_lock(true);
		var count = hl.Profile.track_count(maxDepth);
		var w = 0;
		var arr = new hl.NativeArray<hl.Profile.Symbol>(maxDepth);
		if( count > 0 ) {
			var allocData : hl.BytesAccess<Int> = ALLOC_DATA;
			for( i in 0...count ) {
				var t : hl.Type = null, count = 0, size = 0;
				hl.Profile.track_entry(i, t, count, size, arr);
				if( count == 0 ) continue;
				if( count > 1 ) size = Math.ceil(size/count);
				var tid = getTypeNameIdx(t);
				var sid = getStackIdx(arr);
				if( ALLOC_DATA.length < (w + count * 5) * 4 ) {
					var newLen = ALLOC_DATA.length * 2;
					while( newLen < (w+count*5)*4 )
						newLen *= 2;
					var newData = haxe.io.Bytes.alloc(newLen);
					newData.blit(0, ALLOC_DATA, 0, w * 4);
					ALLOC_DATA = newData;
					allocData = ALLOC_DATA;
				}
				for( i in 0...count ) {
					allocData.set(w++,0);
					allocData.set(w++,OBJ_ID++);
					allocData.set(w++,tid);
					allocData.set(w++,size);
					allocData.set(w++,sid);
				}
			}
		}
		hl.Profile.reset();
		hl.Profile.track_lock(false);

		if( pendingNames.length > 0 ) {
			output.writeByte(10);
			output.writeInt32(pendingNames.length);
			for( n in pendingNames ) {
				output.writeInt32(n.length);
				output.writeString(n);
			}
			pendingNames = [];
		}

		if( pendingStacks.length > 0 ) {
			output.writeByte(12);
			var count = 0;
			for( s in pendingStacks )
				count += 1 + s.length;
			output.writeInt32(count);
			for( s in pendingStacks ) {
				output.writeInt32(s.length);
				for( id in s )
					output.writeInt32(id);
			}
			pendingStacks = [];
		}

		if( w > 0 ) {
			output.writeByte(13);
			output.writeInt32(w);
			var allocData : hl.BytesAccess<Int> = ALLOC_DATA;
			for( i in 0...w ) {
				var d = allocData.get(i);
				output.writeByte(d>>>24);
				output.writeByte((d>>16)&0xFF);
				output.writeByte((d>>8)&0xFF);
				output.writeByte(d&0xFF);
			}
		}

/*
		// Write samples
		if (frame->samples->size()>0) {
			output->writeByte(11);
			output->writeInt32(frame->samples->size());
			i = 0;
			size = frame->samples->size();
			while (i<size) {
			//output->writeInt32(frame->samples->at(i++));
				int d = frame->samples->at(i);
				bytes->b[(int)i*4]	 = d>>24;
				bytes->b[(int)i*4+1] = d>>16;
				bytes->b[(int)i*4+2] = d>>8;
				bytes->b[(int)i*4+3] = d;
				i++;
			}
			output->writeFullBytes(bytes, 0, size*4);
		}

		// GC time
		hx::Anon gct = hx::Anon_obj::Create();
		gct->Add(HX_CSTRING("name") , HX_CSTRING(".gc"),false);
		gct->Add(HX_CSTRING("delta") , (int)frame->gctime,false);
		gct->Add(HX_CSTRING("span") , (int)frame->gctime,false);
		write_object(gct);
*/
	}

}

#end
