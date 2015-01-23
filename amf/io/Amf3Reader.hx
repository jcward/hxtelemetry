package amf.io;

import haxe.io.Bytes;
import haxe.io.BytesData;
import amf.Types;
//import neko.NativeString;


class Amf3Reader {	
	public var decodedBytes: Array<String>;
	public var decodedStrings: Array<String>;
	public var decodedObjects: Array<Dynamic>;
	public var decodedClassDefs: Array<ClassDef>;
	private var input: haxe.io.Input;
	
	public function new(i: haxe.io.Input) {
		input = i;
		input.bigEndian = true;
    decodedBytes = [];
		decodedStrings = [];
		decodedObjects = [];
		decodedClassDefs = [];
	}
	
	private function readWithCode(marker: Int): Dynamic {
    //trace("marker = "+marker);
		return switch (marker) {
			case 0x00: cast null;
			case 0x01: cast null;
			case 0x02: cast false;
			case 0x03: cast true;
			case 0x04: cast readAmf3Int();
			case 0x05: cast input.readDouble();
			case 0x06: cast readAmf3String();
			case 0x08: cast readAmf3Date();
			case 0x09: cast readAmf3Array();
			case 0x0A: cast readAmf3Object();
			case 0x0C: cast readAmf3ByteArray();
    case 0x0D,0xE,0xF,0x10: cast readAmf3Vector(marker);
    default: throw "Not supported or wrong amf type-marker: "+marker;
        //+" at "+cast(input, sys.io.FileInput).tell();
        //Type.getClass(cast(input));
		}
	}

  function readAmf3Vector(vector_type):Dynamic {
    var type = readAmf3Int();
    var is_reference = (type & 0x01) == 0;
    if (is_reference) {
      var reference = type >> 1;
      return decodedObjects[reference];
    } else {
      var vec:Array<Dynamic> = [];
      decodedObjects.push(vec);
      var length = type >> 1;
      var fixed_vector = input.readByte(); // Ignore
      switch( vector_type) {
        case 0xD: // AMF3_VECTOR_INT_MARKER
          for (i in 0...length) {
            vec.push(input.readInt32());
          }
        case 0xE: //AMF3_VECTOR_UINT_MARKER
          for (i in 0...length) {
						vec.push(cast(input.readInt32(), Int));
          }
        case 0xF: // AMF3_VECTOR_DOUBLE_MARKER
          for (i in 0...length) {
						vec.push(input.readDouble());
          }
        case 0x10: //AMF3_VECTOR_OBJECT_MARKER
					var vector_class = readAmf3String(); // Ignore
          for (i in 0...length) {
						vec.push(read());
          }
      }
      return vec;
    }
  }

	private function readAmf3ByteArray() {
		var data = readAmf3String(decodedBytes);
		//return Bytes.ofData(BytesData.ofString(data));
		return Bytes.ofString(data);
		//return haxe.io.Bytes.ofData(NativeString.ofString(data));
	}

	private function readAmf3Date(): Date {
		var flag = readAmf3Int();
    //trace(" -- reading int");
		return flag & 1 == 0 ? Date.fromTime(input.readDouble())
			: cast decodedObjects[flag >> 1];
	}

	/**
	 * a String is encoded in UTF format
	 */
	private function readAmf3String(cache:Array<String>=null): String {
		var strref = readAmf3Int();
		if (cache==null) cache = decodedStrings;

		var result = "";
		if (strref & 0x01 == 0) {
			strref = strref >> 1;
			
			if (strref >= cache.length) {
				throw "Undefined String reference";
			}

		
			result = cache[strref];
		} else {
			var length = strref >> 1;
			
			if (length > 0) {
				result = input.read(length).toString();
				cache.push(result);
			}
		}

    //if (result.indexOf(String.fromCharCode(0))>=0) {
    //  var bytes = haxe.io.Bytes.ofString(result);
		//  var msg = "";
		//  for (i in 0...bytes.length) {
		//  	var b = bytes.get(i);
		//  	if (b>=32 && b<=126) msg += String.fromCharCode(b); else msg += "%"+StringTools.hex(b, 2);
		//  }
    //  trace(" -- reading NTString: "+msg);
		//}

		return result;
	}

	/**
	 * an Int is encoded in U29 format
	 */
	private function readAmf3Int(): Int {
		var char = input.readByte();
		
		if (char & 0x80 == 0x00) {
			return char;
		}
		
		var result = char & 0x7F;
		char = input.readByte();
		
		if (char & 0x80 == 0x00) {
			return (result << 7) | (char & 0x7F);
		}
		
		result = ((result << 7) | (char & 0x7F));
		char = input.readByte();
		
		if (char & 0x80 == 0x00) {
			return (result << 7) | (char & 0x7F);
		}
		
		result = ((result << 7) | (char & 0x7F));
		char = input.readByte();		
		result = (result << 8) | char;
		
		if (result & 0x10000000 != 0) {
			//result is negative number, but it's 29-bit negative number. To make it 32-bit negative we need to put three '1' before result
			result |= 0xe0000000;
		}
		
		return result;
	}
	
	private function readAmf3Array(): Array<Dynamic> {
		var result: Array<Dynamic> = [];

    //trace(" -- reading array...");
		
		var handle = readAmf3Int();
		var isStored = (handle & 0x01) == 0;
		handle = handle >> 1;
		
		var index = decodedObjects.length;
		decodedObjects.push(null);
		
		/*
		 * if isStored is true the same array was decoded earlier so this 
		 * should be found in StoredObjects array
		 */
		if (!isStored) {
			//here should be some key it's significent only if it's not null... But fortunately that's not our case
			input.readByte();
			
			for (i in 0...handle) {
				result.push(read());
			}
			
			//decodedObjects.push(result);
			decodedObjects[index] = result;
		} else {
			result = decodedObjects[handle];
		}
		
		return result;
	}
	
	/**
	 * TODO: the method needs to be developed to be able to decode an instance of a class
	 */
	// private function __obsolete_readAmf3Object(): Dynamic {		
  //  
  //   //trace(" -- reading object...");
  //  
	//   var handle = readAmf3Int();
	//   //if false the same object vas decoded earlier so it's to be found in decodedObjects array
	//   var decodingNeeded = ((handle & 1) != 0);
	//   handle = handle >> 1;
  //  
  //   //trace(" ... decoding needed? "+decodingNeeded);
	//   
	//   var classDef;
	//   if (decodingNeeded) {
	//   	//indicating whether the classDef was decoded earlier
	//   	var inlineClassDef = ((handle & 1) != 0 );
	//   	
	//   	if (inlineClassDef) {
	//   		//type is always "" as we are decoding only objects
	//   		var type = readAmf3String();
	//   		var typedObject = ((type != null) && (type != ""));
	//   		//flags that identify the way the object was serialized 
	//   		var externalizable = ((handle & 1) != 0 ); 
	//   		handle = handle >> 1;
	//   		var dyn = ((handle & 1) != 0 ); 
	//   		handle = handle >> 2;
	//   		/*
	//   		 * handle is showing the quantity of Class members.
  //          While implemening the decoding of classes
	//   		 * use this var. In case of objects handle should be 0
	//   		 */ 
  //  
  //       //trace(" :: inlineClassDef...  # members="+handle);
  //  
  //       var members = [];
  //       for (i in 0...handle) {
  //         members.push(readAmf3String());
  //       }
	//   		
	//   		var type = (dyn) ? ClassType.Dyn : ClassType.Exteralizable;
	//   		classDef = {typedObject: typedObject, type: type, members:members};
	//   		decodedClassDefs.push(classDef);
	//   	} else {
	//   		classDef = decodedClassDefs[handle];
	//   	}
	//   } else {
	//   	var result = decodedObjects[handle];
	//   	
	//   	if (Reflect.field(result, "isEnum") == "__true__") {
	//   		result = makeEnumFromObject(result);
	//   	}
	//   	
	//   	return result;
	//   }
	//   
	//   var index = decodedObjects.length;
	//   decodedObjects.push(null);		
	//   
	//   var result = {};
	//   
	//   //object
	//   if (classDef!=null && classDef.type!=ClassType.Exteralizable) { //(!classDef.typedObject) {
	//   	for (i in 0...classDef.members.length) {
  //       var key = classDef.members[i];
  //       //the decoded object ends with key ""
  //       if (key != "" && key != null) {
  //         var value = read();
  //         //result.set(key, value);
  //         Reflect.setField(result, key, value);
  //       }
  //     }
	//   }	
	//   decodedObjects[index] = result;
	//   
	//   if (Reflect.field(result, "isEnum") == "__true__") {
	//   	result = makeEnumFromObject(result);
	//   }
	//   
	//   return result;
	// }

	private function readAmf3Object(): Dynamic {		
		var type = readAmf3Int();
		var is_reference = ((type & 1) == 0);

    if (is_reference) {
      // instance reference
      var reference = type >> 1;
      var result = decodedObjects[reference];
			
			if (Reflect.field(result, "isEnum") == "__true__") {
				result = makeEnumFromObject(result);
			}
			
			return result;

    } else {
      var class_type = type >> 1;
      var class_is_reference = (class_type & 0x01) == 0;
      var traits;

      if (class_is_reference) { // type reference
        var reference = class_type >> 1;
        traits = decodedClassDefs[reference];
      } else {
        var externalizable = (class_type & 0x02) != 0;
        var dyn = (class_type & 0x04) != 0;
        var attribute_count = class_type >> 3;
        var class_name = readAmf3String();

        //trace(" -- read "+(externalizable?'':'non-')+"externalizable class name: "+class_name+" with attrib count "+attribute_count);

        var class_attributes = [];
        for (i in 0...attribute_count) { class_attributes.push(readAmf3String()); } // Read class members
        //trace(" -- attribs: "+class_attributes);

        traits = {
          "class_name" : class_name,
          "members" : class_attributes,
					"externalizable" : externalizable,
					"dyn" : dyn
        };
        decodedClassDefs.push(traits);
      }

      // # Optimization for deserializing ArrayCollection
			// if traits[:class_name] == "flex.messaging.io.ArrayCollection"
			//	 arr = amf3_deserialize # Adds ArrayCollection array to object cache
			//	 $object_cache << arr # Add again for ArrayCollection source array
			//	 return arr
			// end

      var obj = new Map<String, Dynamic>(); // $class_mapper.get_ruby_obj traits[:class_name]
      decodedObjects.push(obj);

      if (traits.externalizable) {
        // obj.read_external(/* self */);
        throw "Error! TODO: how to handle externalizable objects?";
      } else {
        obj = deepCopy(obj);

        for (i in 0...traits.members.length) {
          var key:String = traits.members[i];
          obj[key] = read();
        }

        if (traits.dyn) {
          var key = readAmf3String();
          while (key.length != 0) { // read next key
            obj[key] = read();
            key = readAmf3String();
          }
        }
      }

      return obj;
    }
  }

  /** 
    deep copy of anything 
   **/ 
  public static function deepCopy<T>( v:T ) : T 
  { 
    if (!Reflect.isObject(v)) // simple type 
    { 
      return v; 
    } 
    else if( Std.is( v, Array ) ) // array 
    { 
      var r = Type.createInstance(Type.getClass(v), []); 
      untyped 
      { 
    for( ii in 0...v.length ) 
      r.push(deepCopy(v[ii])); 
      } 
      return r; 
    } 
    else if( Type.getClass(v) == null ) // anonymous object 
    { 
      var obj : Dynamic = {}; 
    for( ff in Reflect.fields(v) ) 
      Reflect.setField(obj, ff, deepCopy(Reflect.field(v, ff))); 
      return obj; 
    } 
    else // class 
    { 
      var obj = Type.createEmptyInstance(Type.getClass(v)); 
    for( ff in Reflect.fields(v) ) 
      Reflect.setField(obj, ff, deepCopy(Reflect.field(v, ff))); 
      return obj; 
    } 
    return null; 
  } 
	
	public function read(): Dynamic {
		return readWithCode(input.readByte());
	}
	
	/**
	* Enums are sent as objects this method is aimed to decode recived enums
	*/
	private static function makeEnumFromObject(arg: Dynamic): Dynamic {
    //trace(" ... makeEnum");
		var tag = Std.string(Reflect.field(arg, "tag"));
		var name = Std.string(Reflect.field(arg, "name"));
			
		var edecl = Type.resolveEnum(name);
		if(edecl == null)
			throw "Error! Enum: " + name + " not found!";
		
		var constructor = Reflect.field(edecl, tag);
		
		return (Reflect.isFunction(constructor)) ? Reflect.callMethod(edecl, constructor, Reflect.field(arg, "params")) : constructor;	
	}	
}