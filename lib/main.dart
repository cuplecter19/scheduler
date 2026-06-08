import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:uuid/uuid.dart';

import 'core/db/app_database.dart';
import 'core/models/scheduled_task.dart';
import 'core/models/time_block.dart';
import 'core/sync/sync_engine.dart';
import 'features/settings/settings_screen.dart';
import 'features/tasks/tasks_screen.dart';
import 'features/timeblock/timeblock_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');
  final database = await AppDatabase.open();
  final state = AppState(database: database, syncEngine: SyncEngine(database: database));
  await state.load();
  runApp(StructuredCloneApp(state: state));
}

class StructuredCloneApp extends StatefulWidget {
  const StructuredCloneApp({super.key, required this.state});

  final AppState state;

  @override
  State<StructuredCloneApp> createState() => _StructuredCloneAppState();
}

class _StructuredCloneAppState extends State<StructuredCloneApp> {
  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      child: MaterialApp(
        title: 'Structured Scheduler',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(widget.state.fontScale),
        home: const ShellScreen(),
      ),
    );
  }
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.state, required super.child});

  final AppState state;

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.state;

  @override
  bool updateShouldNotify(AppScope oldWidget) => state != oldWidget.state;
}

class AppState extends ChangeNotifier {
  AppState({required this.database, required this.syncEngine});

  final AppDatabase database;
  final SyncEngine syncEngine;
  final _uuid = const Uuid();

  List<ScheduledTask> tasks = <ScheduledTask>[];
  List<TimeBlock> blocks = <TimeBlock>[];
  double fontScale = 1;
  bool hideCompleted = false;
  TaskSort sort = TaskSort.dueDate;
  String syncMessage = '동기화 대기 중';
  late final String deviceId;

  Future<void> load() async {
    deviceId = await database.getSetting('device_id') ?? _uuid.v4();
    await database.setSetting('device_id', deviceId);
    fontScale = double.tryParse(await database.getSetting('font_scale') ?? '') ?? 1;
    hideCompleted = (await database.getSetting('hide_completed')) == 'true';
    final savedSort = await database.getSetting('task_sort');
    sort = TaskSort.values.firstWhere(
      (value) => value.name == savedSort,
      orElse: () => TaskSort.dueDate,
    );
    await reloadData();
  }

  Future<void> reloadData() async {
    tasks = await database.getTasks();
    blocks = await database.getTimeBlocks();
    notifyListeners();
  }

  List<ScheduledTask> visibleTasks() {
    final visible = tasks.where((task) => !hideCompleted || !task.isCompleted).toList();
    if (sort == TaskSort.priority) {
      visible.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    } else {
      visible.sort((a, b) {
        final ad = a.dueDate;
        final bd = b.dueDate;
        if (ad == null && bd == null) return a.title.compareTo(b.title);
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
    }
    return visible;
  }

  List<TimeBlock> blocksForDay(DateTime day) {
    return blocks.where((block) => _sameDay(block.startAt, day)).toList()..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  Future<void> saveTask(ScheduledTask task) async {
    await database.upsertTask(task.copyWith(updatedAt: DateTime.now(), deviceId: deviceId));
    await reloadData();
  }

  Future<void> removeTask(ScheduledTask task) async {
    await database.deleteTask(task.copyWith(deviceId: deviceId));
    await reloadData();
  }

  Future<void> saveBlock(TimeBlock block) async {
    await database.upsertTimeBlock(block.copyWith(updatedAt: DateTime.now(), deviceId: deviceId));
    await reloadData();
  }

  Future<void> removeBlock(TimeBlock block) async {
    await database.deleteTimeBlock(block.copyWith(deviceId: deviceId));
    await reloadData();
  }

  Future<void> setFontScale(double value) async {
    fontScale = value;
    await database.setSetting('font_scale', value.toString());
    notifyListeners();
  }

  Future<void> setHideCompleted(bool value) async {
    hideCompleted = value;
    await database.setSetting('hide_completed', value.toString());
    notifyListeners();
  }

  Future<void> setSort(TaskSort value) async {
    sort = value;
    await database.setSetting('task_sort', value.name);
    notifyListeners();
  }

  Future<void> syncNow() async {
    syncMessage = '동기화 중...';
    notifyListeners();
    try {
      syncMessage = await syncEngine.syncNow();
      await reloadData();
    } catch (error) {
      syncMessage = '동기화 실패: $error';
    }
    notifyListeners();
  }

  String newId() => _uuid.v4();
}

enum TaskSort { dueDate, priority }

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final pages = <Widget>[
      TasksScreen(state: state),
      TimeBlockScreen(state: state),
      SettingsScreen(state: state),
    ];
    return Scaffold(
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.check_circle_outline), selectedIcon: Icon(Icons.check_circle), label: '할 일'),
          NavigationDestination(icon: Icon(Icons.calendar_view_day_outlined), selectedIcon: Icon(Icons.calendar_view_day), label: '타임블록'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '설정'),
        ],
      ),
      floatingActionButton: index == 2
          ? FloatingActionButton.small(onPressed: state.syncNow, child: const Icon(Icons.sync))
          : null,
    );
  }
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

Widget blueHeader({required String title, required String subtitle, Widget? trailing}) {
  return Container(
    margin: const EdgeInsets.fromLTRB(20, 20, 20, 12),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: <Color>[AppColors.primary, AppColors.secondary]),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    ),
  );
}
