import '../models/momo_models.dart';

class PhoneHelper {
  /// Normalizes any Ghana phone format (+233 54 123 4567, 233541234567, 054-123-4567)
  /// into standard 10-digit local format: 0541234567
  static String normalize(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');

    if (cleaned.startsWith('233') && cleaned.length == 12) {
      cleaned = '0${cleaned.substring(3)}';
    } else if (cleaned.startsWith('00233') && cleaned.length == 14) {
      cleaned = '0${cleaned.substring(5)}';
    }

    return cleaned;
  }

  /// Converts standard 10-digit to international format if needed (233541234567)
  static String toInternational(String raw) {
    final norm = normalize(raw);
    if (norm.startsWith('0') && norm.length == 10) {
      return '233${norm.substring(1)}';
    }
    return norm;
  }

  /// Formats for human readability: 054 412 3456
  static String formatDisplay(String raw) {
    final norm = normalize(raw);
    if (norm.length == 10 && norm.startsWith('0')) {
      return '${norm.substring(0, 3)} ${norm.substring(3, 6)} ${norm.substring(6)}';
    }
    return raw;
  }

  /// Detects telecom network by Ghanaian phone prefix
  static NetworkProvider? detectNetwork(String raw) {
    final norm = normalize(raw);
    if (norm.length < 3) return null;

    final prefix3 = norm.substring(0, 3);

    // MTN Ghana prefixes
    if (['024', '054', '055', '059', '025', '030'].contains(prefix3)) {
      return NetworkProvider.mtn;
    }

    // Telecel Ghana (formerly Vodafone) prefixes
    if (['020', '050'].contains(prefix3)) {
      return NetworkProvider.telecel;
    }

    // AT Ghana (formerly AirtelTigo) prefixes
    if (['027', '057', '026', '056'].contains(prefix3)) {
      return NetworkProvider.at;
    }

    return null;
  }
}
