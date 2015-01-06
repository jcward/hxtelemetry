package amf.io;

import amf.Types;

/**
* 
* this class is reader and writer for Amf0 fomat at one time
* 
* Table of markers (AMF0 format):
* 
* 0x00 - marker for Number type(Ints and Float)
* 0x01 - boolean marker
* 0x02 - string marker
* 0x03 - object marker
* 0x05 - null marker
* 0x06 - undefined
* 0x0A - array
* 0x0C - longString
* 
* TODO: not all amf-types are implemented
*/
class Amf0 {
	public var decodedObjects: Array<Dynamic>;
	public var references: Array<EnumPath>;
	public var currentRef: Int;
	
	public function new() {
		decodedObjects = [];
		references = [];
		currentRef = 1;
	}
	
	public function startWritingResult(output: haxe.io.Output) {
		output.writeByte(0x0A);
		output.writeInt32(Std.int(2));
	}
	
	public function writeEnumPaths(output: haxe.io.Output) {
		output.writeByte(0x0A);
		output.writeInt32(Std.int(references.length));
		
		for (item in references) {
			output.writeByte(0x03);
			
			output.writeUInt16(3);
			output.write(haxe.io.Bytes.ofString("key"));
			write(output, item.key);
			
			output.writeUInt16(6);
			output.write(haxe.io.Bytes.ofString("object"));
			output.writeByte(0x07);
			output.writeUInt16(item.objectReference);
			
			output.writeUInt16(0x0000);
			output.writeByte(0x09);
		}
	}
	
	public function writeAmf0String(output: haxe.io.Output, str: String) {
		if (str.length < 0xFFFF) {
			//string-type marker
			output.writeByte(0x02);
			output.writeUInt16(str.length);
			output.write(haxe.io.Bytes.ofString(str));
		} else {
			//long-string-type marker
			output.writeByte(0x0C);
			output.writeInt32(Std.int(str.length));
			output.write(haxe.io.Bytes.ofString(str));					
		}		
	}
	
	public function readWithCode(input: haxe.io.Input, id: Int): Dynamic {	
		return switch(id) {
		case 0x00:
			cast input.readDouble();
		case 0x01: 
			cast switch(input.readByte()) {
					case 0: false;
					case 1: true;
					default: throw "Invalid AMF(encoded Bool is not 1 or 0)";
				}
		case 0x02:
			cast input.read(input.readUInt16()).toString();
		case 0x03:
			readAmf0Object(input);
		case 0x05:
			cast null;
		case 0x06:
			cast null;
		case 0x07:
			var ind = input.readUInt16();
			
			if (ind >= decodedObjects.length)
				throw "Undefined reference";
			
			decodedObjects[ind];
		case 0x0A:
			var length = Std.int(input.readInt32());
			var result: Array<Dynamic> = [];
			//index of current array in the decodedObjects
			var ind = decodedObjects.length;
			//we need to push something to increase the length of an array 
			decodedObjects.push(null);
			
			for (j in 0...length) {
				result.push(read(input));
			}
			
			decodedObjects[ind] = result;
			cast result;
		case 0x0B: // date
			var result = Date.fromTime(input.readDouble());
			input.readInt16(); // skip timezone
			cast result;
		case 0x0C:
			cast input.read(Std.int(input.readInt32()));
		//AMF3 value
		case 0x11:
			var reader = new Amf3Reader(input);
			var result = reader.read();	
			cast result;
		default:
			throw "Unknown AMF " + id;
		}
	}
	
	private function readAmf0Object(input: haxe.io.Input): Dynamic {
		var result = {};
		var ind = decodedObjects.length;
		/*
		 * if there are some object inside this one they will be plased into the decodedObjects array
		 * earlier, this is incorrect. null is needed just to hold the place
		 */ 
		decodedObjects.push(null);
		
		while (true) {
			var name = input.read(input.readUInt16()).toString();
			var marker = input.readByte();
			
			//end of object marker
			if (marker == 0x09) {
				break;
			}
			
			Reflect.setField(result, name, readWithCode(input, marker));
		}
		
		if (Reflect.field(result, "isEnum") == "__true__") {
			result = makeEnumFromObject(result);
		}
		
		decodedObjects[ind] = result;
		return result;		
	}

	public function read(input: haxe.io.Input): Dynamic {
		return readWithCode(input,input.readByte());
	}	
	
	private function writeAmf0Object(output: haxe.io.Output, arg: Dynamic) {
		//Object-type marker
		output.writeByte(0x03);
		
		var ind: Int = currentRef;
		currentRef++;
		
		for (f in Reflect.fields(arg)) {
			output.writeUInt16(f.length);
			output.write(haxe.io.Bytes.ofString(f));
			
			var isEnum = write(output, Reflect.field(arg, f));
			
			if (isEnum) {
				references.push({objectReference: ind, key: f});
			}			
		}
		
		//empty string
		output.writeUInt16(0);
		//object end marker
		output.writeByte(0x09);		
	}	
	
	/**
	 * @return true if enum was writen, false in any other case
	 */
	public function write(output: haxe.io.Output, v: Dynamic): Bool {
		return switch(Type.typeof(v)) {
		case TNull:
			output.writeByte(0x05);
			false;
		case TInt, TFloat: 
			output.writeByte(0x00);
			output.writeDouble(v);
			false;
		case TBool:
			output.writeByte(0x01);
			output.writeByte(if (v) 1 else 0);
			false;
		case TObject:
			writeAmf0Object(output, v);
			false;
		case TEnum(e):
			var obj = {};
			
			Reflect.setField(obj, "index", Type.enumIndex(v));
			Reflect.setField(obj, "tag", Type.enumConstructor(v));
			Reflect.setField(obj, "params", Type.enumParameters(v));
			Reflect.setField(obj, "name", Type.getEnumName(Type.getEnum(v)));
			Reflect.setField(obj, "isEnum", "__true__");
			
			writeAmf0Object(output, obj);
			true;
		case TClass(c):
			if (c == cast String) {
				this.writeAmf0String(output, v);
			} else if (c == cast Array) {
				var copy: Array<Dynamic> = v;
				
				var ind: Int = currentRef;
				currentRef++;				
				
				output.writeByte(0x0A);
				output.writeInt32(Std.int(copy.length));				
				
				//for (item in copy) {
				for (i in 0...copy.length) {
					var isEnum = write(output, copy[i]);
					
					if (isEnum) {
						references.push({objectReference: ind, key: i});
					}		
				}
			} else if (c == cast Date) {
				output.writeByte(0x0B);
				output.writeDouble(v.getTime());
				output.writeInt16(0);
			} else {	
				throw "Can't encode instance of " + Type.getClassName(c);
			}
			
			false;
		default:
			throw "Can't encode " + Std.string(v);
			false;
		}
	}
	
	/**
	* Enums are sent as objects this method is aimed to decode recived enums
	*/
	private function makeEnumFromObject(arg: Dynamic): Dynamic {
		var tag = Std.string(Reflect.field(arg, "tag"));
		var name = Std.string(Reflect.field(arg, "name"));
			
		var edecl = Type.resolveEnum(name);
		if(edecl == null)
			throw "Enum: " + name + " not found!";
		
		var constructor = Reflect.field(edecl, tag);
		
		return (Reflect.isFunction(constructor)) ? Reflect.callMethod(edecl, constructor, Reflect.field(arg, "params")) : constructor;	
	}
	
}