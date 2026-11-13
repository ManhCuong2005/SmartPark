import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/providers.dart';
import '../../../domain/parking_rules.dart';
import '../../../shared/widgets/park_widgets.dart';
import '../../park_controller.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({
    super.key,
    required this.repository,
    this.booking,
    this.newEnd,
  }) : assert((booking == null) == (newEnd == null));
  final ParkController repository;
  final Json? booking;
  final DateTime? newEnd;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String _method = 'qr';
  int? _balance, _orderCode;
  Uri? _checkoutUrl;
  String? _message;
  bool _busy = false, _finished = false, _fundedFailure = false;
  late final String? _actor;
  late final AppLifecycleListener _lifecycle;
  bool get _extension => widget.booking != null;
  int get _amount =>
      _extension
          ? extensionFee(widget.booking!, widget.newEnd!)
          : widget.repository.total;
  bool get _sameAccount => widget.repository.userId == _actor && _actor != null;

  @override
  void initState() {
    super.initState();
    _actor = widget.repository.userId;
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (_orderCode != null && !_finished) _run(_check);
      },
    );
    _loadBalance();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await ref.read(payosTopupRepositoryProvider).balance();
      if (mounted && _sameAccount) setState(() => _balance = balance);
    } catch (_) {
      if (mounted)
        setState(() => _message = 'Chưa tải được số dư. Bạn có thể thử lại.');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _finished) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (!_sameAccount)
        throw const ParkFailure('Tài khoản đã thay đổi. Vui lòng mở lại vé.');
      await action();
    } catch (error) {
      if (error is ParkFailure && error.code == 'PRICE_CHANGED') {
        widget.repository.clearPayment(extension: _extension);
        await widget.repository.refresh();
      }
      if (mounted)
        setState(
          () =>
              _message =
                  error is ParkFailure
                      ? error.message
                      : 'Chưa xác minh được thanh toán. Nếu đã chuyển tiền, hãy kiểm tra giao dịch; đừng chuyển lại.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openQr() async {
    final url = _checkoutUrl!;
    if (url.origin != 'https://pay.payos.vn' ||
        !await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw const ParkFailure(
        'Chưa mở được QR. Hãy bấm Mở lại QR để tiếp tục giao dịch hiện tại.',
      );
    }
  }

  Future<void> _pay() async {
    if (_method == 'wallet') {
      await widget.repository.payBooking(
        booking: widget.booking,
        newEnd: widget.newEnd,
      );
      if (mounted) _finish();
      return;
    }
    final request = await widget.repository.paymentRequest(
      booking: widget.booking,
      newEnd: widget.newEnd,
    );
    final order = await ref
        .read(payosTopupRepositoryProvider)
        .createBookingPayment(request);
    if (!mounted || !_sameAccount) return;
    setState(() {
      _orderCode = (order['orderCode'] as num).toInt();
      _checkoutUrl = Uri.parse(order['checkoutUrl'] as String);
    });
    await _openQr();
  }

  Future<void> _check() async {
    final result = await ref
        .read(payosTopupRepositoryProvider)
        .checkBookingPayment(_orderCode!);
    if (!mounted || !_sameAccount) return;
    if (result['status'] == 'PAID' && result['booking'] is Map) {
      await widget.repository.acceptPaidBooking(
        Map<String, dynamic>.from(result['booking'] as Map),
        _actor!,
        extension: _extension,
      );
      if (mounted) _finish();
      return;
    }
    if (result['status'] == 'PAID' && result['bookingError'] != null) {
      widget.repository.clearPayment(extension: _extension);
      setState(() {
        _fundedFailure = true;
        _message =
            'Tiền đã được giữ trong số dư gửi xe. ${backendMessage(result['bookingError'] as String)} '
            'Hãy chọn lại thông tin và thanh toán bằng số dư; không cần chuyển tiền lần nữa.';
      });
      await _loadBalance();
    } else if (['CANCELLED', 'EXPIRED'].contains(result['status'])) {
      widget.repository.clearPayment(extension: _extension);
      setState(() {
        _orderCode = null;
        _checkoutUrl = null;
        _message =
            'QR đã hủy hoặc hết hạn. Bạn có thể chọn phương thức và thử lại.';
      });
    } else {
      setState(
        () =>
            _message =
                result['status'] == 'PAID'
                    ? 'Đã nhận tiền, đang chờ máy chủ xác nhận vé. Hãy kiểm tra lại sau.'
                    : 'Chưa nhận được xác nhận chuyển khoản. Hãy kiểm tra lại sau khi thanh toán.',
      );
    }
  }

  void _finish() {
    _finished = true;
    if (_extension) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/tickets/detail',
        (route) => false,
      );
    }
  }

  Widget _option(String method, IconData icon, String title, String subtitle) {
    final selected = _method == method;
    return Semantics(
      selected: selected,
      button: true,
      child: ParkCard(
        color: selected ? ParkColors.paleBlue : Colors.white,
        borderColor: selected ? ParkColors.blue : null,
        onTap: _busy ? null : () => setState(() => _method = method),
        child: Row(
          children: [
            Icon(icon, color: ParkColors.blue, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(subtitle),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: selected ? ParkColors.blue : ParkColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _orderCode != null;
    final insufficient =
        _method == 'wallet' && (_balance == null || _balance! < _amount);
    return PopScope(
      canPop: !_busy,
      child: ParkPage(
        bottom: BottomAction(
          child: ParkButton(
            _busy
                ? 'Đang xử lý…'
                : _fundedFailure
                ? 'Chọn lại thông tin'
                : pending
                ? 'Kiểm tra thanh toán'
                : 'Thanh toán ${money(_amount)}',
            onPressed:
                _busy || (!pending && insufficient)
                    ? null
                    : () {
                      if (_fundedFailure) {
                        if (_extension) {
                          Navigator.pop(context);
                        } else {
                          Navigator.popUntil(
                            context,
                            (route) =>
                                route.settings.name == '/booking/time' ||
                                route.isFirst,
                          );
                        }
                      } else {
                        _run(pending ? _check : _pay);
                      }
                    },
          ),
        ),
        child: Column(
          children: [
            PageHeading(
              _extension ? 'Thanh toán gia hạn' : 'Thanh toán vé',
              subtitle: 'Chọn phương thức phù hợp với bạn',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ParkCard(
                    color: ParkColors.paleBlue,
                    child: Column(
                      children: [
                        Text(
                          _extension
                              ? 'Thanh toán phần thời gian thêm'
                              : 'Tổng thanh toán',
                        ),
                        const SizedBox(height: 10),
                        Txt(
                          money(_amount),
                          size: 32,
                          color: ParkColors.blue,
                          weight: FontWeight.w700,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _extension
                              ? widget.booking!['plate'] as String
                              : widget.repository.vehicle.plate,
                        ),
                        if (_extension)
                          Text(
                            'Giờ ra mới: ${displayDate(widget.newEnd!)} ${clock(TimeOfDay.fromDateTime(widget.newEnd!))}',
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!pending) ...[
                    _option(
                      'qr',
                      Icons.qr_code_rounded,
                      'Chuyển khoản QR',
                      'Thanh toán an toàn qua payOS',
                    ),
                    const SizedBox(height: 12),
                    _option(
                      'wallet',
                      Icons.account_balance_wallet_outlined,
                      'Số dư gửi xe',
                      _balance == null
                          ? 'Chưa tải được số dư'
                          : 'Khả dụng: ${money(_balance!)}',
                    ),
                    if (_method == 'wallet')
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed:
                              _busy
                                  ? null
                                  : () async {
                                    await Navigator.pushNamed(
                                      context,
                                      '/wallet',
                                    );
                                    if (mounted) await _loadBalance();
                                  },
                          child: Text(
                            insufficient
                                ? 'Nạp thêm vào số dư'
                                : 'Quản lý số dư',
                          ),
                        ),
                      ),
                  ] else ...[
                    const ParkCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.qr_code_rounded,
                          size: 36,
                          color: ParkColors.blue,
                        ),
                        title: Text('Đang chờ xác nhận thanh toán'),
                        subtitle: Text(
                          'Sau khi chuyển khoản, quay lại đây để xem kết quả.',
                        ),
                      ),
                    ),
                    if (!_fundedFailure)
                      TextButton.icon(
                        onPressed: _busy ? null : () => _run(_openQr),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Mở lại QR'),
                      ),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: ParkCard(child: Text(_message!)),
                    ),
                    if (!pending && !_extension)
                      TextButton(
                        onPressed:
                            _busy
                                ? null
                                : () => Navigator.popUntil(
                                  context,
                                  (route) =>
                                      route.settings.name == '/booking/time' ||
                                      route.isFirst,
                                ),
                        child: const Text('Đổi thời gian'),
                      ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    _extension
                        ? 'Giờ ra chỉ được cập nhật sau khi thanh toán thành công. Chưa thanh toán sẽ không gia hạn vé.'
                        : 'Vé chỉ được xác nhận sau khi máy chủ nhận đủ tiền. Khi xe ra, không thu lại phần đã thanh toán.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nếu lịch thay đổi hoặc hết chỗ trong lúc chuyển khoản, tiền sẽ được giữ trong số dư gửi xe để bạn đặt lại.',
                  ),
                  if (_balance == null)
                    TextButton(
                      onPressed: _busy ? null : _loadBalance,
                      child: const Text('Tải lại số dư'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
