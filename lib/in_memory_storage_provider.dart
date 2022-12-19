import 'package:unleash_proxy_client_flutter/storage_provider.dart';

class InMemoryStorageProvider implements StorageProvider {
  final Map<String, dynamic> store = {};

  InMemoryStorageProvider();

  Future<dynamic> get(String name) async {
    return store[name];
  }

  Future<void> save(String name, dynamic data) async {
    store[name] = data;
  }
}