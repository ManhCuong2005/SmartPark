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
  // The persisted grace value is legacy data. Current policy charges from
  // arrival, with at least one full hour, including an immediate check-out.
  final hours = (minutes / 60).ceil();
  return (hours < 1 ? 1 : hours) * hourlyRate;
}

void validateReservation(DateTime start, DateTime end, DateTime now) {
  if (!end.isAfter(start) ||
      start.isBefore(now.subtract(const Duration(minutes: 5))) ||
      end.difference(start) > const Duration(days: 7)) {
    throw const ParkFailure('Chọn giờ vào/ra hợp lệ, tối đa 7 ngày.');
  }
}

DateTime noShowDeadline(DateTime scheduledEnd) => scheduledEnd;

/// A late arrival keeps the purchased duration; early admission reserves the
/// actual arrival too. The server must approve the resulting interval atomically.
({DateTime start, DateTime end}) admissionPeriod(
  DateTime scheduledStart,
  DateTime scheduledEnd,
  DateTime arrival,
) =>
    !arrival.isBefore(scheduledEnd)
        ? (
          start: arrival,
          end: arrival.add(scheduledEnd.difference(scheduledStart)),
        )
        : (
          start: arrival.isBefore(scheduledStart) ? arrival : scheduledStart,
          end: scheduledEnd,
        );

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
    '23P01': 'Lịch của ô đỗ hoặc phương tiện bị trùng. Vui lòng kiểm tra lại.',
    'VEHICLE_TIME_CONFLICT':
        'Xe này đã có vé trùng giờ. Hãy đổi xe/giờ hoặc xem vé hiện có.',
    'SLOT_TIME_CONFLICT':
        'Ô đỗ đã có lịch trùng khoảng giờ bạn chọn. Vui lòng chọn ô hoặc giờ khác.',
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
        'Xe đang có vé đặt chỗ hoặc đang gửi trong bãi. Hãy kết thúc lượt gửi hoặc hủy vé trước khi đổi biển số, loại xe hoặc xóa xe.',
    'VEHICLE_NOT_FOUND':
        'Phương tiện không còn tồn tại. Vui lòng tải lại danh sách xe.',
    'INVALID_TIME': 'Thời gian đặt chỗ không hợp lệ. Vui lòng chọn lại.',
    'SLOT_IN_USE': 'Vị trí đang có vé hoạt động, chưa thể tắt vị trí này.',
    'LOT_UNAVAILABLE': 'Bãi đỗ hiện không nhận đặt chỗ.',
    'TICKET_NOT_FOUND':
        'Không tìm thấy vé hoặc bạn chưa được phân công vào bãi.',
  };
  return errors[code] ?? 'Không thể hoàn thành yêu cầu ($code).';
}
