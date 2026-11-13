import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/providers.dart';
import '../../park_controller.dart' show money, clock, displayDate;
import '../../../shared/widgets/park_widgets.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final _amount = TextEditingController();
  final _providerStatuses = <int, String>{};
  int? _balance;
  List<Map<String, dynamic>> _history = [];
  bool _busy = false;
  String? _message;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repository = ref.read(payosTopupRepositoryProvider);
    final (balance, history) =
        await (repository.balance(), repository.history()).wait;
    if (!mounted) return;
    setState(() {
      _balance = balance;
      _history = history;
    });
  }

  Future<void> _run(Future<void> Function() action, String errorMessage) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _message = errorMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() =>
      _run(_load, 'Chưa tải được số dư. Vui lòng thử lại.');

  Future<void> _open(Uri url) async {
    if (url.origin != 'https://pay.payos.vn' ||
        !await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw StateError('Unable to open payOS checkout');
    }
  }

  Future<void> _create() async {
    final amount = int.tryParse(_amount.text.trim());
    if (amount == null || amount < 2000 || amount > 5000000) {
      setState(() => _message = 'Nhập số tiền từ 2.000 ₫ đến 5.000.000 ₫.');
      return;
    }
    await _run(() async {
      final url = await ref.read(payosTopupRepositoryProvider).create(amount);
      if (!mounted) return;
      _amount.clear();
      await _load();
      if (mounted) await _open(url);
    }, 'Không mở được thanh toán. Kiểm tra lịch sử trước khi tạo yêu cầu mới.');
  }

  Future<void> _check(int orderCode) => _run(() async {
    final status = await ref
        .read(payosTopupRepositoryProvider)
        .check(orderCode);
    if (!mounted) return;
    _providerStatuses[orderCode] = status;
    await _load();
  }, 'Chưa xác minh được giao dịch. Nếu đã chuyển tiền, hãy kiểm tra lại sau.');

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
                child: Row(
                  children: [
                    const BackButton(),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Số dư gửi xe',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Làm mới số dư',
                      onPressed: _busy ? null : _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      WalletBalanceCard(
                        balanceText:
                            _balance != null
                                ? money(_balance!)
                                : _message != null
                                ? 'Chưa tải được'
                                : 'Đang tải…',
                        onRetry:
                            _balance == null && _message != null && !_busy
                                ? _refresh
                                : null,
                      ),
                      const SizedBox(height: 24),
                      _topupForm(),
                      if (_message != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: ParkCard(
                            borderColor: Theme.of(
                              context,
                            ).colorScheme.error.withValues(alpha: .35),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: Theme.of(context).colorScheme.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _message!,
                                    style: const TextStyle(height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      const Text(
                        'Lịch sử nạp tiền',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_busy && _balance == null)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (_history.isEmpty && _balance != null)
                        const ParkCard(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 36,
                                  color: ParkColors.muted,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Chưa có giao dịch nạp tiền',
                                  style: TextStyle(color: ParkColors.muted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      for (final row in _history) _transaction(row),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _topupForm() => ParkCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nạp tiền vào tài khoản',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _amount,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            labelText: 'Số tiền nạp',
            hintText: 'Nhập số tiền',
            suffixText: 'VNĐ',
            suffixStyle: TextStyle(fontSize: 13, color: ParkColors.muted),
            helperText: 'Từ 2.000đ đến 5.000.000đ',
            helperStyle: TextStyle(fontSize: 12, color: ParkColors.muted),
          ),
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _amount,
          builder:
              (context, value, _) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final amount in [20000, 50000, 100000, 200000, 500000])
                    ChoiceChip(
                      label: Text(money(amount)),
                      selected: int.tryParse(value.text) == amount,
                      showCheckmark: false,
                      onSelected:
                          _busy
                              ? null
                              : (_) {
                                _amount.value = TextEditingValue(
                                  text: amount.toString(),
                                  selection: TextSelection.collapsed(
                                    offset: amount.toString().length,
                                  ),
                                );
                              },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                ],
              ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ? null : _create,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 54),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.qr_code_2_rounded, size: 21),
            label: const Text(
              'Tạo QR chuyển khoản',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
        const SizedBox(height: 14),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.open_in_new_rounded, size: 14, color: ParkColors.muted),
            SizedBox(width: 6),
            Text(
              'Thanh toán qua payOS',
              style: TextStyle(fontSize: 12, color: ParkColors.muted),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _transaction(Map<String, dynamic> row) {
    final orderCode = row['order_code'] as int;
    final paid = row['paid_at'] != null;
    final url = row['checkout_url'] as String?;
    final expired =
        !DateTime.parse(row['expires_at'] as String).isAfter(DateTime.now());
    final cancelled = _providerStatuses[orderCode] == 'CANCELLED';
    final status =
        paid
            ? 'Đã nạp'
            : cancelled
            ? 'Đã hủy'
            : expired
            ? 'Đã hết hạn'
            : url == null
            ? 'Chưa tạo được QR'
            : 'Chờ thanh toán';
    final tone =
        paid
            ? ParkColors.green
            : expired || cancelled
            ? ParkColors.muted
            : const Color(0xFFAD6817);
    final date =
        DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ParkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    paid
                        ? Icons.south_west_rounded
                        : expired || cancelled
                        ? Icons.receipt_long_outlined
                        : Icons.schedule_rounded,
                    color: tone,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${paid ? '+' : ''}${money(row['amount'] as int)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color:
                              paid
                                  ? ParkColors.green
                                  : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (date != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${displayDate(date)} · ${clock(TimeOfDay.fromDateTime(date))}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: ParkColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: tone,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'Mã nạp $orderCode',
                  style: const TextStyle(fontSize: 12, color: ParkColors.muted),
                ),
              ],
            ),
            if (!paid && url != null) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  if (!expired && !cancelled)
                    FilledButton.tonalIcon(
                      onPressed:
                          _busy
                              ? null
                              : () => _run(
                                () => _open(Uri.parse(url)),
                                'Không mở được trang thanh toán.',
                              ),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                      label: const Text('Mở QR'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _check(orderCode),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Kiểm tra giao dịch'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final walletBalanceProvider = FutureProvider.autoDispose.family<int, String>(
  (ref, _) {
    ref.watch(parkControllerProvider.select((state) => state.snapshot
        .rows('payments').map((payment) => payment['id']).join(',')));
    return ref.watch(payosTopupRepositoryProvider).balance();
  },
);

class ProfileWalletCard extends ConsumerWidget {
  const ProfileWalletCard({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(walletBalanceProvider(userId));
    return WalletBalanceCard(
      balanceText: balance.when(
        data: money,
        loading: () => 'Đang tải…',
        error: (_, __) => 'Chưa tải được',
      ),
      onRetry:
          balance.hasError
              ? () => ref.invalidate(walletBalanceProvider(userId))
              : null,
      onTap: () async {
        await Navigator.pushNamed(context, '/wallet');
        if (context.mounted) ref.invalidate(walletBalanceProvider(userId));
      },
    );
  }
}

class WalletBalanceCard extends StatelessWidget {
  const WalletBalanceCard({
    super.key,
    required this.balanceText,
    this.onTap,
    this.onRetry,
  });
  final String balanceText;
  final VoidCallback? onTap, onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: ParkColors.blue.withValues(alpha: .14),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2347B5), ParkColors.navy],
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 11),
                      const Expanded(
                        child: Text(
                          'Số dư gửi xe',
                          style: TextStyle(
                            color: Color(0xFFD1DEFF),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 17),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      balanceText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  ),
                  if (onTap != null || onRetry != null) ...[
                    const SizedBox(height: 18),
                    Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: .16),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (onRetry != null)
                          TextButton(
                            onPressed: onRetry,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                            ),
                            child: const Text('Thử lại'),
                          ),
                        if (onTap != null) ...[
                          const Expanded(
                            child: Text(
                              'Nạp tiền',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
