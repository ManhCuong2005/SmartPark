/// Dịch vụ sinh chuỗi mã VietQR chuẩn Napas 247 / EMVCo QR code
/// Giúp sinh mã QR động để khách hàng thanh toán nhanh qua ứng dụng ngân hàng.
class VietQrHelper {
  const VietQrHelper._();

  /// Sinh URL ảnh VietQR chuẩn nhanh thông qua cổng VietQR API công khai
  /// [bankBin]: Mã BIN ngân hàng (ví dụ: 970422 - MBBank, 970415 - VietinBank, 970436 - Vietcombank)
  /// [accountNo]: Số tài khoản nhận tiền
  /// [amount]: Số tiền (VNĐ)
  /// [description]: Nội dung chuyển khoản (ví dụ: SMARTPARK TICKET 123)
  /// [accountName]: Tên chủ tài khoản
  static String generateQuickQrUrl({
    required String bankBin,
    required String accountNo,
    required int amount,
    required String description,
    String? accountName,
  }) {
    final cleanAccount = accountNo.trim();
    final cleanDesc = Uri.encodeComponent(description.trim());
    final cleanName = accountName != null ? Uri.encodeComponent(accountName.trim()) : '';
    
    // Sử dụng endpoint chuẩn của VietQR image service:
    // https://img.vietqr.io/image/<BANK_BIN>-<ACCOUNT_NO>-compact2.png?amount=<AMOUNT>&addInfo=<DESCRIPTION>&accountName=<ACCOUNT_NAME>
    final buffer = StringBuffer('https://img.vietqr.io/image/$bankBin-$cleanAccount-compact2.png');
    buffer.write('?amount=$amount');
    if (cleanDesc.isNotEmpty) {
      buffer.write('&addInfo=$cleanDesc');
    }
    if (cleanName.isNotEmpty) {
      buffer.write('&accountName=$cleanName');
    }
    return buffer.toString();
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

