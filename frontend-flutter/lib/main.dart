import 'package:material_ui/material_ui.dart';
import 'core/theme.dart';
import 'data/catalog_repository.dart';
import 'data/account_api.dart';
import 'data/local_store.dart';
import 'data/study_ledger.dart';
import 'data/offline_license.dart';
import 'data/offline_fun.dart';
import 'features/study/lesson_page.dart';
import 'features/native_ui.dart';
import 'features/learning_entitlement_gate.dart';
import 'features/offline_fun_pages.dart';
import 'features/native_achievements.dart';
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
  Future<List<LessonProgress>>? _progressFuture;

  void _refreshProgress() {
    final profile = activeProfile;
    if (profile != null) {
      _progressFuture = ledger.progressFor(profile.id, grade: grade);
    }
  }

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
          _progressFuture = ledger.progressFor(profile.id, grade: profile.grade);
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
          _refreshProgress();
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
          _refreshProgress();
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
          _refreshProgress();
          currentPack = repository.loadGrade(grade);
          gradeEntitled = offline.gradeAllowed(grade);
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

  Future<bool> _requireLearningAccess() async {
    final checkedGrade = grade;
    try {
      final allowed = await offline.gradeAllowed(checkedGrade);
      if (allowed && mounted && grade == checkedGrade) return true;
    } catch (_) {
      // Fail closed: unreadable or corrupt signed leases cannot open lessons.
    }
    if (!mounted) return false;
    setState(() => gradeEntitled = Future<bool>.value(false));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(
        'Chưa có quyền học hợp lệ. Hãy kích hoạt key cho lớp này.')));
    return false;
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
      backgroundColor: HhkNative.bg,
      appBar: AppBar(
        backgroundColor: HhkNative.bg,
        centerTitle: true,
        elevation: 0,
        leading: Builder(builder: (context) => IconButton(
          key: const Key('open-feature-menu'),
          tooltip: 'Mở menu tính năng',
          icon: const Icon(Icons.menu_rounded, color: HhkNative.ink),
          onPressed: () => Scaffold.of(context).openDrawer(),
        )),
        title: const Text('HỌC HỨNG KHỞI',
            style: TextStyle(fontSize: 15, color: HhkNative.ink,
              letterSpacing: .4, fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            key: const Key('open-account'),
            tooltip: 'Tài khoản & key',
            icon: const Icon(Icons.account_circle_rounded,
              size: 27, color: HhkNative.purple),
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
                  : LearningEntitlementGate(
                      entitlement: gradeEntitled,
                      grade: grade,
                      onGrade: _selectGrade,
                      onActivate: _openAccount,
                      onRefresh: _refreshLicense,
                      onSwitchProfile: _chooseProfile,
                      child: IndexedStack(index: tab, children: pages),
                    )),
      // NavigationBar owns the system bottom safe area; do not wrap it again.
      bottomNavigationBar: CompactBottomNavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
      ),
    );
  }


  Widget _homePage() => FutureBuilder<GradePack>(
    future: currentPack,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Text('Không tải được nội dung lớp này.'));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return FutureBuilder<List<LessonProgress>>(
        future: _progressFuture,
        builder: (context, progressSnapshot) => NativeHomePage(
          pack: snapshot.data!,
          grade: grade,
          profileName: activeProfile?.name ?? 'Học sinh',
          progress: progressSnapshot.data ?? <LessonProgress>[],
          onProfile: _chooseProfile,
          onAchievements: _showAchievements,
          onAccount: _openAccount,
          onSubjects: () => setState(() => tab = 1),
          onPractice: () => setState(() => tab = 2),
          onDaily: () => _openFunMode(FunMode.daily),
          onGames: () => _openFunMode(null),
          onSubject: (subject) => _openSubject(snapshot.data!, subject),
          onLesson: (lesson) => _openLesson(snapshot.data!, lesson),
        ),
      );
    },
  );


  
  Widget _curriculumPage() => FutureBuilder<GradePack>(
    future: currentPack,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Text('Không tải được danh sách môn học.'));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final pack = snapshot.data!;
      final subjects = pack.subjects.where((s) =>
        pack.lessonsFor(s['code']?.toString() ?? '').isNotEmpty).toList();
      return ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          const Text('Môn học của bé', style: TextStyle(
            fontSize: 27, color: HhkNative.ink, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('Lớp $grade · Khám phá kiến thức theo từng môn',
            style: const TextStyle(color: HhkNative.muted)),
          const SizedBox(height: 18),
          const NativeDopiBanner(
            title: 'Cùng Dopi khám phá!',
            subtitle: 'Mỗi bài học là một điều thú vị.'),
          const SizedBox(height: 20),
          const Text('Chọn lớp', style: TextStyle(fontWeight: FontWeight.w800,
            color: HhkNative.ink)),
          const SizedBox(height: 9),
          SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (var i = 1; i <= 5; i++)
                Padding(padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text('Lớp $i'),
                    selected: grade == i,
                    onSelected: (_) => _selectGrade(i))),
            ])),
          const SizedBox(height: 18),
          NativeHeading('Danh sách môn học',
            action: '${subjects.length} môn'),
          const SizedBox(height: 8),
          if (subjects.isEmpty)
            const NativePanel(child: Text('Chưa có môn học cho lớp này.')),
          for (final subject in subjects)
            Padding(padding: const EdgeInsets.only(bottom: 12),
              child: NativePanel(
                onTap: () => _openSubject(pack, subject),
                child: Row(children: [
                  Container(width: 64, height: 64, alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: HhkNative.subjectColor(
                        subject['code']?.toString() ?? ''),
                      borderRadius: BorderRadius.circular(20)),
                    child: Text(HhkNative.emoji(subject),
                      style: const TextStyle(fontSize: 29))),
                  const SizedBox(width: 15),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(subject['name']?.toString() ?? 'Môn học',
                        style: const TextStyle(color: HhkNative.ink,
                          fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 5),
                      Text('${pack.lessonsFor(subject['code']?.toString() ?? '').length} bài học',
                        style: const TextStyle(color: HhkNative.muted,
                          fontSize: 12)),
                    ])),
                  const Icon(Icons.arrow_circle_right_rounded,
                    color: HhkNative.purple, size: 32),
                ]),
              )),
        ],
      );
    },
  );


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
    await _refreshLicense();
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


  Future<void> _openFunMode(FunMode? mode) async {
    if (!await _requireLearningAccess()) return;
    final profile = activeProfile;
    if (profile == null || !mounted) return;
    try {
      final pack = await currentPack;
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => mode == null
            ? OfflineMiniGameHubPage(
                pack: pack, profile: profile, storage: store,
                ensureAccess: _requireLearningAccess)
            : OfflineFunRoundPage(
                mode: mode, pack: pack, profile: profile, storage: store),
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Không thể mở trò chơi offline. Hãy thử lại.')));
      }
    }
  }

  Future<void> _openLegacyFeature(LegacyMenuItem feature) async {
    if (!{'account', 'profiles', 'parent', 'daily', 'games'}.contains(feature.id) &&
        !await _requireLearningAccess()) {
      return;
    }
    if (!mounted) return;
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
      case 'daily':
        await _openFunMode(FunMode.daily);
        return;
      case 'games':
        await _openFunMode(null);
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
        return id != null && pack.questionsFor(id).any(QuizEvaluator.canGrade);
      }).toList();
      return FutureBuilder<List<LessonProgress>>(
        future: _progressFuture,
        builder: (context, progressSnapshot) {
          final progress = {for (final p in
            progressSnapshot.data ?? <LessonProgress>[]) p.lessonId: p};
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            itemCount: lessons.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Luyện tập thật vui', style: TextStyle(
                      fontSize: 27, color: HhkNative.ink,
                      fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text('Lớp $grade · Kết quả lưu offline trên thiết bị',
                      style: const TextStyle(color: HhkNative.muted)),
                    const SizedBox(height: 17),
                    const NativeDopiBanner(
                      title: 'Cùng Dopi giải đố!',
                      subtitle: 'Cố lên, mỗi câu hỏi là một bước tiến.',
                      color: HhkNative.pink),
                    const SizedBox(height: 19),
                    NativeHeading('Chọn bài luyện',
                      action: '${lessons.length} bài'),
                    if (lessons.isEmpty)
                      const NativePanel(child: Text(
                        'Lớp này chưa có câu hỏi có thể chấm điểm.')),
                    const SizedBox(height: 8),
                  ]);
              }
              final lesson = lessons[index - 1];
              final id = (lesson['id'] as num?)?.toInt();
              return Padding(padding: const EdgeInsets.only(bottom: 12),
                child: NativeLessonRow(lesson: lesson, index: index,
                  practice: true, progress: progress[id],
                  onTap: () => _openPractice(pack, lesson)));
            },
          );
        },
      );
    },
  );

  Future<void> _openPractice(GradePack pack,
      Map<String, dynamic> lesson) async {
    if (!await _requireLearningAccess()) return;
    if (!mounted) return;
    final profile = activeProfile;
    final id = (lesson['id'] as num?)?.toInt();
    if (profile == null || id == null) return;
    final questions = pack.questionsFor(id)
        .where(QuizEvaluator.canGrade).toList();
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PracticePage(
        questions: questions, ledger: ledger,
        profileId: profile.id, grade: grade,
        lessonId: id, subjectCode: lesson['subjectCode']?.toString() ?? '',
        lessonTitle: lesson['title']?.toString() ?? 'Luyện tập',
      ),
    ));
    if (mounted) setState(_refreshProgress);
  }

  Future<void> _openLesson(GradePack pack,
      Map<String, dynamic> lesson) async {
    if (!await _requireLearningAccess()) return;
    if (!mounted) return;
    final profile = activeProfile;
    if (profile == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LessonPage(
        pack: pack, lesson: lesson,
        ledger: ledger, profileId: profile.id),
    ));
    if (mounted) setState(_refreshProgress);
  }

  void _showAchievements() {
    final profile = activeProfile;
    if (profile == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => FutureBuilder<List<LessonProgress>>(
        future: ledger.progressFor(profile.id, grade: grade),
        builder: (context, snapshot) => NativeAchievementsPage(
          profileName: profile.name, grade: grade,
          progress: snapshot.data ?? <LessonProgress>[],
          onDetails: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => LocalProgressPage(
              ledger: ledger, profile: profile, grade: grade,
              currentPack: currentPack))),
        ),
      ),
    ));
  }


  
  Widget _settingsPage() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
    children: [
      const Text('Góc của bé', style: TextStyle(fontSize: 27,
        fontWeight: FontWeight.w900, color: HhkNative.ink)),
      const SizedBox(height: 8),
      const Text('Hồ sơ, thành tích và cài đặt học tập',
        style: TextStyle(color: HhkNative.muted)),
      const SizedBox(height: 18),
      NativePanel(color: HhkNative.lilac,
        onTap: _chooseProfile,
        child: Row(children: [
          Image.asset('assets/brand/dopi-avatar.png',
            width: 68, height: 68),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(activeProfile?.name ?? 'Học sinh',
                style: const TextStyle(fontSize: 17,
                  color: HhkNative.ink, fontWeight: FontWeight.w900)),
              Text('Lớp $grade · Đổi hồ sơ',
                style: const TextStyle(color: HhkNative.muted)),
            ])),
          const Icon(Icons.chevron_right, color: HhkNative.purple),
        ])),
      const SizedBox(height: 17),
      NativeHeading('Học tập & thành tích'),
      const SizedBox(height: 8),
      NativePanel(onTap: _showAchievements,
        child: const ListTile(
          leading: Icon(Icons.emoji_events_rounded,
            color: HhkNative.purple),
          title: Text('Thành tích của bé'),
          subtitle: Text('XP, số lượt luyện và dấu mốc thật'),
          trailing: Icon(Icons.chevron_right))),
      const SizedBox(height: 12),
      NativePanel(onTap: () => _openLegacyFeature(
          const LegacyMenuItem('review', 'Ôn tập', Icons.refresh)),
        child: const ListTile(
          leading: Icon(Icons.refresh_rounded, color: HhkNative.purple),
          title: Text('Ôn tập thông minh'),
          subtitle: Text('Xem lại câu cần ôn'),
          trailing: Icon(Icons.chevron_right))),
      const SizedBox(height: 18),
      NativeHeading('Tài khoản & thiết bị'),
      const SizedBox(height: 8),
      NativePanel(onTap: _openAccount,
        child: const ListTile(
          leading: Icon(Icons.manage_accounts_rounded,
            color: HhkNative.purple),
          title: Text('Tài khoản, mật khẩu và key'),
          subtitle: Text('Phiên đăng nhập, QR và quyền học offline'),
          trailing: Icon(Icons.chevron_right))),
      const SizedBox(height: 12),
      const NativePanel(child: ListTile(
        leading: Icon(Icons.privacy_tip_outlined,
          color: HhkNative.purple),
        title: Text('Quyền riêng tư'),
        subtitle: Text('Điểm số và hồ sơ học lưu trên thiết bị.'))),
    ],
  );


  
  Future<void> _openSubject(GradePack pack, Map<String, dynamic> subject) async {
    if (!await _requireLearningAccess()) return;
    if (!mounted) return;
    final profile = activeProfile;
    if (profile == null) return;
    final lessons = pack.lessonsFor(subject['code']?.toString() ?? '');
    final title = subject['name']?.toString() ?? 'Môn học';
    bool practisedOnly = false;
    Future<List<LessonProgress>> progressFuture = ledger.progressFor(
      profile.id, grade: grade,
      subjectCode: subject['code']?.toString() ?? '');
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (ctx) => Scaffold(
        backgroundColor: HhkNative.bg,
        appBar: AppBar(title: Text(title)),
        body: StatefulBuilder(builder: (ctx, refresh) =>
          FutureBuilder<List<LessonProgress>>(
            future: progressFuture,
            builder: (ctx, snapshot) {
              final progress = {for (final p in snapshot.data ??
                <LessonProgress>[]) p.lessonId: p};
              final visible = lessons.where((lesson) =>
                !practisedOnly || progress.containsKey(lesson['id'])).toList();
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                itemCount: visible.length + 1,
                itemBuilder: (ctx, index) {
                  if (index == 0) {
                    return Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        NativeDopiBanner(title: 'Cùng học $title!',
                          subtitle: '${lessons.length} bài trong giáo trình'),
                        const SizedBox(height: 16),
                        Row(children: [
                          ChoiceChip(label: const Text('Tất cả'),
                            selected: !practisedOnly, onSelected: (_) =>
                              refresh(() => practisedOnly = false)),
                          const SizedBox(width: 8),
                          ChoiceChip(label: const Text('Đã luyện'),
                            selected: practisedOnly, onSelected: (_) =>
                              refresh(() => practisedOnly = true)),
                        ]),
                        const SizedBox(height: 12),
                        NativeHeading('Bài học',
                          action: '${visible.length} bài'),
                        if (visible.isEmpty)
                          const NativePanel(child: Text(
                            'Chưa có bài đã luyện. Chọn Tất cả để bắt đầu!')),
                        const SizedBox(height: 7),
                      ],
                    );
                  }
                  final lesson = visible[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: NativeLessonRow(
                      lesson: lesson,
                      index: lessons.indexOf(lesson) + 1,
                      progress: progress[lesson['id']],
                      onTap: () async {
                        await _openLesson(pack, lesson);
                        if (ctx.mounted) {
                          refresh(() => progressFuture = ledger.progressFor(
                            profile.id, grade: grade,
                            subjectCode: subject['code']?.toString() ?? ''));
                        }
                      },
                    ));
                },
              );
            },
          )),
      ),
    ));
  }

}
