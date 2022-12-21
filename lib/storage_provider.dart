abstract class StorageProvider {
  Future<void> save(String name, String data);
  Future<String?> get(String name);
}
