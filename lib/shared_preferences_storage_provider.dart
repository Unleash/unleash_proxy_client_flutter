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
  Future<dynamic> get(String name) async {
    var result = _sharedPreferences.getString(name);
    return result != null ? jsonDecode(result) : null;
  }

  Future<void> save(String name, dynamic data) async {
    var jsonEncoder = JsonEncoder();
    await _sharedPreferences.setString(name, jsonEncoder.convert(data));
  }
}