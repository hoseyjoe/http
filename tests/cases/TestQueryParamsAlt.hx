package cases;

import http.HttpError;
import utest.Assert;
import http.HttpClient;
import utest.Async;
import utest.Test;

@:timeout(2000)
class TestQueryParamsAlt extends Test {
    private static inline var BASE_URL:String = "https://httpbin.org";

    function setupClass() {
        logging.LogManager.instance.addAdaptor(new logging.adaptors.ConsoleLogAdaptor({
            levels: [logging.LogLevel.Info, logging.LogLevel.Error]
        }));
    }

    function teardownClass() {
        logging.LogManager.instance.clearAdaptors();
    }

    function testGet(async:Async) {
        var client = new HttpClient();
        client.get('${BASE_URL}/get', ["param1" => "value1", "param2" => "value2"]).then(result -> {
            Assert.notNull(result.response.body);
            var json = result.response.bodyAsJson;
            Assert.notNull(json);
            Assert.equals("https://httpbin.org/get?param1=value1&param2=value2", json.url);
            Assert.equals("value1", json.args.param1);
            Assert.equals("value2", json.args.param2);
            async.done();
        }, (error:HttpError) -> {
            Assert.fail();
            async.done();
        });
    }

    function testPost(async:Async) {
        var client = new HttpClient();
        client.post('${BASE_URL}/post', null, ["param1" => "value1", "param2" => "value2"]).then(result -> {
            Assert.notNull(result.response.body);
            var json = result.response.bodyAsJson;
            Assert.notNull(json);
            Assert.equals("https://httpbin.org/post?param1=value1&param2=value2", json.url);
            Assert.equals("value1", json.args.param1);
            Assert.equals("value2", json.args.param2);
            async.done();
        }, (error:HttpError) -> {
            Assert.fail();
            async.done();
        });
    }

    function testPut(async:Async) {
        var client = new HttpClient();
        client.put('${BASE_URL}/put', null, ["param1" => "value1", "param2" => "value2"]).then(result -> {
            Assert.notNull(result.response.body);
            var json = result.response.bodyAsJson;
            Assert.notNull(json);
            Assert.equals("https://httpbin.org/put?param1=value1&param2=value2", json.url);
            Assert.equals("value1", json.args.param1);
            Assert.equals("value2", json.args.param2);
            async.done();
        }, (error:HttpError) -> {
            Assert.fail();
            async.done();
        });
    }

    function testDelete(async:Async) {
        var client = new HttpClient();
        client.delete('${BASE_URL}/delete', null, ["param1" => "value1", "param2" => "value2"]).then(result -> {
            Assert.notNull(result.response.body);
            var json = result.response.bodyAsJson;
            Assert.notNull(json);
            Assert.equals("https://httpbin.org/delete?param1=value1&param2=value2", json.url);
            Assert.equals("value1", json.args.param1);
            Assert.equals("value2", json.args.param2);
            async.done();
        }, (error:HttpError) -> {
            Assert.fail();
            async.done();
        });
    }
}