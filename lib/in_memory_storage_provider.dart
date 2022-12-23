import 'package:unleash_proxy_client_flutter/storage_provider.dart';

/// Storage provider using memory. This is the implementation used in most unit tests.
class InMemoryStorageProvider extends StorageProvider {
  final Map<String, String> store = {};

  InMemoryStorageProvider();

  @override
  Future<String?> get(String name) async {
    return store[name];
  }

  @override
  Future<void> save(String name, String data) async {
    store[name] = data;
  }
}
