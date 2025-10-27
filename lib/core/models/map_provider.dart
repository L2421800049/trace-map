enum MapProvider {
  defaultMap,
  tencent,
}

String mapProviderToStorage(MapProvider provider) => provider.name;

MapProvider mapProviderFromStorage(String? value) {
  if (value == MapProvider.tencent.name) {
    return MapProvider.tencent;
  }
  return MapProvider.defaultMap;
}

String mapProviderDisplayName(MapProvider provider) {
  switch (provider) {
    case MapProvider.tencent:
      return '腾讯地图';
    case MapProvider.defaultMap:
      return '默认地图';
  }
}
