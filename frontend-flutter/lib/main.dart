import 'package:material_ui/material_ui.dart';
import 'core/theme.dart';
import 'data/catalog_repository.dart';
import 'data/local_store.dart';
import 'data/study_ledger.dart';
import 'features/study/lesson_page.dart';
import 'features/account/account_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HhkApp());
}

class HhkApp extends StatelessWidget {
  const HhkApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Học Hứng Khởi',
        theme: HhkTheme.light,
        debugShowCheckedModeBanner: false,
        home: const HomeScreen(),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CatalogRepository repository = CatalogRepository();
  final LocalStore store = createLocalStore();
  late final StudyLedger ledger = StudyLedger(store);
  int grade = 3;
  int tab = 0;
  bool initialized = false;
  StudentProfile? activeProfile;
  List<StudentProfile> profiles = [];
  String? initializationError;
  late Future<GradePack> currentPack = repository.loadGrade(grade);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      await store.open();
      await ledger.initialize();
      final profile = await ledger.activeProfile();
      final all = await ledger.listProfiles();
      if (mounted) {
        setState(() {
          activeProfile = profile;
          profiles = all;
          grade = profile.grade;
          currentPack = repository.loadGrade(grade);
          initialized = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          initialized = true;
          initializationError =
              'Không mở được dữ liệu học tập trên thiết bị. Hãy kiểm tra bộ nhớ và thử khởi động lại.';
        });
      }
    }
  }

  Future<void> _selectGrade(int value) async {
    final current = activeProfile;
    if (current == null) return;
    try {
      final next = await ledger.changeGrade(current.id, value);
      if (mounted) {
        setState(() {
          activeProfile = next;
          profiles = profiles.map((p) => p.id == next.id ? next : p).toList();
          grade = value;
          currentPack = repository.loadGrade(value);
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không lưu được lớp học offline.')));
      }
    }
  }

  Future<void> _switchProfile(String id) async {
    try {
      final next = await ledger.selectProfile(id);
      if (mounted) {
        setState(() {
          activeProfile = next;
          grade = next.grade;
          currentPack = repository.loadGrade(grade);
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không chọn được hồ sơ.')));
      }
    }
  }

  Future<void> _createProfile() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Thêm hồ sơ học sinh'),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLength: 32,
                decoration: const InputDecoration(labelText: 'Tên học sinh'),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Hủy')),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(dialogContext, controller.text),
                    child: const Text('Lưu offline'))
              ],
            ));
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      final next = await ledger.createProfile(name, grade);
      final all = await ledger.listProfiles();
      if (mounted) {
        setState(() {
          activeProfile = next;
          profiles = all;
          grade = next.grade;
          currentPack = repository.loadGrade(grade);
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tạo được hồ sơ offline.')));
      }
    }
  }

  @override
  void dispose() {
    store.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_homePage(), _curriculumPage(), const AccountPage(), _settingsPage()];
    return Scaffold(
      appBar: AppBar(
          title: const Row(children: [
            Icon(Icons.auto_stories_rounded, color: HhkTheme.orange),
            SizedBox(width: 8),
            Text('HHK CAP-01', style: TextStyle(fontWeight: FontWeight.w800)),
          ]),
          actions: [
            if (activeProfile != null)
              PopupMenuButton<String>(
                tooltip: 'Chọn hồ sơ học sinh',
                onSelected: (id) {
                  if (id == 'create') {
                    _createProfile();
                  } else {
                    _switchProfile(id);
                  }
                },
                itemBuilder: (_) => [
                  for (final profile in profiles)
                    PopupMenuItem(
                      value: profile.id,
                      child: Text('${profile.name} • Lớp ${profile.grade}'),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                      value: 'create', child: Text('Thêm hồ sơ')),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                      child: Text('${activeProfile!.name} • Lớp $grade')),
                ),
              ),
          ]),
      body: SafeArea(
          child: !initialized
              ? const Center(child: CircularProgressIndicator())
              : initializationError != null
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(initializationError!, textAlign: TextAlign.center)))
                  : IndexedStack(index: tab, children: pages)),
      bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (value) => setState(() => tab = value),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Trang chủ'),
            NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: 'Môn học'),
            NavigationDestination(
                icon: Icon(Icons.manage_accounts_outlined),
                selectedIcon: Icon(Icons.manage_accounts),
                label: 'Tài khoản'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Cài đặt'),
          ]),
    );
  }

  Widget _homePage() => ListView(padding: const EdgeInsets.all(16), children: [
        Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                color: const Color(0xFFFFE0BF),
                borderRadius: BorderRadius.circular(24)),
            child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Học vui mỗi ngày',
                      style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                          color: HhkTheme.teal)),
                  SizedBox(height: 8),
                  Text(
                      'Bài học, luyện tập và ôn tập đều chạy trên điện thoại.'),
                  SizedBox(height: 6),
                  Text(
                      'Không cần Chat AI • Không gửi điểm từng câu lên máy chủ',
                      style: TextStyle(fontSize: 12)),
                ])),
        const SizedBox(height: 12),
        if (activeProfile != null)
          FutureBuilder<int>(
              future: ledger.totalXp(activeProfile!.id),
              builder: (context, snapshot) => Card(
                    child: ListTile(
                        leading: const Icon(Icons.emoji_events_outlined),
                        title: Text('Hồ sơ: ${activeProfile!.name}'),
                        subtitle: Text('XP tích lũy: ${snapshot.data ?? 0}'),
                        trailing: TextButton(
                            onPressed: _createProfile,
                            child: const Text('Thêm học sinh'))),
                  )),
        const SizedBox(height: 22),
        Text('Chọn lớp', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (var i = 1; i <= 5; i++)
            ChoiceChip(
                label: Text('Lớp $i'),
                selected: grade == i,
                onSelected: (_) => _selectGrade(i)),
        ]),
        const SizedBox(height: 20),
        FutureBuilder<GradePack>(
            future: currentPack,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Lỗi tải nội dung: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final pack = snapshot.data!;
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Môn học • Lớp $grade',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    if (pack.subjects.isEmpty || pack.lessons.isEmpty)
                      const Card(
                          child: Padding(
                              padding: EdgeInsets.all(18),
                              child: Text(
                                  'Đang chờ nhập dữ liệu giáo trình đã được kiểm tra từ repo nguồn.')))
                    else
                      ...pack.subjects
                          .where((s) => pack
                              .lessonsFor(s['code']?.toString() ?? '')
                              .isNotEmpty)
                          .map((s) => Card(
                                  child: ListTile(
                                leading: CircleAvatar(
                                    child:
                                        Text(s['emoji']?.toString() ?? '📚')),
                                title: Text(s['name']?.toString() ?? 'Môn học'),
                                subtitle: Text(
                                    '${pack.lessonsFor(s['code'].toString()).length} bài học'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _openSubject(pack, s),
                              ))),
                    const SizedBox(height: 10),
                    const Text(
                        'Bản dựng Flutter dùng để kiểm thử kiến trúc. Chưa phát hành giấy phép thương mại.',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ]);
            }),
      ]);

  Widget _curriculumPage() => FutureBuilder<GradePack>(
      future: currentPack,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final pack = snapshot.data!;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('Bài học lớp $grade',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          if (pack.lessons.isEmpty)
            const Text(
                'Chưa có dữ liệu thực. Chạy import-source GitHub Actions.')
          else
            for (final subject in pack.subjects)
              if (pack.lessonsFor(subject['code']?.toString() ?? '').isNotEmpty)
                Card(
                    child: ListTile(
                  title: Text(subject['name']?.toString() ?? ''),
                  subtitle: Text(
                      '${pack.lessonsFor(subject['code'].toString()).length} bài học'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _openSubject(pack, subject),
                )),
        ]);
      });

  Widget _settingsPage() =>
      ListView(padding: const EdgeInsets.all(16), children: [
        if (activeProfile != null)
          FutureBuilder<List<SubjectStatistics>>(
            future: ledger.subjectStatistics(activeProfile!.id, grade),
            builder: (context, snapshot) => Card(
              child: ListTile(
                leading: const Icon(Icons.bar_chart),
                title: Text('Thống kê • ${activeProfile!.name} • Lớp $grade'),
                subtitle: Text(snapshot.hasData
                    ? '${snapshot.data!.fold<int>(0, (s, x) => s + x.lessonsPractised)} bài đã luyện • ${snapshot.data!.fold<int>(0, (s, x) => s + x.attempts)} lượt'
                    : 'Đang đọc tiến độ local'),
              ),
            ),
          ),
        const Card(
            child: ListTile(
                leading: Icon(Icons.offline_bolt, color: HhkTheme.teal),
                title: Text('Học offline'),
                subtitle: Text('SQLite Android/iOS • IndexedDB Web'))),
        const Card(
            child: ListTile(
                leading: Icon(Icons.key_outlined),
                title: Text('Quản lý key trong tài khoản'),
                subtitle: Text(
                    'Mở tab Tài khoản để đăng nhập, quét QR và quản lý key.'))),
        const Card(
            child: ListTile(
                leading: Icon(Icons.privacy_tip_outlined),
                title: Text('Quyền riêng tư'),
                subtitle:
                    Text('Không tự đồng bộ dữ liệu học sinh lên máy chủ.'))),
      ]);

  void _openSubject(GradePack pack, Map<String, dynamic> subject) {
    final lessons = pack.lessonsFor(subject['code']?.toString() ?? '');
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (context) => Scaffold(
              appBar:
                  AppBar(title: Text(subject['name']?.toString() ?? 'Môn học')),
              body: ListView.builder(
                  itemCount: lessons.length,
                  itemBuilder: (context, i) {
                    final lesson = lessons[i];
                    return Card(
                        child: ListTile(
                      leading: CircleAvatar(child: Text('${i + 1}')),
                      title: Text(lesson['title']?.toString() ?? 'Bài học'),
                      subtitle: Text(lesson['summarySimple']?.toString() ?? '',
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => LessonPage(
                                  pack: pack,
                                  lesson: lesson,
                                  ledger: ledger,
                                  profileId: activeProfile!.id))),
                    ));
                  }),
            )));
  }
}
