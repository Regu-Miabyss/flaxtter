import 'package:ffcache/ffcache.dart';
import 'package:logging/logging.dart';

extension CacheHelper on FFCache {
  static final log = Logger('CacheHelper');

  Future<String> getOrCreateAsJSON(String key, Duration expiry, Future<String> Function() create) async {
    if (await has(key)) {
      log.info('Loading $key from the cache');
      return await getJSON(key);
    }

    log.info('Loading $key from the source');
    var result = await create();
    await setJSONWithTimeout(key, result, expiry);
    return result;
  }
}
