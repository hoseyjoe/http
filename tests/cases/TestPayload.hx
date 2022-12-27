package cases;

import http.ContentTypes;
import http.StandardHeaders;
import haxe.Json;
import http.HttpError;
import utest.Assert;
import http.HttpClient;
import utest.Async;
import utest.Test;

@:timeout(2000)
class TestPayload extends Test {
    private static inline var BASE_URL:String = "https://httpbin.org";

    function setupClass() {
        logging.LogManager.instance.addAdaptor(new logging.adaptors.ConsoleLogAdaptor({
            levels: [logging.LogLevel.Info, logging.LogLevel.Error]
        }));
    }

    function teardownClass() {
        logging.LogManager.instance.clearAdaptors();
    }

    function testPost(async:Async) {
        var client = new HttpClient();
        client.defaultRequestHeaders = [StandardHeaders.ContentType => ContentTypes.ApplicationJson];
        client.post('${BASE_URL}/post', {foo: "foo string", bar: 111}).then(result -> {
            Assert.notNull(result.response.body);
            var json = result.response.bodyAsJson;
            Assert.notNull(json);
            Assert.equals("https://httpbin.org/post", json.url);
            var data = json.data;
            Assert.notNull(data);
            var jsonData = Json.parse(data);
            Assert.equals("foo string", jsonData.foo);
            Assert.equals(111, jsonData.bar);
            async.done();
        }, (error:HttpError) -> {
            Assert.fail();
            async.done();
        });
    }

    function testPut(async:Async) {
        var client = new HttpClient();
        client.defaultRequestHeaders = [StandardHeaders.ContentType => ContentTypes.ApplicationJson];
        client.put('${BASE_URL}/put', {foo: "foo string", bar: 111}).then(result -> {
            Assert.notNull(result.response.body);
            var json = result.response.bodyAsJson;
            Assert.notNull(json);
            Assert.equals("https://httpbin.org/put", json.url);
            var data = json.data;
            Assert.notNull(data);
            var jsonData = Json.parse(data);
            Assert.equals("foo string", jsonData.foo);
            Assert.equals(111, jsonData.bar);
            async.done();
        }, (error:HttpError) -> {
            Assert.fail();
            async.done();
        });
    }
}