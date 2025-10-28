enum StorageMode {
  local,
  objectStore,
}

StorageMode storageModeFromString(String? value) {
  switch (value) {
    case 'objectStore':
      return StorageMode.objectStore;
    case 'local':
    default:
      return StorageMode.local;
  }
}

String storageModeToString(StorageMode mode) {
  switch (mode) {
    case StorageMode.local:
      return 'local';
    case StorageMode.objectStore:
      return 'objectStore';
  }
}
