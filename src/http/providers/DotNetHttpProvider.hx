package http.providers;

#if cs
import cs.NativeArray;
import cs.system.text.Encoding;
import cs.types.UInt8;
import haxe.Json;
import haxe.io.Bytes;
import promises.Promise;
import sys.thread.Deque;
import sys.thread.Thread;

// .NET's client, written by hand so both Haxe's C# target and hxc bind it.
@:native("System.Threading.Tasks.Task`1")
private extern class NetTask<T> {
    var Result(default, never):T;
}

@:native("System.Func`5")
private extern class NetFunc5<A, B, C, D, R> {}

@:native("System.Net.Http.HttpMethod")
private extern class NetMethod {
    @:overload function new(method:String);
}

@:native("System.Net.Http.HttpContent")
private extern class NetContent {
    @:overload function ReadAsByteArrayAsync():NetTask<NativeArray<UInt8>>;
}

@:native("System.Net.Http.StringContent")
private extern class NetStringContent extends NetContent {
    @:overload function new(content:String, encoding:Encoding, mediaType:String);
}

@:native("System.Net.Http.Headers.HttpHeaders")
private extern class NetHeaders {
    @:overload function TryAddWithoutValidation(name:String, value:String):Bool;
}

@:native("System.Net.Http.Headers.HttpRequestHeaders")
private extern class NetRequestHeaders extends NetHeaders {}

@:native("System.Net.Http.HttpRequestMessage")
private extern class NetRequest {
    @:overload function new(method:NetMethod, requestUri:String);
    var Content:NetContent;
    var Headers(default, never):NetRequestHeaders;
}

@:native("System.Net.HttpStatusCode")
private extern enum NetStatus {}

@:native("System.Net.Http.HttpResponseMessage")
private extern class NetResponse {
    var StatusCode(default, never):NetStatus;
    var Content(default, never):NetContent;
    function Dispose():Void;
}

@:native("System.Security.Cryptography.X509Certificates.X509Certificate2")
private extern class NetCertificate {}

@:native("System.Security.Cryptography.X509Certificates.X509Chain")
private extern class NetChain {}

@:native("System.Net.Security.SslPolicyErrors")
private extern enum NetPolicyErrors {}

@:native("System.Net.Http.HttpMessageHandler")
private extern class NetMessageHandler {}

@:native("System.Net.Http.HttpClientHandler")
private extern class NetClientHandler extends NetMessageHandler {
    function new();
    var ServerCertificateCustomValidationCallback:NetFunc5<NetRequest, NetCertificate, NetChain, NetPolicyErrors, Bool>;
    static var DangerousAcceptAnyServerCertificateValidator(default, never):NetFunc5<NetRequest, NetCertificate, NetChain, NetPolicyErrors, Bool>;
}

@:native("System.Net.Http.HttpClient")
private extern class NetClient {
    @:overload function new(handler:NetMessageHandler);
    @:overload function Send(request:NetRequest):NetResponse;
}

/**
 * HttpClient's provider on C#, where the default one can't do https, as Haxe's C# target has no TLS
 * sockets. A body is a String, or something that can be turned into one; Bytes are refused. Redirects
 * are followed by .NET, whatever `followRedirects` says, and responses don't carry their headers.
 * Promises settle on the thread that polls haxe.Timer, the UI thread in a HaxeUI app.
 */
class DotNetHttpProvider implements IHttpProvider {
    public var encodeUrl:Bool = true;

    private var client:NetClient;
    private var clientVerifies:Bool;

    private static var completed = new Deque<Void->Void>();
    private static var inFlight = 0;
    private static var pump:haxe.Timer;

    public function new() {
    }

    public function makeRequest(request:HttpRequest):Promise<HttpResponse> {
        return new Promise((resolve, reject) -> {
            var client = currentClient();
            inFlight++;
            startPump();
            Thread.create(function() {
                try {
                    var response = send(client, request);
                    var status = response.httpStatus;
                    // As the default provider decides it: sys.Http calls below 200 and from 400 up errors.
                    if (status < 200 || status >= 400) {
                        var error = new HttpError('Http Error #$status', status);
                        error.body = response.body;
                        completed.add(() -> reject(error));
                    } else {
                        completed.add(() -> resolve(response));
                    }
                } catch (e:Dynamic) {
                    var message = Std.string(e);
                    completed.add(() -> reject(new HttpError(message, 0)));
                }
            });
        });
    }

    // A client's handler can't change once it has sent anything, so a new setting is a new client.
    private function currentClient():NetClient {
        var verifies = HttpClient.verifyCertificates;
        if (client == null || clientVerifies != verifies) {
            var handler = new NetClientHandler();
            if (!verifies) {
                handler.ServerCertificateCustomValidationCallback = NetClientHandler.DangerousAcceptAnyServerCertificateValidator;
            }
            client = new NetClient(handler);
            clientVerifies = verifies;
        }
        return client;
    }

    private static function startPump() {
        if (pump != null) {
            return;
        }
        pump = new haxe.Timer(50);
        pump.run = function() {
            var done = completed.pop(false);
            while (done != null) {
                inFlight--;
                done();
                done = completed.pop(false);
            }
            if (inFlight == 0) {
                pump.stop();
                pump = null;
            }
        };
    }

    private function send(client:NetClient, request:HttpRequest):HttpResponse {
        var message = new NetRequest(new NetMethod(request.method), buildUrl(request));
        var contentType = "text/plain";
        var headers = request.headers;
        if (headers != null) {
            for (name in headers.keys()) {
                var value = Std.string(headers.get(name));
                // .NET keeps this one on the content, and takes it there without any parameters.
                if (name.toLowerCase() == "content-type") {
                    contentType = StringTools.trim(value.split(";")[0]);
                } else {
                    message.Headers.TryAddWithoutValidation(name, value);
                }
            }
        }
        var body = request.body;
        if (body != null) {
            message.Content = new NetStringContent(bodyText(body, contentType), Encoding.UTF8, contentType);
        }
        var sent = client.Send(message);
        var response = new HttpResponse();
        response.originalRequest = request;
        try {
            response.httpStatus = cast sent.StatusCode;
            response.body = Bytes.ofData(sent.Content.ReadAsByteArrayAsync().Result);
        } catch (e:Dynamic) {
            sent.Dispose();
            throw e;
        }
        sent.Dispose();
        return response;
    }

    private function buildUrl(request:HttpRequest):String {
        var params:Map<String, Any> = [];
        for (name in request.url.queryParams.keys()) {
            params.set(name, request.url.queryParams.get(name));
        }
        for (name in request.queryParams.keys()) {
            params.set(name, request.queryParams.get(name));
        }
        var parts = [];
        for (name in params.keys()) {
            var value = Std.string(params.get(name));
            parts.push(encodeUrl ? StringTools.urlEncode(name) + "=" + StringTools.urlEncode(value) : name + "=" + value);
        }
        var url = request.url.build(false);
        return parts.length == 0 ? url : url + "?" + parts.join("&");
    }

    private function bodyText(body:Any, contentType:String):String {
        if ((body is String)) {
            return body;
        }
        if ((body is Bytes)) {
            throw "DotNetHttpProvider sends text bodies only";
        }
        return contentType == ContentTypes.ApplicationJson ? Json.stringify(body) : Std.string(body);
    }
}
#end
