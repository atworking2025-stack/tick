import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const App());

const seed = Color(0xFF4772FA);

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Вазифалар',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
        darkTheme: ThemeData(
            colorSchemeSeed: seed,
            brightness: Brightness.dark,
            useMaterial3: true),
        home: const Home(),
      );
}

class Task {
  String id, title, list;
  bool done;
  int priority; // 0 - йўқ, 1 - паст, 2 - ўрта, 3 - юқори
  DateTime? due;

  Task({
    required this.id,
    required this.title,
    this.list = 'Умумий',
    this.done = false,
    this.priority = 0,
    this.due,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'list': list,
        'done': done,
        'priority': priority,
        'due': due?.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'],
        title: j['title'],
        list: j['list'] ?? 'Умумий',
        done: j['done'] ?? false,
        priority: j['priority'] ?? 0,
        due: j['due'] == null ? null : DateTime.parse(j['due']),
      );
}

const lists = ['Умумий', 'Иш', 'Шахсий', 'Харид'];
const prColors = [Colors.grey, Colors.blue, Colors.orange, Colors.red];

String fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Task> tasks = [];
  int tab = 0;
  String? listFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('tasks');
    if (s != null) {
      setState(() => tasks = (jsonDecode(s) as List)
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList());
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('tasks', jsonEncode(tasks.map((t) => t.toJson()).toList()));
  }

  List<Task> get visible {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    var r = tasks.where((t) {
      if (listFilter != null && t.list != listFilter) return false;
      if (tab == 0) return !t.done && t.due != null && t.due!.isBefore(tomorrow);
      if (tab == 1) return !t.done;
      return t.done;
    }).toList();
    r.sort((a, b) {
      final da = a.due ?? DateTime(2100), db = b.due ?? DateTime(2100);
      final c = da.compareTo(db);
      return c != 0 ? c : b.priority.compareTo(a.priority);
    });
    return r;
  }

  void _edit([Task? t]) {
    final ctrl = TextEditingController(text: t?.title ?? '');
    var pr = t?.priority ?? 0;
    var list = t?.list ?? (listFilter ?? lists.first);
    DateTime? due = t?.due ?? (tab == 0 ? DateTime.now() : null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                    hintText: 'Вазифа номи...', border: InputBorder.none),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final l in lists)
                    ChoiceChip(
                      label: Text(l),
                      selected: l == list,
                      onSelected: (_) => set(() => list = l),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: Text('Йўқ')),
                  ButtonSegment(value: 1, label: Text('Паст')),
                  ButtonSegment(value: 2, label: Text('Ўрта')),
                  ButtonSegment(value: 3, label: Text('Юқори')),
                ],
                selected: {pr},
                onSelectionChanged: (s) => set(() => pr = s.first),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(due == null ? 'Муддат' : fmt(due!)),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: due ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) set(() => due = d);
                    },
                  ),
                  if (due != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => set(() => due = null),
                    ),
                  const Spacer(),
                  FilledButton(
                    child: const Text('Сақлаш'),
                    onPressed: () {
                      final s = ctrl.text.trim();
                      if (s.isEmpty) return;
                      setState(() {
                        if (t == null) {
                          tasks.add(Task(
                            id: DateTime.now().microsecondsSinceEpoch.toString(),
                            title: s,
                            list: list,
                            priority: pr,
                            due: due,
                          ));
                        } else {
                          t
                            ..title = s
                            ..list = list
                            ..priority = pr
                            ..due = due;
                        }
                      });
                      _save();
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = visible;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(
        title: Text(['Бугун', 'Барчаси', 'Бажарилган'][tab]),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Рўйхат',
            onSelected: (v) => setState(() => listFilter = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('Барча рўйхатлар')),
              for (final l in lists) PopupMenuItem(value: l, child: Text(l)),
            ],
          ),
        ],
        bottom: listFilter == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(36),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InputChip(
                      label: Text(listFilter!),
                      onDeleted: () => setState(() => listFilter = null),
                    ),
                  ),
                ),
              ),
      ),
      body: items.isEmpty
          ? Center(
              child: Text(
                tab == 2 ? 'Ҳали бажарилганлар йўқ' : 'Вазифалар йўқ 🎉',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final t = items[i];
                final overdue = !t.done && t.due != null && t.due!.isBefore(today);
                return Dismissible(
                  key: ValueKey(t.id),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) {
                    setState(() => tasks.remove(t));
                    _save();
                  },
                  child: ListTile(
                    onTap: () => _edit(t),
                    leading: Checkbox(
                      value: t.done,
                      shape: const CircleBorder(),
                      side: BorderSide(color: prColors[t.priority], width: 2),
                      onChanged: (v) {
                        setState(() => t.done = v ?? false);
                        _save();
                      },
                    ),
                    title: Text(
                      t.title,
                      style: TextStyle(
                        decoration: t.done ? TextDecoration.lineThrough : null,
                        color: t.done ? Colors.grey : null,
                      ),
                    ),
                    subtitle: Text(
                      [if (t.due != null) fmt(t.due!), t.list].join('  •  '),
                      style: TextStyle(color: overdue ? Colors.red : null),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton:
          FloatingActionButton(onPressed: _edit, child: const Icon(Icons.add)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: 'Бугун'),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Барчаси'),
          NavigationDestination(icon: Icon(Icons.done_all), label: 'Бажарилган'),
        ],
      ),
    );
  }
}
