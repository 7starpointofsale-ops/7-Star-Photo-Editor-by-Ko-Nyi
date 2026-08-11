import 'dart:typed_data';

class ClothChangeException implements Exception {
  const ClothChangeException(this.message);
  final String message;
}

abstract class ClothChangeService {
  Future<Uint8List> change({required Uint8List person, required Uint8List garment});
}

/// Intentionally does not guess or scrape ImageHub endpoints. Replace with an
/// official, authorised integration when ImageHub publishes one.
class UnavailableClothChangeService implements ClothChangeService {
  @override
  Future<Uint8List> change({required Uint8List person, required Uint8List garment}) {
    throw const ClothChangeException('အဝတ်အစားပြောင်းဝန်ဆောင်မှုကို ယခု မရရှိသေးပါ။');
  }
}
