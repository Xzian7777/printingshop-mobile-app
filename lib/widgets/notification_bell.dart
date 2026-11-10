import 'package:flutter/material.dart';
import '../services/app_notifications.dart';
import '../theme/dashboard_theme.dart';

class NotificationBell extends StatefulWidget {
  final NotificationRepository repository;
  final ValueChanged<InboxNotification> onOpen;
  const NotificationBell(
      {super.key, required this.repository, required this.onOpen});
  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  late Stream<List<InboxNotification>> _stream = widget.repository.watch();
  @override
  void didUpdateWidget(covariant NotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository.identity != widget.repository.identity) {
      _stream = widget.repository.watch();
    }
  }

  Stream<List<InboxNotification>> _retry() {
    final stream = widget.repository.watch();
    setState(() => _stream = stream);
    return stream;
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<InboxNotification>>(
        stream: _stream,
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          final unread = items.where((item) => item.unread).length;
          return IconButton(
            tooltip: 'Notifications',
            icon: Badge(
                isLabelVisible: unread > 0,
                label: Text(unread > 99 ? '99+' : '$unread'),
                backgroundColor: const Color(0xFFBE123C),
                textColor: Colors.white,
                child: const Icon(Icons.notifications_outlined,
                    color: DashboardTheme.green)),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: Colors.white,
              builder: (_) => Theme(
                  data: DashboardTheme.light,
                  child: SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.75,
                    child: _NotificationSheet(
                        stream: _stream,
                        initial: items,
                        initialError: snapshot.hasError,
                        repository: widget.repository,
                        onRetry: _retry,
                        onOpen: widget.onOpen),
                  )),
            ),
          );
        },
      );
}

class _NotificationSheet extends StatefulWidget {
  final Stream<List<InboxNotification>> stream;
  final List<InboxNotification> initial;
  final bool initialError;
  final NotificationRepository repository;
  final Stream<List<InboxNotification>> Function() onRetry;
  final ValueChanged<InboxNotification> onOpen;
  const _NotificationSheet(
      {required this.stream,
      required this.initial,
      required this.initialError,
      required this.repository,
      required this.onRetry,
      required this.onOpen});
  @override
  State<_NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<_NotificationSheet> {
  late Stream<List<InboxNotification>> _stream = widget.stream;
  bool _busy = false;
  String? _error;

  Future<void> _save(List<InboxNotification> items,
      {bool clear = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (clear) {
        await widget.repository.clear(items);
      } else {
        await widget.repository.markRead(items);
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Unable to save notification changes. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open(InboxNotification item) {
    final messenger = ScaffoldMessenger.of(context);
    if (item.unread) {
      widget.repository.markRead([item]).catchError((Object error) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Unable to mark this notification as read.')));
      });
    }
    Navigator.pop(context);
    widget.onOpen(item);
  }

  String _date(DateTime date) {
    final local = date.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return '${months[local.month - 1]} ${local.day}, ${local.year} · $hour:${local.minute.toString().padLeft(2, '0')} ${local.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: StreamBuilder<List<InboxNotification>>(
          stream: _stream,
          initialData: widget.initial,
          builder: (context, snapshot) {
            final items = snapshot.data ?? [];
            final unread = items.where((item) => item.unread).toList();
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Expanded(
                        child: Text('Notifications',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: DashboardTheme.ink))),
                    IconButton(
                        tooltip: 'Close notifications',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ]),
                  Wrap(spacing: 8, children: [
                    TextButton.icon(
                        onPressed: _busy || unread.isEmpty
                            ? null
                            : () => _save(unread),
                        icon: const Icon(Icons.done_all, size: 18),
                        label: const Text('Mark read')),
                    TextButton.icon(
                        onPressed: _busy || items.isEmpty
                            ? null
                            : () => _save(items, clear: true),
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text('Clear all')),
                  ]),
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(_error!,
                            style: const TextStyle(color: Color(0xFFBE123C)))),
                  const Divider(),
                  Expanded(
                      child: (snapshot.hasError ||
                              (snapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  widget.initialError))
                          ? Center(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                  const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                          'Unable to load notifications. Check your connection and account access.',
                                          textAlign: TextAlign.center)),
                                  OutlinedButton(
                                      onPressed: () => setState(
                                          () => _stream = widget.onRetry()),
                                      child: const Text('Retry')),
                                ]))
                          : items.isEmpty
                              ? const Center(
                                  child: Text('No notifications yet.',
                                      style: TextStyle(
                                          color: DashboardTheme.muted)))
                              : ListView.separated(
                                  itemCount: items.length,
                                  separatorBuilder: (_, index) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final item = items[index];
                                    return Material(
                                        color: item.unread
                                            ? const Color(0xFFECFDF5)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          onTap: () => _open(item),
                                          child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Expanded(
                                                              child: Text(
                                                                  item.title,
                                                                  maxLines: 2,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: const TextStyle(
                                                                      color: DashboardTheme
                                                                          .ink,
                                                                      fontSize:
                                                                          14,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700))),
                                                          if (item.unread)
                                                            Padding(
                                                                padding: EdgeInsets
                                                                    .only(
                                                                        left: 8,
                                                                        top: 4),
                                                                child: Semantics(
                                                                    label:
                                                                        'Unread',
                                                                    child: Icon(
                                                                        Icons
                                                                            .circle,
                                                                        size: 8,
                                                                        color: DashboardTheme
                                                                            .green))),
                                                        ]),
                                                    const SizedBox(height: 5),
                                                    Text(item.message,
                                                        maxLines: 3,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                            color:
                                                                DashboardTheme
                                                                    .muted,
                                                            fontSize: 13,
                                                            height: 1.4)),
                                                    const SizedBox(height: 8),
                                                    Text(_date(item.time),
                                                        style: const TextStyle(
                                                            color:
                                                                DashboardTheme
                                                                    .muted,
                                                            fontSize: 11)),
                                                  ])),
                                        ));
                                  },
                                )),
                ]);
          },
        ),
      ));
}
