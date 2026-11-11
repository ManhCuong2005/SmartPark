/// Dịch vụ sinh chuỗi mã VietQR chuẩn Napas 247 / EMVCo QR code
/// Giúp sinh mã QR động để khách hàng thanh toán nhanh qua ứng dụng ngân hàng.
class VietQrHelper {
  const VietQrHelper._();

  /// Sinh chuỗi dữ liệu EMVCo VietQR chuẩn (dạng text payload) để render trực tiếp bằng qr_flutter
  /// Giúp hiển thị mã QR offline ngay lập tức, không phụ thuộc vào internet hay dịch vụ ảnh bên ngoài,
  /// và không bao giờ bị lỗi hết hạn phiên từ phía API trung gian.
  static String generateEmvCoPayload({
    required String bankBin,
    required String accountNo,
    required int amount,
    required String description,
  }) {
    String tlv(String tag, String value) {
      final len = value.length.toString().padLeft(2, '0');
      return '$tag$len$value';
    }

    // 00: Payload Format Indicator = "01"
    final f00 = tlv('00', '01');
    // 01: Point of Initiation Method = "12" (Dynamic QR có số tiền)
    final f01 = tlv('01', '12');

    // Tag 38: Merchant Account Information cho VietQR / Napas
    // Sub-tag 00: GUID Napas ("A000000727")
    final sub00 = tlv('00', 'A000000727');
    // Sub-tag 01: Beneficiary Organization (Bank BIN + Account Number)
    final sub01 = tlv('01', tlv('00', bankBin) + tlv('01', accountNo.trim()));
    // Sub-tag 02: Service Code ("QRIBFTTA" - Chuyển nhanh Napas247 đến tài khoản)
    final sub02 = tlv('02', 'QRIBFTTA');
    final f38 = tlv('38', sub00 + sub01 + sub02);

    // 53: Transaction Currency (704 = VNĐ)
    final f53 = tlv('53', '704');
    // 54: Transaction Amount
    final f54 = tlv('54', amount.toString());
    // 58: Country Code ("VN")
    final f58 = tlv('58', 'VN');

    // 62: Additional Data Field Template (Nội dung chuyển khoản)
    final f62 = tlv('62', tlv('08', description.trim()));

    final payloadWithoutCrc = '$f00$f01$f38$f53$f54$f58$f62' + '6304';

    // Tính mã kiểm tra CRC-16/CCITT-FALSE
    int crc = 0xFFFF;
    for (int i = 0; i < payloadWithoutCrc.length; i++) {
      crc ^= (payloadWithoutCrc.codeUnitAt(i) << 8);
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    final crcString = crc.toRadixString(16).toUpperCase().padLeft(4, '0');
    return '$payloadWithoutCrc$crcString';
  }

  /// Danh sách các mã BIN ngân hàng phổ biến tại Việt Nam
  static const Map<String, String> popularBankBins = {
    'MBBank (MB)': '970422',
    'Vietcombank (VCB)': '970436',
    'VietinBank (CTG)': '970415',
    'Techcombank (TCB)': '970407',
    'BIDV': '970418',
    'TPBank': '970423',
    'VPBank': '970432',
    'ACB': '970416',
  };
}

