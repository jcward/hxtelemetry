package amf.io;

import amf.Types;

class AmfDeserializer {
	private var amf3Reader: Amf3Reader;
	//this flag shows whether the format of incoming package is AMF3 or AMF0
	public var objectEncoding: AmfVersion; 
	public var bodies: List<AmfBody>;
	public var bodiesCount: Int;
	private var input: haxe.io.Input;
	
	public function new(i: haxe.io.Input) {
		bodiesCount = 0;
		bodies = new List<AmfBody>();
		input = i;
		amf3Reader = new Amf3Reader(i);
	}
	
	public function readAmfBody(): AmfBody {
		//encoded path, somting like Object.Object2...ObjectN.methodToCall
		var fun = readString();	
		//client resonse
		var response = readString();
		//the total length of the encoded params array
		Std.int(input.readInt32());		
		
		var data = new Array<Dynamic>();
		data = readData();	
		
		return {
			name: fun,
			data: data,		
			clientResponse: response,
		};
	}
	
	/**
	 * reading the quantity of amf bodies and amf version
	 */
	public function startReading() {
		input.readByte();
		//the second byte is version 0x00 - AMF0, 0x03 - AMF3
		objectEncoding = (input.readByte() == 0) ? AmfVersion.AMF0 : AmfVersion.AMF3;
		//the quantity of incoming headers always 0
		input.readUInt16();
		bodiesCount = input.readUInt16();
	}
	
	private function readData(): Dynamic {
		var amf = new Amf0();
		var ret = amf.read(input);
		return ret;
	}
	
	private function readString() {
		var length = input.readUInt16();
		
		return (length == 0) ? "" : input.read(length).toString();
	}
}