class NetworkInfo {
  NetworkInfo({
    this.packageName,
    this.rxTotalBytes,
    this.txTotalBytes,
  });

  /// Construct class from the json map
  factory NetworkInfo.fromMap(Map map) => NetworkInfo(
        packageName: map['packageName'],
        rxTotalBytes: map['rxTotalBytes'],
        txTotalBytes: map['txTotalBytes'],
      );

  final String? packageName;
  final String? rxTotalBytes;
  final String? txTotalBytes;
}

enum NetworkType {
  all,
  wifi,
  mobile,
}

extension NetworkTypeExt on NetworkType {
  int get value {
    switch (this) {
      case NetworkType.all:
        return 1;
      case NetworkType.wifi:
        return 2;
      case NetworkType.mobile:
        return 3;
    }
  }
}
