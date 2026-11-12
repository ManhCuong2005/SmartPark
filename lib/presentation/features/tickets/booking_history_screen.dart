import 'package:flutter/material.dart';
import '../../park_controller.dart';
import '../../../shared/widgets/park_widgets.dart';
import 'booking_history_data.dart';

class TicketHistoryScreen extends StatefulWidget {
  const TicketHistoryScreen({super.key, required this.repository});
  final ParkController repository;
  @override
  State<TicketHistoryScreen> createState() => _TicketHistoryScreenState();
}

class _TicketHistoryScreenState extends State<TicketHistoryScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  bool _activeTab = true, _showAllActive = false, _cancelled = false;
  String _query = '';

  void _selectTab(bool active) {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _search.clear();
    setState(() {
      _activeTab = active;
      _cancelled = false;
      _query = '';
    });
  }

  void _open(HistoryBooking booking) {
    widget.repository.update(
      () => widget.repository.selectedBookingId = booking.id,
    );
    Navigator.pushNamed(context, '/tickets/qr');
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository;
    final data = BookingHistoryData.fromSnapshot(repo.snapshot, repo.userId);
    final theme = Theme.of(context), colors = theme.colorScheme;
    final completed = data.ended.where((b) => !b.isCancelled).toList();
    final cancelled = data.ended.where((b) => b.isCancelled).toList();
    final active = _showAllActive ? data.active : data.active.take(1).toList();
    final query = _query.trim().toLowerCase();
    final ended =
        (_cancelled ? cancelled : completed)
            .where(
              (b) =>
                  query.isEmpty ||
                  '${b.lotName} ${b.plate} ${b.dateLabel}'
                      .toLowerCase()
                      .contains(query),
            )
            .toList();
    final archive = <({String? month, HistoryBooking? booking})>[];
    String? previousMonth;
    for (final b in ended) {
      final month = 'Tháng ${b.sortTime.month}/${b.sortTime.year}';
      if (previousMonth != month) {
        archive.add((month: month, booking: null));
        previousMonth = month;
      }
      archive.add((month: null, booking: b));
    }
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: repo.refresh,
                    child: CustomScrollView(
                      key: const PageStorageKey('booking-history-scroll'),
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        const SliverToBoxAdapter(
                          child: PageHeading('Lịch sử đặt chỗ', back: false),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _HistoryTabsHeader(
                            background: theme.scaffoldBackgroundColor,
                            child: _HistoryTabs(
                              active: _activeTab,
                              onChanged: _selectTab,
                            ),
                          ),
                        ),
                        if (_activeTab) ...[
                          if (data.active.isEmpty)
                            const SliverPadding(
                              padding: EdgeInsets.fromLTRB(22, 12, 22, 0),
                              sliver: SliverToBoxAdapter(
                                child: _HistoryEmpty(
                                  title: 'Chưa có vé đang hoạt động',
                                  message:
                                      'Vé đặt chỗ mới sẽ xuất hiện tại đây để bạn mở mã QR khi đến bãi.',
                                ),
                              ),
                            ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _ActiveBookingCard(
                                    booking: active[i],
                                    onTap: () => _open(active[i]),
                                  ),
                                ),
                                childCount: active.length,
                              ),
                            ),
                          ),
                          if (data.active.length > 1)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                ),
                                child: TextButton(
                                  onPressed:
                                      () => setState(
                                        () => _showAllActive = !_showAllActive,
                                      ),
                                  child: Text(
                                    _showAllActive
                                        ? 'Thu gọn vé đang hoạt động'
                                        : 'Xem tất cả ${data.active.length} vé đang hoạt động',
                                  ),
                                ),
                              ),
                            ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(22, 0, 16, 8),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Txt(
                                      'Gần đây',
                                      size: 18,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                  if (data.ended.isNotEmpty)
                                    TextButton(
                                      onPressed: () => _selectTab(false),
                                      child: const Text('Xem tất cả'),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (completed.isEmpty)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(22, 0, 22, 24),
                                child: Text(
                                  'Các lượt gửi xe đã hoàn thành sẽ được lưu tại đây.',
                                ),
                              ),
                            ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _HistoryBookingCard(
                                    booking: completed[i],
                                    onTap: () => _open(completed[i]),
                                  ),
                                ),
                                childCount: completed.length.clamp(0, 2),
                              ),
                            ),
                          ),
                          if (cancelled.isNotEmpty && completed.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                ),
                                child: TextButton(
                                  onPressed: () {
                                    _selectTab(false);
                                    setState(() => _cancelled = true);
                                  },
                                  child: Text(
                                    'Xem ${cancelled.length} vé đã hủy',
                                  ),
                                ),
                              ),
                            ),
                        ] else ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    key: const ValueKey('history-search'),
                                    controller: _search,
                                    onChanged:
                                        (value) =>
                                            setState(() => _query = value),
                                    decoration: const InputDecoration(
                                      hintText: 'Tìm bãi hoặc biển số',
                                      prefixIcon: Icon(Icons.search, size: 20),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      ChoiceChip(
                                        label: Text(
                                          'Đã kết thúc (${completed.length})',
                                        ),
                                        selected: !_cancelled,
                                        onSelected:
                                            (_) => setState(
                                              () => _cancelled = false,
                                            ),
                                      ),
                                      ChoiceChip(
                                        label: Text(
                                          'Đã hủy (${cancelled.length})',
                                        ),
                                        selected: _cancelled,
                                        onSelected:
                                            (_) => setState(
                                              () => _cancelled = true,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (ended.isEmpty)
                            SliverPadding(
                              padding: const EdgeInsets.all(22),
                              sliver: SliverToBoxAdapter(
                                child: _HistoryEmpty(
                                  title:
                                      query.isNotEmpty
                                          ? 'Không tìm thấy vé phù hợp'
                                          : _cancelled
                                          ? 'Chưa có vé đã hủy'
                                          : 'Chưa có lượt gửi xe hoàn thành',
                                  message:
                                      query.isNotEmpty
                                          ? 'Thử tìm bằng tên bãi, biển số hoặc ngày đặt chỗ.'
                                          : 'Lịch sử sẽ tự cập nhật sau khi máy chủ xác nhận thay đổi.',
                                ),
                              ),
                            ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                i,
                              ) {
                                final item = archive[i];
                                if (item.month != null) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      top: 20,
                                      bottom: 12,
                                    ),
                                    child: Text(
                                      item.month!,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  );
                                }
                                final booking = item.booking!;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _HistoryBookingCard(
                                    booking: booking,
                                    onTap: () => _open(booking),
                                  ),
                                );
                              }, childCount: archive.length),
                            ),
                          ),
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    ),
                  ),
                ),
                const ParkBottomNav(active: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryTabs extends StatelessWidget {
  const _HistoryTabs({required this.active, required this.onChanged});
  final bool active;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Material(
    color: _historyCardColor(context),
    borderRadius: BorderRadius.circular(13),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final isActive in [true, false])
            Expanded(
              child: Semantics(
                button: true,
                selected: active == isActive,
                child: Material(
                  color:
                      active == isActive ? ParkColors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(11),
                    onTap: () => onChanged(isActive),
                    child: SizedBox(
                      height: 40,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              isActive ? 'Đang hoạt động' : 'Đã hoàn thành',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color:
                                    active == isActive
                                        ? Colors.white
                                        : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _HistoryTabsHeader extends SliverPersistentHeaderDelegate {
  _HistoryTabsHeader({required this.child, required this.background});
  final Widget child;
  final Color background;
  @override
  double get minExtent => 64;
  @override
  double get maxExtent => 64;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(
    color: background,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
      child: child,
    ),
  );
  @override
  bool shouldRebuild(covariant _HistoryTabsHeader oldDelegate) =>
      child != oldDelegate.child || background != oldDelegate.background;
}

class _ActiveBookingCard extends StatelessWidget {
  const _ActiveBookingCard({required this.booking, required this.onTap});
  final HistoryBooking booking;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final parked = booking.status == 'parked';
    final muted = _historyMuted(context);
    return Semantics(
      button: true,
      label: 'Mở vé ${booking.plate} tại ${booking.lotName}',
      child: ParkCard(
        key: ValueKey('history-active-${booking.id}'),
        color: _historyCardColor(context),
        borderColor: _historyBorderColor(context),
        padding: const EdgeInsets.all(18),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 148),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (parked)
                    const FigmaAsset('16:390', 'Status', size: 9)
                  else
                    const Icon(
                      Icons.schedule_outlined,
                      size: 13,
                      color: ParkColors.blue,
                    ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      parked ? 'ĐANG SỬ DỤNG' : 'ĐÃ ĐẶT CHỖ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: parked ? ParkColors.green : ParkColors.blue,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      booking.plate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                booking.lotName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                booking.timeLabel,
                style: TextStyle(fontSize: 12, color: muted, height: 1.4),
              ),
              const SizedBox(height: 18),
              Divider(height: 1, color: _historyBorderColor(context)),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      booking.slotCode.isEmpty
                          ? 'Xem vị trí trên vé'
                          : 'Vị trí ${booking.slotCode}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ParkColors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        booking.priceCaption,
                        style: TextStyle(fontSize: 10, color: muted),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        money(booking.amount),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryBookingCard extends StatelessWidget {
  const _HistoryBookingCard({required this.booking, required this.onTap});
  final HistoryBooking booking;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Mở lịch sử ${booking.lotName}, ${booking.plate}',
    child: ParkCard(
      key: ValueKey('history-ended-${booking.id}'),
      color: _historyCardColor(context),
      borderColor: _historyBorderColor(context),
      padding: const EdgeInsets.all(15),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 70),
        child: Row(
          children: [
            Container(
              width: 55,
              height: 56,
              decoration: BoxDecoration(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? ParkColors.blue.withValues(alpha: .18)
                        : ParkColors.paleBlue,
                borderRadius: BorderRadius.circular(15),
              ),
              alignment: Alignment.center,
              child:
                  booking.motorcycle
                      ? const Icon(
                        Icons.two_wheeler_outlined,
                        size: 29,
                        color: ParkColors.blue,
                      )
                      : const FigmaAsset('16:390', 'IconCar', size: 29),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.lotName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${booking.dateLabel} · ${booking.durationLabel}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: _historyMuted(context),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    booking.isCancelled || booking.isExpired
                        ? booking.isExpired
                            ? 'Hết hạn · Chưa sử dụng'
                            : 'Đã hủy · Không thu phí'
                        : money(booking.amount),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          booking.isCancelled || booking.isExpired
                              ? _historyMuted(context)
                              : ParkColors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const FigmaAsset('16:390', 'IconChevronRight', size: 21),
          ],
        ),
      ),
    ),
  );
}

Color _historyMuted(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : ParkColors.muted;

Color _historyCardColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF182536)
        : Colors.white;
Color _historyBorderColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2B3B50)
        : ParkColors.line;

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty({required this.title, required this.message});
  final String title, message;
  @override
  Widget build(BuildContext context) => ParkCard(
    color: _historyCardColor(context),
    borderColor: _historyBorderColor(context),
    child: Column(
      children: [
        const Icon(
          Icons.confirmation_number_outlined,
          color: ParkColors.blue,
          size: 30,
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
