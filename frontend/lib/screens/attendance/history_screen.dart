import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../models/attendance_session.dart';
import '../../providers/class_provider.dart';
import '../../services/attendance_service.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/common/status_badge.dart';

/// Attendance history with class / date / subject filters.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int? _classId;
  DateTime? _from;
  DateTime? _to;
  final _subject = TextEditingController();

  List<HistoryItem> _items = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final classes = context.read<ClassProvider>();
      if (classes.classes.isEmpty) classes.load();
      _load();
    });
  }

  @override
  void dispose() {
    _subject.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _items = await context.read<AttendanceService>().history(
            classId: _classId,
            from: _from,
            to: _to,
            subject: _subject.text,
          );
    } catch (e) {
      _error = 'Could not load history.';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<ClassProvider>();
    final dateFmt = DateFormat('dd MMM yyyy');
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int>(
                    initialValue: _classId,
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                          value: null, child: Text('All classes')),
                      ...classes.visible.map((c) =>
                          DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.name} ${c.section}'))),
                    ],
                    onChanged: (v) {
                      setState(() => _classId = v);
                      _load();
                    },
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(_from == null
                      ? 'From'
                      : dateFmt.format(_from!)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _from ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _from = picked);
                      _load();
                    }
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                      _to == null ? 'To' : dateFmt.format(_to!)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _to ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _to = picked);
                      _load();
                    }
                  },
                ),
                if (_from != null || _to != null || _classId != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _from = null;
                        _to = null;
                        _classId = null;
                      });
                      _load();
                    },
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          Expanded(child: _body(dateFmt)),
        ],
      ),
    );
  }

  Widget _body(DateFormat dateFmt) {
    if (_loading && _items.isEmpty) {
      return const LoadingView(message: 'Loading history…');
    }
    if (_error != null && _items.isEmpty) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      return const EmptyView(
        message: 'No attendance sessions match these filters.',
        icon: Icons.history_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final s = _items[i];
          final finalized =
              s.status == 'finalized';
          return Card(
            child: ListTile(
              leading: SessionStatusBadge(
                  status: sessionStatusFrom(s.status)),
              title: Text(
                  '${s.className} ${s.section} · ${s.subject}'),
              subtitle: Text(
                '${dateFmt.format(s.date)} · Present ${s.present}/${s.total}'
                '${s.needsReview > 0 ? ' · ${s.needsReview} need review' : ''}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pushNamed(
                finalized
                    ? RouteNames.sessionDetail(s.id)
                    : RouteNames.reviewSession(s.id),
              ),
            ),
          );
        },
      ),
    );
  }
}
