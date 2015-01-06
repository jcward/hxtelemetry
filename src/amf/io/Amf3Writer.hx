 package amf.io;

import haxe.io.BytesData;
import amf.Types;
import Type;
//import neko.NativeString;
import haxe.io.Bytes;


// aux class to maintain a cache of string with fast accesses
class StringCache {
	private var strings: Map<String,Int>;
	private var nextIndex: Int;

	public function new() {
		strings = new Map<String,Int>();
		nextIndex = 0;
	}

	public function add(s: String) {
		strings.set(s, nextIndex);
		++nextIndex;
	}

	public function getIndex(s: String): Int {
		return strings.exists(s) ? strings.get(s) : -1;
	}
}

/**
* table of markers(according to AMF3 Format)
* 
* 0x00 - undefined-marker
* 0x01 - null-marker
* 0x02 - false-marker
* 0x03 - true-marker
* 0x04 - integer-marker
* 0x05 - double-marker
* 0x06 - string-marker
* 0x07 - xml-doc - marker
* 0x08 - date-marker
* 0x09 - array-marker
* 0x0A - object-marker(objects classes and hashes)
* 0x0B - xml-marker
* 0x0C - byte-array-marker 
*/
class Amf3Writer /*implements io.Writer*/ {
	
	public static var countWithoutReflect: Int = 0;
	public static var countWithReflect: Int = 0;
	
	private var output: haxe.io.Output;
	public var stringCache: StringCache; 
	
	public var references: Array<EnumPath>;
	public var currentRef: Int;
	
public static var INT28_MIN_VALUE= -268435456;
public static var INT28_MAX_VALUE = 268435455;
public static var INT29_MASK = 0x1FFFFFFF;	
	
	
	public function new(o: haxe.io.Output) {
		output = o;
		//trace(output.bigEndian);
		output.bigEndian=true;

		stringCache = new StringCache();
		
		references = [];
		currentRef = 1;
	}

	public function startWritingResult() {
		output.writeByte(0x09);
		writeAmf3Int((2 << 1) | 0x01);
		output.writeByte(0x01);
	}
	
	public function writeEnumPaths() {
		output.writeByte(0x09);
		writeAmf3Int((references.length << 1) | 0x01);
		output.writeByte(0x01);
		
		for (item in references) {
			output.writeByte(0x0A);
			output.writeByte(0x0B);
			output.writeByte(0x01);
			
			writeAmf3String("key");
			write(item.key);
			
			writeAmf3String("object");
			output.writeByte(0x0A);
			writeAmf3Int(item.objectReference << 1);
			
			output.writeByte(0x01);
		}
	}	
	
	/**
	 * @param	item = an item to find
	 * @param	array = an array to find item
	 * @return the position of item in array -1 whether there is no such element in array
	 * 
	 * mind that the method works correctly only if an array contains an item not more then one time
	 * (as it is in our case)
	 */
	private function getItemIndex(item: Dynamic, array: Array<Dynamic>): Int {
		for (i in 0...array.length) {
			if (item == array[i]) {
				return i;
			}
		}
		
		return -1;
	}
	
	/**
	 * @return true if enum was sent, otherwise false
	 */
	public function write(val: Dynamic): Bool {		
		return switch( Type.typeof(val) ) {
			case TNull:
				output.writeByte(0x01);
				false;
			case TInt: 
				//integer type is limited by 29 bits
				if (val <= INT28_MAX_VALUE && val >= INT28_MIN_VALUE) {
					//if val is negative int29 we need to make that int 29-based instead of 31-based (otherwise it'll be 
					//recognized big positive number on client) 
					val = val & INT29_MASK;
					
					output.writeByte(0x04);
					writeAmf3Int(val);
				} else {
					output.writeByte(0x05);
					output.writeDouble(val);
				}
				false;
			case TFloat:
				output.writeByte(0x05);
				output.writeDouble(val);
				false;
			case TBool: 
				if (val) {
					output.writeByte(0x03);
				} else {
					output.writeByte(0x02);
				}
				false;
			case TObject: 
				writeAmf3Object(val);		
				false;
			case TEnum(e):
				var result = {};
				Reflect.setField(result, "index", Type.enumIndex(val));
				//enum constructor
				Reflect.setField(result, "tag", Type.enumConstructor(val));
				//list of the parameters for the constructor
				Reflect.setField(result, "params", Type.enumParameters(val));
				//finally, enum name
				Reflect.setField(result, "name", Type.getEnumName(Type.getEnum(val)));
				Reflect.setField(result, "isEnum", "__true__");
				
				writeAmf3Object(result);
				true;
			case TClass(c):
				if (c == cast String) {
					output.writeByte(0x06);
					writeAmf3String(val);
				} else if (c == cast Array) {
					output.writeByte(0x09);
					writeAmf3Array(val);
				} else if (c == cast haxe.io.Bytes) {
          trace("TODO: fix Amf3Writer, needs separate byte cache from string cache");
					output.writeByte(0x0C);
					writeAmf3StringData(val);
				} else if (c == cast Date) {
					writeAmf3Date(val);				
				} else {
					throw "Can't encode instance of " + Type.getClassName(c);
				}
				false;
			default:
				throw "Can't encode " + Std.string(val);
				false;
		}		
	}
	
	private function writeAmf3Int(v: Int) {
		var cur = v;
		
		if (cur < 0x80) {
			output.writeByte(cur & 0xFF);
		} else if (cur < 0x4000) {
			output.writeByte((cur >> 7) & 0x7F | 0x80);
			output.writeByte(cur & 0x7F);
		} else if (cur < 0x200000) {
			output.writeByte((cur >> 14) & 0x7F | 0x80);
			output.writeByte((cur >> 7) & 0x7F | 0x80);
			output.writeByte(cur & 0x7F);
		} else {
			output.writeByte((cur >> 22) & 0x7F | 0x80);
			output.writeByte((cur >> 15) & 0x7F | 0x80);
			output.writeByte((cur >> 8) & 0x7F | 0x80);
			output.writeByte(cur & 0xFF);
		}
	}
	
	private function writeAmf3String(str: String) {
		if (str == "") {
			//length of str = 0
			output.writeByte(0x01);
		} else {
			var index = stringCache.getIndex(str); 
			
			if (index == -1) {
				
				//writeAmf3StringData(Bytes.ofData(neko.NativeString.ofString(str)));				
				//writeAmf3StringData(Bytes.ofData(BytesData.ofString(str)));
				writeAmf3StringData(Bytes.ofString(str));
				
				stringCache.add(str); 
			} else {
				var handle = index << 1;
				writeAmf3Int(handle);
			}
		}
	}

	private function writeAmf3Date(date: Date) {
		output.writeByte(0x08);
		writeAmf3Int(1);
		output.writeDouble(date.getTime());
	}

	private function writeAmf3StringData(data: Bytes) {
		var handle = (data.length << 1) | 0x01;
		writeAmf3Int(handle);
		output.write(data);
	}

	public function writeObjectHeader(): Int {
		//marking that an Object is encoded
		output.writeByte(0x0A);
		//object definition
		output.writeByte(0x0B);
		output.writeByte(0x01);
		return currentRef++;
	}
	
	public function writeObjectFooter() {
		//marking the end of an object with key ""
		output.writeByte(0x01);
	}

	/**
	 * cyclic reference is disabled
	 */
	private function writeAmf3Object(val: Dynamic, ?writeFields: Dynamic -> Dynamic /*io.Writer*/ -> Int -> Void) {
		var ind: Int = writeObjectHeader();
				
		if (null != writeFields) {
			writeFields(val, this, ind);
		} else if (null != val.__writeFieldsToAmf3) {
			val.__writeFieldsToAmf3(val, this, ind);
		} else {
			for (f in Reflect.fields(val)) {
				writeObjectField(f, Reflect.field(val, f), ind);
			}
		}
		writeObjectFooter();
	}
	
	
	public function writeArrayHeader(array: Array<Dynamic>, ?withMark: Bool): Int {
		if (null != withMark && true == withMark) {
			output.writeByte(0x09);
		}
		
		//reference
		writeAmf3Int((array.length << 1) | 0x01);
		/*
		 * here should be a list of keys and values but in our case they are not significant
		 * to mark it null marker should be writen
		 */ 
		output.writeByte(0x01);
		
		return currentRef++;
	}

	/**
	 * Circular referencing is disabled in arrays
	 */
	private function writeAmf3Array(array: Array<Dynamic>, ?writeItem: Dynamic -> Dynamic /*io.Writer*/ -> Bool) {
		var ind = writeArrayHeader(array);
		
		var item;
		for (i in 0...array.length) {
			item = array[i];
			var isEnum = if (null != writeItem) writeItem(item, this) else write(item);
			
			if (isEnum) {
				references.push({objectReference: ind, key: i});
			}
		}
	}
	
	//------------------------------------------------------------
	// io.Writer interface
	//------------------------------------------------------------
	
	
	public function writeInt(val: Null<Int>) {
		if (null != val) {
			if (val & 0x0e000000 == 0) {
				output.writeByte(0x04);
				writeAmf3Int(val);
			} else {
				output.writeByte(0x05);
				output.writeDouble(val);
			}
		} else {
			writeNull();
		}
	}

	public function writeFloat(val: Null<Float>) {
		if (null != val) {
			output.writeByte(0x05);
			output.writeDouble(val);
		} else {
			writeNull();
		}
	}
	
	public function writeString(val: Null<String>) {
		if (null != val) {
			output.writeByte(0x06);
			writeAmf3String(val);
		} else {
			writeNull();
		}
	}
	
	
	public function writeObject(val: Dynamic, writeFields: Dynamic -> Dynamic /*io.Writer*/ -> Int -> Void) {
		if (null != val) {
			writeAmf3Object(val, writeFields);
		} else {
			writeNull();
		}
	}

	public function writeEnum(val: Dynamic, ind: Int, key: Int) {
		if (null != val) {
				var result = {};
				Reflect.setField(result, "index", Type.enumIndex(val));
				//enum constructor
				Reflect.setField(result, "tag", Type.enumConstructor(val));
				//list of the parameters for the constructor
				Reflect.setField(result, "params", Type.enumParameters(val));
				Reflect.setField(result, "name", Type.getEnumName(Type.getEnum(val)));			
				Reflect.setField(result, "isEnum", "__true__");
				
				writeAmf3Object(result);
				references.push({objectReference: ind, key: key});
		} else {
			writeNull();
		}
	}
	
	public function writeObjectFieldHeader(name: String) {
		writeAmf3String(name);
	}
	
	public function writeObjectField(name: String, value: Dynamic, currentRef: Int, ?writeValue: Dynamic -> Bool) {
		writeAmf3String(name);
		var isEnum = if (null != writeValue) writeValue(value) else write(value);
		
		if (isEnum) {
			references.push({objectReference: currentRef, key: name});
		}	
	}
	
	public function writeArray(val: Array <Dynamic>, writeItem: Dynamic -> Dynamic /*io.Writer*/ -> Bool) {
		if (null != val) {
			output.writeByte(0x09);
			writeAmf3Array(val, writeItem);
		} else {
			writeNull();
		}
	}
	
	public function writeNull() {
		output.writeByte(0x01);
	}
	
}
