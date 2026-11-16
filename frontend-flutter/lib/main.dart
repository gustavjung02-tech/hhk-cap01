import 'package:material_ui/material_ui.dart';
import 'core/theme.dart';
import 'data/catalog_repository.dart';
import 'data/account_api.dart';
import 'data/local_store.dart';
import 'data/study_ledger.dart';
import 'data/offline_license.dart';
import 'features/study/lesson_page.dart';
import 'features/account/account_page.dart';
import 'features/auth_gateway.dart';
import 'features/legacy_feature_drawer.dart';
import 'features/local_progress_page.dart';
import 'features/study/practice_page.dart';
import 'features/study/quiz_evaluator.dart';
import 'widgets/compact_bottom_navigation_bar.dart';

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
        home: AuthGateway(
          buildApp: (session, signOut, api) => HomeScreen(
            session: session, onSignedOut: signOut, api: api),
        ),
      );
}

class HomeScreen extends StatefulWidget {
  final AccountSession session;
  final Future<void> Function() onSignedOut;
  final AccountApi api;
  const HomeScreen({super.key, required this.session,
    required this.onSignedOut, required this.api});
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
  final OfflineLicenseManager offline = OfflineLicenseManager();
  late Future<bool> gradeEntitled = offline.gradeAllowed(grade);
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
          gradeEntitled = offline.gradeAllowed(grade);
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
          gradeEntitled = offline.gradeAllowed(value);
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
          gradeEntitled = offline.gradeAllowed(grade);
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

  Future<void> _refreshLicense() async {
    if (mounted) setState(() => gradeEntitled = offline.gradeAllowed(grade));
  }

  @override
  void dispose() {
    store.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_homePage(), _curriculumPage(), _practiceHubPage(), _settingsPage()];
    return Scaffold(
      drawer: LegacyFeatureDrawer(
        profileName: activeProfile?.name ?? 'Học sinh',
        grade: grade,
        onSelect: _openLegacyFeature,
      ),
      appBar: AppBar(
        leading: Builder(builder: (context) => IconButton(
          key: const Key('open-feature-menu'),
          tooltip: 'Mở menu tính năng',
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        )),
        title: const Text('Học Hứng Khởi',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            key: const Key('open-account'),
            tooltip: 'Tài khoản & key',
            icon: const Icon(Icons.account_circle_outlined, size: 26),
            onPressed: _openAccount,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
          child: !initialized
              ? const Center(child: CircularProgressIndicator())
              : initializationError != null
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(initializationError!, textAlign: TextAlign.center)))
                  : IndexedStack(index: tab, children: pages)),
      // NavigationBar owns the system bottom safe area; do not wrap it again.
      bottomNavigationBar: CompactBottomNavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
      ),
    );
  }

  Widget _homePage() => ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          constraints: const BoxConstraints(minHeight: 210),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            image: const DecorationImage(
              image: AssetImage('assets/brand/landing-hero.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xD9163F39), Color(0x770F524A),
                  Color(0x120F524A)],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Học vui mỗi ngày',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 10),
                Text('Cùng Dopi khám phá kiến thức lớp $grade nhé!',
                    style: const TextStyle(fontSize: 16, color: Colors.white)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => setState(() => tab = 1),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Tiếp tục học'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<bool>(
          future: gradeEntitled,
          builder: (context, snapshot) => Card(child: ListTile(
            leading: Icon(snapshot.data == true
                ? Icons.verified_user : Icons.lock_outline),
            title: Text(snapshot.data == true
                ? 'Quyền học offline lớp $grade: hợp lệ'
                : 'Chưa kích hoạt quyền offline lớp $grade'),
            subtitle: const Text('Phần xem thử vẫn dùng được. Kích hoạt trong tab Tài khoản để nhận lease Ed25519.'),
            trailing: TextButton(
              onPressed: _openAccount,
              child: const Text('Tài khoản')),
          )),
        ),
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

  Future<void> _openAccount() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Tài khoản & key')),
        body: AccountPage(
          api: widget.api,
          initialSession: widget.session,
          onSignedOut: widget.onSignedOut,
          onLicenseChanged: _refreshLicense,
        ),
      ),
    ));
  }

  Future<void> _chooseProfile() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Chọn hồ sơ học sinh')),
          for (final profile in profiles)
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: Text(profile.name),
              subtitle: Text('Lớp ${profile.grade}'),
              trailing: activeProfile?.id == profile.id
                  ? const Icon(Icons.check_circle) : null,
              onTap: () => Navigator.pop(ctx, profile.id),
            ),
          ListTile(
            leading: const Icon(Icons.person_add_alt_1_outlined),
            title: const Text('Thêm học sinh'),
            onTap: () => Navigator.pop(ctx, 'create'),
          ),
        ],
      )),
    );
    if (id == 'create') {
      await _createProfile();
    } else if (id != null) {
      await _switchProfile(id);
    }
  }

  void _openLegacyFeature(LegacyMenuItem feature) {
    switch (feature.id) {
      case 'lessons':
      case 'curriculum':
        setState(() => tab = 1);
        return;
      case 'account':
        _openAccount();
        return;
      case 'profiles':
        _chooseProfile();
        return;
      case 'review':
      case 'progress':
      case 'analytics':
        if (activeProfile == null) return;
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => LocalProgressPage(
            ledger: ledger, profile: activeProfile!,
            grade: grade, currentPack: currentPack,
            review: feature.id == 'review',
          ),
        ));
        return;
      case 'parent':
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ParentOverviewPage(ledger: ledger, profiles: profiles),
        ));
        return;
      default:
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => LegacyComingSoonPage(feature: feature),
        ));
    }
  }

  Widget _practiceHubPage() => FutureBuilder<GradePack>(
    future: currentPack,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Text('Không tải được bài luyện tập.'));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final pack = snapshot.data!;
      final lessons = pack.lessons.where((lesson) {
        final id = (lesson['id'] as num?)?.toInt();
        return id != null &&
            pack.questionsFor(id).any(QuizEvaluator.canGrade);
      }).toList();
      return ListView(padding: const EdgeInsets.all(16), children: [
        Text('Luyện tập • Lớp $grade',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Chọn bài để làm câu hỏi. Kết quả và XP được lưu offline.'),
        const SizedBox(height: 14),
        if (lessons.isEmpty)
          const Card(child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('Chưa có câu hỏi có thể chấm cho lớp này.'),
          )),
        for (final lesson in lessons)
          Card(child: ListTile(
            leading: const Icon(Icons.quiz_outlined),
            title: Text(lesson['title']?.toString() ?? 'Bài học'),
            subtitle: Text(lesson['subjectCode']?.toString() ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              if (activeProfile == null) return;
              final id = (lesson['id'] as num).toInt();
              final questions = pack.questionsFor(id)
                  .where(QuizEvaluator.canGrade).toList();
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => PracticePage(
                  questions: questions, ledger: ledger,
                  profileId: activeProfile!.id, grade: grade,
                  lessonId: id, subjectCode: lesson['subjectCode']?.toString() ?? '',
                  lessonTitle: lesson['title']?.toString() ?? 'Luyện tập',
                ),
              ));
            },
          )),
      ]);
    },
  );

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
