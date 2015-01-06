package amf;

import amf.io.AmfDeserializer;
import amf.io.AmfSerializer;
import amf.Types;
import RequestHandler;
import BasicRequestHandler;

/**
 * see documentation on amf format:
 * 
 * http://download.macromedia.com/pub/labs/amf/amf3_spec_121207.pdf
 * http://download.macromedia.com/pub/labs/amf/amf0_spec_121207.pdf 
 * http://osflash.org/documentation/amf 
 */
class AmfHandler extends BasicRequestHandler {
	private var objectEncoding: AmfVersion;
	private var serializer: AmfSerializer;
	private var deserializer: AmfDeserializer;

	private var delayedHeader: Bool;
	
	//client response of the processing amf body
	private var currentClientResponse: String;
	//the offset of current amf body
	private var currentBody: Int;
	private var bodiesQuantity: Int;
	
	// lazy mode allows to write cookies while processing first request
	public override function new(lazyMode: Bool) {
		super();
		delayedHeader = lazyMode;
	}
	
	public override function checkRequest(): Bool {
		return neko.Web.getClientHeader("Content-Type") == "application/x-amf"; 
	}

	public override function startResponse(): Void {
		serializer = new AmfSerializer(objectEncoding);
		// sometimes we might want to delay writing the header until the first response is being sent
		// to allow setting cookies while processing request for instance
		if (!delayedHeader) {
			neko.Web.setHeader("Content-Type", "application/x-amf");
			serializer.writeHeading(bodiesQuantity);
		}
	}

	public override function finishResponse(): Void {
		//all data has been already sent so it's nothing to do here
	}
	
	public override function encodeError(error: Dynamic): Void {
		// sending the header if we haven't done it
		if (delayedHeader) {
			neko.Web.setHeader("Content-Type", "application/x-amf");
			serializer.writeHeading(bodiesQuantity);
			delayedHeader = false;
		}

		serializer.writeAmfBody({result: error, clientResponse: currentClientResponse}, "/onStatus", true);
	}
	
	public override function encodeResponseEntry(response: Dynamic): Void {	
		// sending the header if we haven't done it
		if (delayedHeader) {
			serializer.writeHeading(bodiesQuantity);
			delayedHeader = false;
		}

		serializer.writeAmfBody({result: response, clientResponse: currentClientResponse}, "/onResult", false);
	}
	
	public override function hasNext(): Bool {
		return (currentBody < bodiesQuantity);
	}
	
	public override function next(): RequestData {
		currentBody++;
		var body = deserializer.readAmfBody();
		currentClientResponse = body.clientResponse;
		
		return {path: body.name.split("."), args: body.data};
	}
	
	public override function initRequest(): Void {
		//getting an amf package
		var messageBody = neko.Web.getPostData();
		
		var input = new haxe.io.BytesInput(haxe.io.Bytes.ofString(messageBody));
		input.bigEndian = true;
		deserializer = new AmfDeserializer(input);		
		deserializer.startReading();
		
		objectEncoding = deserializer.objectEncoding;
		currentBody = 0;
		bodiesQuantity = deserializer.bodiesCount;
	}
}