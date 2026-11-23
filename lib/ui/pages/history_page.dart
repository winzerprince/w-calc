import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_settings.dart';
import '../../app/calc_model.dart';
import '../../app/history_store.dart';
import '../haptics.dart';
import '../reading_theme.dart';

/// Calculation history, one tab per calculator model: time, calculation,
/// answer. Tap to copy the answer. A switch keeps it on the device or not.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, this.modelId});

  /// Model to show first (the one in use).
  final String? modelId;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String? _modelId;

  String get _model => _modelId!;
  set _model(String v) => _modelId = v;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _modelId ??= widget.modelId ?? ModelScope.of(context).id;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _day(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(t.year, t.month, t.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${d.year}-${_two(d.month)}-${_two(d.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final store = HistoryStore.instance;
    final settings = SettingsScope.of(context);
    return AppPageTheme(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final scheme = Theme.of(context).colorScheme;
          final models = {_model, ...store.models}.map(CalcModel.byId).toList();
          final items = store.of(_model).reversed.toList();
          return Scaffold(
            appBar: AppBar(
              title: const Text('History'),
              actions: [
                IconButton(
                  key: const Key('history-clear'),
                  tooltip: 'Clear this history',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: items.isEmpty
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (d) => AlertDialog(
                              title: const Text('Clear history?'),
                              content: Text(
                                'All calculations on '
                                '${CalcModel.byId(_model).name} are removed.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(d, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(d, true),
                                  child: const Text('Clear'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) store.clear(_model);
                        },
                ),
              ],
            ),
            body: Column(
              children: [
                SwitchListTile(
                  key: const Key('history-save'),
                  secondary: const Icon(Icons.save_outlined),
                  title: const Text('Save history on this device'),
                  subtitle: Text(
                    settings.saveHistory
                        ? 'Kept between sessions, separately for each model'
                        : 'Off: nothing is stored; this list goes when the app closes',
                  ),
                  value: settings.saveHistory,
                  onChanged: (v) {
                    keyVibration();
                    settings.update(saveHistory: v);
                    store.setPersist(v);
                  },
                ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final m in models)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            key: Key('history-model-${m.id}'),
                            label: Text(m.name),
                            selected: m.id == _model,
                            onSelected: (_) => setState(() => _model = m.id),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Text(
                            'No calculations yet on '
                            '${CalcModel.byId(_model).name}.',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        )
                      : ListView.builder(
                          key: const Key('history-items'),
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final it = items[i];
                            final header =
                                i == 0 ||
                                _day(items[i - 1].time) != _day(it.time);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (header)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      14,
                                      16,
                                      4,
                                    ),
                                    child: Text(
                                      _day(it.time),
                                      style: TextStyle(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ListTile(
                                  leading: Text(
                                    '${_two(it.time.hour)}:${_two(it.time.minute)}',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  title: Text(it.input),
                                  trailing: Text(
                                    it.result,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: it.result),
                                    );
                                    keyVibration();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Copied ${it.result}'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
