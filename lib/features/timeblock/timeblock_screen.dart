import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/time_block.dart';
import '../../main.dart';
import '../../theme/app_colors.dart';

class TimeBlockScreen extends StatefulWidget {
  const TimeBlockScreen({super.key, required this.state});

  final AppState state;

  @override
  State<TimeBlockScreen> createState() => _TimeBlockScreenState();
}

class _TimeBlockScreenState extends State<TimeBlockScreen> {
  DateTime selectedDay = DateTime.now();
  bool weekMode = false;

  @override
  Widget build(BuildContext context) {
    final title = DateFormat('M월 d일 EEEE', 'ko_KR').format(selectedDay);
    return Scaffold(
      body: Column(
        children: <Widget>[
          blueHeader(
            title: '타임블록',
            subtitle: weekMode ? '주간 보기' : title,
            trailing: IconButton.filledTonal(
              onPressed: () => setState(() => weekMode = !weekMode),
              icon: Icon(weekMode ? Icons.view_day : Icons.view_week),
              color: Colors.white,
            ),
          ),
          _DaySelector(
            selectedDay: selectedDay,
            onChanged: (day) => setState(() => selectedDay = day),
          ),
          Expanded(child: weekMode ? _WeekView(state: widget.state, selectedDay: selectedDay) : _DayTimeline(state: widget.state, selectedDay: selectedDay)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBlockEditor(context, widget.state, day: selectedDay),
        icon: const Icon(Icons.add),
        label: const Text('블록'),
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({required this.selectedDay, required this.onChanged});

  final DateTime selectedDay;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 14,
        itemBuilder: (context, index) {
          final day = DateTime.now().subtract(const Duration(days: 3)).add(Duration(days: index));
          final selected = _sameDay(day, selectedDay);
          return Padding(
            padding: const EdgeInsets.all(4),
            child: ChoiceChip(
              selected: selected,
              label: SizedBox(
                width: 54,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(DateFormat('E', 'ko_KR').format(day)),
                    Text('${day.day}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              onSelected: (_) => onChanged(day),
            ),
          );
        },
      ),
    );
  }
}

class _DayTimeline extends StatelessWidget {
  const _DayTimeline({required this.state, required this.selectedDay});

  final AppState state;
  final DateTime selectedDay;

  @override
  Widget build(BuildContext context) {
    final blocks = state.blocksForDay(selectedDay);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: 24,
      itemBuilder: (context, hour) {
        final hourBlocks = blocks.where((block) => block.startAt.hour == hour).toList();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(width: 54, child: Text('${hour.toString().padLeft(2, '0')}:00', style: const TextStyle(color: Colors.black54))),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 68),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
                child: Column(children: hourBlocks.map((block) => _BlockTile(block: block, state: state)).toList()),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({required this.state, required this.selectedDay});

  final AppState state;
  final DateTime selectedDay;

  @override
  Widget build(BuildContext context) {
    final start = selectedDay.subtract(Duration(days: selectedDay.weekday - 1));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: 7,
      itemBuilder: (context, index) {
        final day = start.add(Duration(days: index));
        final blocks = state.blocksForDay(day);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(DateFormat('M/d EEEE', 'ko_KR').format(day), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 8),
                if (blocks.isEmpty) const Text('블록 없음') else ...blocks.map((block) => _BlockTile(block: block, state: state)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({required this.block, required this.state});

  final TimeBlock block;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(block.colorHex);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withOpacity(0.25))),
      child: ListTile(
        onTap: () => showBlockEditor(context, state, block: block, day: block.startAt),
        leading: Container(width: 5, height: 42, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99))),
        title: Text(block.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${DateFormat('HH:mm').format(block.startAt)} - ${DateFormat('HH:mm').format(block.endAt)}${block.note.isEmpty ? '' : ' · ${block.note}'}'),
        trailing: IconButton(onPressed: () => state.removeBlock(block), icon: const Icon(Icons.delete_outline)),
      ),
    );
  }
}

Future<void> showBlockEditor(BuildContext context, AppState state, {TimeBlock? block, required DateTime day}) async {
  final title = TextEditingController(text: block?.title ?? '');
  final note = TextEditingController(text: block?.note ?? '');
  var start = block?.startAt ?? DateTime(day.year, day.month, day.day, 9);
  var end = block?.endAt ?? start.add(const Duration(hours: 1));
  var color = block?.colorHex ?? '#2D7FF9';
  var taskId = block?.taskId;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(block == null ? '타임블록 추가' : '타임블록 수정', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextField(controller: title, decoration: const InputDecoration(labelText: '제목')),
              const SizedBox(height: 12),
              TextField(controller: note, decoration: const InputDecoration(labelText: '메모')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: taskId,
                decoration: const InputDecoration(labelText: '연결할 할 일'),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem(value: null, child: Text('연결 없음')),
                  ...state.tasks.map((task) => DropdownMenuItem(value: task.id, child: Text(task.title))),
                ],
                onChanged: (value) => setState(() => taskId = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _TimeButton(
                      label: '시작',
                      time: start,
                      onTap: () async {
                        final next = await _pickTime(context, start);
                        setState(() => start = next);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeButton(
                      label: '종료',
                      time: end,
                      onTap: () async {
                        final next = await _pickTime(context, end);
                        setState(() => end = next);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: AppColors.blockPalette.map((candidate) {
                  final hex = _colorToHex(candidate);
                  return ChoiceChip(
                    selected: color == hex,
                    label: Text(hex),
                    avatar: CircleAvatar(backgroundColor: candidate),
                    onSelected: (_) => setState(() => color = hex),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (title.text.trim().isEmpty) return;
                  if (!end.isAfter(start)) end = start.add(const Duration(minutes: 30));
                  await state.saveBlock(TimeBlock(
                    id: block?.id ?? state.newId(),
                    title: title.text.trim(),
                    taskId: taskId,
                    note: note.text.trim(),
                    startAt: start,
                    endAt: end,
                    colorHex: color,
                    updatedAt: DateTime.now(),
                    deviceId: state.deviceId,
                  ));
                  if (context.mounted) Navigator.pop(context);
                },
                child: const SizedBox(width: double.infinity, child: Center(child: Text('저장'))),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.label, required this.time, required this.onTap});
  final String label;
  final DateTime time;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(onPressed: onTap, icon: const Icon(Icons.schedule), label: Text('$label ${DateFormat('HH:mm').format(time)}'));
}

Future<DateTime> _pickTime(BuildContext context, DateTime value) async {
  final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(value));
  return picked == null ? value : DateTime(value.year, value.month, value.day, picked.hour, picked.minute);
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
Color _hexToColor(String hex) => Color(int.parse(hex.replaceFirst('#', '0xff')));
String _colorToHex(Color color) => '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
