import 'package:unleash_proxy_client_flutter/storage_provider.dart';

class InMemoryStorageProvider implements StorageProvider {
  final Map<String, String> store = {};

  InMemoryStorageProvider();

  Future<String?> get(String name) async {
    return store[name];
  }

  Future<void> save(String name, String data) async {
    store[name] = data;
  }
}