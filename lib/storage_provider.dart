abstract class StorageProvider {
    Future<void> save(String name, dynamic data);
    Future<dynamic> get(String name);
}