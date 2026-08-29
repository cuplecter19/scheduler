import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/scheduled_task.dart';
import '../../main.dart';
import '../../theme/app_colors.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final tasks = state.visibleTasks();
    return Scaffold(
      body: Column(
        children: <Widget>[
          blueHeader(
            title: '오늘의 할 일',
            subtitle: '${tasks.where((task) => !task.isCompleted).length}개 남음 · ${DateFormat('M월 d일 EEEE', 'ko_KR').format(DateTime.now())}',
            trailing: IconButton.filledTonal(
              onPressed: state.syncNow,
              icon: const Icon(Icons.sync),
              color: Colors.white,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: SegmentedButton<TaskSort>(
                    segments: const <ButtonSegment<TaskSort>>[
                      ButtonSegment(value: TaskSort.dueDate, label: Text('마감일순'), icon: Icon(Icons.event)),
                      ButtonSegment(value: TaskSort.priority, label: Text('우선순위'), icon: Icon(Icons.flag)),
                    ],
                    selected: <TaskSort>{state.sort},
                    onSelectionChanged: (selected) => state.setSort(selected.first),
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  selected: state.hideCompleted,
                  label: const Text('완료 숨김'),
                  onSelected: state.setHideCompleted,
                ),
              ],
            ),
          ),
          Expanded(
            child: tasks.isEmpty
                ? const Center(child: Text('할 일을 추가해 하루를 구조화하세요.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) => _TaskCard(task: tasks[index], state: state),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTaskEditor(context, state),
        icon: const Icon(Icons.add),
        label: const Text('할 일'),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.state});

  final ScheduledTask task;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final due = task.dueDate == null ? '마감일 없음' : DateFormat('M/d HH:mm').format(task.dueDate!);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => showTaskEditor(context, state, task: task),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Checkbox(
                value: task.isCompleted,
                onChanged: (value) => state.saveTask(task.copyWith(isCompleted: value ?? false)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (task.note.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(task.note, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: <Widget>[
                        _Pill(icon: Icons.event, label: due),
                        _Pill(icon: Icons.flag, label: _priorityLabel(task.priority), color: _priorityColor(task.priority)),
                        for (final tag in task.tags) _Pill(icon: Icons.tag, label: tag),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => state.removeTask(task),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.color = AppColors.primary});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

Future<void> showTaskEditor(BuildContext context, AppState state, {ScheduledTask? task}) async {
  final title = TextEditingController(text: task?.title ?? '');
  final note = TextEditingController(text: task?.note ?? '');
  final tags = TextEditingController(text: task?.tags.join(', ') ?? '');
  var priority = task?.priority ?? TaskPriority.medium;
  var dueDate = task?.dueDate;
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
              Text(task == null ? '할 일 추가' : '할 일 수정', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextField(controller: title, decoration: const InputDecoration(labelText: '제목')),
              const SizedBox(height: 12),
              TextField(controller: note, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '메모')),
              const SizedBox(height: 12),
              TextField(controller: tags, decoration: const InputDecoration(labelText: '태그 (쉼표로 구분)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<TaskPriority>(
                initialValue: priority,
                decoration: const InputDecoration(labelText: '우선순위'),
                items: TaskPriority.values.map((value) => DropdownMenuItem(value: value, child: Text(_priorityLabel(value)))).toList(),
                onChanged: (value) => setState(() => priority = value ?? priority),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(dueDate == null ? '마감일 없음' : DateFormat('yyyy.MM.dd HH:mm').format(dueDate!)),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final now = DateTime.now();
                  final date = await showDatePicker(
                    context: context,
                    initialDate: dueDate ?? now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 5),
                  );
                  if (date == null || !context.mounted) return;
                  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(dueDate ?? now));
                  setState(() => dueDate = DateTime(date.year, date.month, date.day, time?.hour ?? 9, time?.minute ?? 0));
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        if (title.text.trim().isEmpty) return;
                        final now = DateTime.now();
                        final edited = ScheduledTask(
                          id: task?.id ?? state.newId(),
                          title: title.text.trim(),
                          note: note.text.trim(),
                          dueDate: dueDate,
                          priority: priority,
                          tags: tags.text.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList(),
                          isCompleted: task?.isCompleted ?? false,
                          updatedAt: now,
                          deviceId: state.deviceId,
                        );
                        await state.saveTask(edited);
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('저장'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _priorityLabel(TaskPriority priority) => switch (priority) {
      TaskPriority.low => '낮음',
      TaskPriority.medium => '보통',
      TaskPriority.high => '높음',
    };

Color _priorityColor(TaskPriority priority) => switch (priority) {
      TaskPriority.low => AppColors.success,
      TaskPriority.medium => AppColors.primary,
      TaskPriority.high => AppColors.danger,
    };
