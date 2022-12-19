import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:unleash_proxy_client_flutter/storage_provider.dart';

class SharedPreferencesStorageProvider implements StorageProvider {
  SharedPreferences _sharedPreferences;

  static Future<StorageProvider> init() async {
    final sharedPreferences = await SharedPreferences.getInstance();
    return SharedPreferencesStorageProvider(sharedPreferences);
  }

  SharedPreferencesStorageProvider(this._sharedPreferences);

  // for shared preferences it doesn't have to be async
  Future<String?> get(String name) async {
    return _sharedPreferences.getString(name);
  }

  Future<void> save(String name, String data) async {
    await _sharedPreferences.setString(name, data);
  }
}