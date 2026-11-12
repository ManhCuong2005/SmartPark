class GeoPosition {
  const GeoPosition(this.latitude, this.longitude);
  final double latitude, longitude;
}

abstract interface class LocationService {
  /// One foreground fix, only after the user requests their position.
  Future<GeoPosition> currentPosition();
}
