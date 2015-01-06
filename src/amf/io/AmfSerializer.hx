package amf.io;

import amf.AmfHandler;
import amf.Types;

class AmfSerializer {
	public var objectEncoding: AmfVersion;
	private var output: haxe.io.Output;
	
	public function new(version: AmfVersion) {
		objectEncoding = version;
		output = new io.ResponseOutput();
		output.bigEndian = true;
	}
	
	/**
	 * writing version, quantity of outgoing headers and bodies 
	 */
	public function writeHeading(outgoingBodiesQuantity: Int) {
		//amf version(AMF0)
		output.writeUInt16(0x0000);
		//outgoing headers quantity
		output.writeUInt16(0x0000);
		output.writeUInt16(outgoingBodiesQuantity);
	}
	
	/**
	 * resulIndex is string, onResult if everything is OK, onStatus if an exception
	 * was thrown.
	 */
	public function writeAmfBody(result: AmfResult, resultIndex: String, error: Bool) {
		writeString(result.clientResponse + resultIndex);
		//this string is not significant but the format requiers it's presence
		writeString("null");
			
		var curBuffer = new haxe.io.BytesOutput();
		curBuffer.bigEndian = true;
		writeData(curBuffer, result.result, error);
		var str: String = curBuffer.getBytes().toString();
			
		//writing the length of the encoded data
		output.writeInt32(haxe.Int32.ofInt(str.length));
		//writing encoded data
		output.write(haxe.io.Bytes.ofString(str));		
	}
	
	private function writeData(output: haxe.io.Output, arg: Dynamic, error) {
		switch (objectEncoding) {
			case AMF0:
				var amf = new Amf0();
				// if an error occured there is no need to wrap the package into an additional array
				if (!error) {
					amf.startWritingResult(output);
				}
					
				var ind = amf.write(output, arg);
				
				if (!error) {
					//if arg is enum
					if (ind) {
						amf.references.push({objectReference: 1, key: null});
					}
					
					amf.writeEnumPaths(output);
				}
			case AMF3:
				var writer = new Amf3Writer(output);
				//type-marker AMF3 data
				output.writeByte(0x11);
				
				// if an error occured there is no need to wrap the package into an additional array
				if (!error) {
					writer.startWritingResult();
				}
					
				var ind = writer.write(arg);
				
				if (!error) {
					//if arg is enum
					if (ind) {
						writer.references.push({objectReference: 1, key: null});
					}
					
					writer.writeEnumPaths();
				}
			default: throw "Not supported version of AMF";
		}
	}
	
	private function writeString(str: String) {
		var utf8Str = neko.Utf8.encode(str);
		
		output.writeUInt16(utf8Str.length);
		output.write(haxe.io.Bytes.ofString(utf8Str));
	}
}