import 'models.dart';

String normalizePlate(String text) =>
    text.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
bool isValidPlate(String text) =>
    RegExp(r'^[0-9]{2}[A-Z]{1,2}[0-9]{4,6}$').hasMatch(normalizePlate(text));

/// Candidate extraction deliberately avoids guessing O/0 or I/1 in noisy OCR.
List<String> plateCandidates(String text) {
  final matches = RegExp(
    r'\b\d{2}\s*[-.]?\s*[A-Z]{1,2}\s*[-.]?\s*\d?\s*[-.\s]?\s*\d{2,3}\s*[.\s]?\s*\d{2}\b',
    caseSensitive: false,
  ).allMatches(text.replaceAll('\r', '\n'));
  return matches
      .map((m) => normalizePlate(m.group(0)!))
      .where(isValidPlate)
      .toSet()
      .toList();
}

int calculateFee(
  DateTime start,
  DateTime end,
  int hourlyRate,
  int freeMinutes,
) {
  if (end.isBefore(start) || hourlyRate < 0 || freeMinutes < 0) {
    throw const ParkFailure('Khoảng thời gian hoặc bảng giá không hợp lệ.');
  }
  final seconds = end.difference(start).inMilliseconds / 1000;
  final minutes = (seconds / 60).ceil();
  return minutes <= freeMinutes ? 0 : (minutes / 60).ceil() * hourlyRate;
}

void validateReservation(DateTime start, DateTime end, DateTime now) {
  if (!end.isAfter(start) ||
      start.isBefore(now.subtract(const Duration(minutes: 5))) ||
      end.difference(start) > const Duration(days: 7)) {
    throw const ParkFailure('Chọn giờ vào/ra hợp lệ, tối đa 7 ngày.');
  }
}

bool isTransientCode(String? code) =>
    code == null ||
    code.startsWith('08') ||
    [
      '429',
      '502',
      '503',
      '504',
      '40001',
      '40P01',
      '53300',
      '57014',
      'PGRST000',
      'PGRST001',
      'PGRST002',
    ].contains(code);

Duration retryDelay(int attempts) =>
    Duration(seconds: 2 * (1 << attempts.clamp(0, 8)));

String backendMessage(String code) {
  const errors = {
    'VERSION_CONFLICT':
        'Dữ liệu đã thay đổi trên thiết bị khác. Tải lại và kiểm tra thao tác.',
    'SLOT_UNAVAILABLE': 'Chỗ đỗ không còn khả dụng. Vui lòng chọn lại.',
    '23P01': 'Khoảng giờ này đã có người đặt. Vui lòng chọn lại.',
    '23505': 'Thao tác bị trùng hoặc chỗ đỗ đang được sử dụng.',
    'FORBIDDEN': 'Bạn không có quyền thực hiện thao tác ở bãi này.',
    '42501': 'Bạn không có quyền thực hiện thao tác.',
    'INVALID_STATE':
        'Trạng thái hoặc thời gian vé không cho phép thao tác này.',
    'PLATE_MISMATCH': 'Biển số không khớp vé. Kiểm tra lại trước khi xác nhận.',
    'INVALID_QR': 'QR không khớp vé trên hệ thống.',
    'CLOCK_REVIEW_REQUIRED':
        'Thời gian thiết bị cần được kiểm tra bởi chủ bãi.',
    'VEHICLE_IN_USE':
        'Phương tiện đang có vé hoạt động, chưa thể sửa biển số hoặc xóa.',
    'TICKET_NOT_FOUND':
        'Không tìm thấy vé hoặc bạn chưa được phân công vào bãi.',
  };
  return errors[code] ?? 'Không thể hoàn thành yêu cầu ($code).';
}
