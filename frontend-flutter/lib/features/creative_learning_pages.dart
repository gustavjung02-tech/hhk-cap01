import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';

import '../data/catalog_repository.dart';
import '../data/creative_port.dart';
import '../data/local_store.dart';
import '../data/study_ledger.dart';

class MemoryRoomPage extends StatefulWidget {
  final GradePack pack;
  final LocalStore store;
  final String profileId;
  const MemoryRoomPage({super.key, required this.pack,
    required this.store, required this.profileId});
  @override
  State<MemoryRoomPage> createState() => _MemoryRoomPageState();
}

class _MemoryRoomPageState extends State<MemoryRoomPage> {
  List<ReviewCard>? due;
  Map<int, ReviewDue> reviews = {};
  int index = 0;
  bool revealed = false;
  bool busy = false;
  String? error;

  @override
  void initState() { super.initState(); reload(); }

  Future<void> reload() async {
    try {
      final data = await MemoryRoomStore(widget.store)
          .load(widget.profileId, widget.pack.grade);
      final now = DateTime.now().millisecondsSinceEpoch;
      final cards = ReviewDeck.fromPack(widget.pack)
          .where((c) => (data[c.id]?.atMillis ?? 0) <= now)
          .take(20).toList();
      if (!mounted) return;
      setState(() {
        reviews = data;
        due = cards;
        index = 0;
        revealed = false;
      });
    } catch (_) {
      if (mounted) setState(() => error = 'Không đọc được lịch ôn đã lưu trên máy.');
    }
  }

  Future<void> rate(String difficulty) async {
    if (busy || due == null || index >= due!.length) return;
    setState(() => busy = true);
    try {
      final current = due![index];
      final record = await MemoryRoomStore(widget.store)
          .rate(widget.profileId, widget.pack.grade,
            current.id, difficulty, DateTime.now());
      if (!mounted) return;
      setState(() {
        reviews[current.id] = record;
        index++;
        revealed = false;
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không lưu được lịch ôn. Vui lòng thử lại.')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = due;
    return Scaffold(
      appBar: AppBar(title: const Text('Phòng trí nhớ')),
      body: error != null ? Center(child: Text(error!))
        : cards == null ? const Center(child: CircularProgressIndicator())
        : cards.isEmpty || index >= cards.length
          ? Center(child: Padding(padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('🧠', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                const Text('Đã ôn hết thẻ đến hạn!',
                  textAlign: TextAlign.center, style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Thẻ sẽ xuất hiện lại theo lịch ghi nhớ đã lưu.'),
                const SizedBox(height: 14),
                Text('Tổng số thẻ đã lên lịch: ' + reviews.length.toString()),
                const SizedBox(height: 16),
                OutlinedButton(onPressed: reload,
                  child: const Text('Kiểm tra lại')),
              ])))
          : ListView(padding: const EdgeInsets.all(18), children: [
              Text('Thẻ ' + (index + 1).toString() + '/'
                + cards.length.toString() + ' · Lớp '
                + widget.pack.grade.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Card(child: InkWell(onTap: () => setState(() => revealed = !revealed),
                child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 235),
                  child: Padding(padding: const EdgeInsets.all(24),
                    child: Center(child: Column(mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cards[index].lesson,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black54)),
                        const SizedBox(height: 20),
                        Text(revealed ? cards[index].answer : cards[index].prompt,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22,
                            fontWeight: FontWeight.bold)),
                        const SizedBox(height: 18),
                        Text(revealed ? 'Chạm để xem câu hỏi'
                          : 'Chạm để xem đáp án'),
                      ])))))),
              const SizedBox(height: 14),
              if (!revealed)
                FilledButton(onPressed: () => setState(() => revealed = true),
                  child: const Text('Xem đáp án'))
              else Wrap(alignment: WrapAlignment.center, spacing: 9, children: [
                OutlinedButton(onPressed: busy ? null : () => rate('hard'),
                  child: const Text('Khó')),
                OutlinedButton(onPressed: busy ? null : () => rate('medium'),
                  child: const Text('Vừa')),
                FilledButton(onPressed: busy ? null : () => rate('easy'),
                  child: const Text('Dễ')),
              ]),
              const SizedBox(height: 16),
              const Text('Chỉ ôn câu có đáp án kiểm tra được. '
                  'Không cộng XP vào điểm luyện tập.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
    );
  }
}

class MindMapPage extends StatefulWidget {
  final GradePack pack;
  const MindMapPage({super.key, required this.pack});
  @override
  State<MindMapPage> createState() => _MindMapPageState();
}

class _MindMapPageState extends State<MindMapPage> {
  int? selectedId;
  int expanded = -1;

  @override
  Widget build(BuildContext context) {
    final lessons = widget.pack.lessons.where((row) =>
        row['id'] is num && row['isActive'] != 0).toList();
    final currentId = selectedId ??
        (lessons.isEmpty ? null : (lessons.first['id'] as num).toInt());
    final matched = lessons.where((l) => l['id'] == currentId).toList();
    final branches = currentId == null ? <LessonBranch>[]
        : MindMapDeck.fromLesson(widget.pack, currentId);
    return Scaffold(
      appBar: AppBar(title: const Text('Sơ đồ tư duy')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Sơ đồ liên kết những ý chính của bài học.',
          textAlign: TextAlign.center),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: lessons.isEmpty ? null : () async {
            final next = await showModalBottomSheet<int>(context: context,
              isScrollControlled: true, builder: (ctx) =>
                SafeArea(child: SizedBox(
                  height: MediaQuery.sizeOf(ctx).height * .65,
                  child: ListView(children: [
                    for (final lesson in lessons)
                      ListTile(title: Text(lesson['title']?.toString() ?? ''),
                        onTap: () => Navigator.pop(ctx,
                          (lesson['id'] as num).toInt())),
                  ]))));
            if (next != null && mounted) {
              setState(() { selectedId = next; expanded = -1; });
            }
          },
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('Chọn bài học')),
        const SizedBox(height: 16),
        if (matched.isEmpty)
          const Center(child: Text('Lớp này chưa có bài học.'))
        else ...[
          Center(child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xffe9d5ff),
              borderRadius: BorderRadius.circular(24)),
            child: Text(matched.first['title']?.toString() ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          )),
          const Center(child: SizedBox(height: 26,
            child: VerticalDivider(thickness: 3, color: Color(0xffa78bfa)))),
          if (branches.isEmpty)
            const Text('Bài này chưa có thẻ nội dung đã biên tập.',
              textAlign: TextAlign.center)
          else for (var i = 0; i < branches.length; i++) ...[
            Row(children: [
              Container(width: 18, height: 3,
                color: const Color(0xffa78bfa)),
              Expanded(child: Card(
                color: i.isEven ? const Color(0xffeff6ff)
                  : const Color(0xfffff1f2),
                child: InkWell(onTap: () => setState(() =>
                  expanded = expanded == i ? -1 : i),
                  child: Padding(padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text(branches[i].title,
                            style: const TextStyle(fontWeight: FontWeight.bold))),
                          Icon(expanded == i
                            ? Icons.expand_less : Icons.expand_more),
                        ]),
                        if (expanded == i) ...[
                          const SizedBox(height: 10),
                          Text(branches[i].content),
                        ],
                      ]),
                  )),
              )),
            ]),
            if (i != branches.length - 1)
              const Padding(padding: EdgeInsets.only(left: 8),
                child: SizedBox(height: 14,
                  child: VerticalDivider(thickness: 2,
                    color: Color(0xffa78bfa)))),
          ],
          const SizedBox(height: 16),
          const Text('Nhánh kiến thức lấy từ thẻ học và tóm tắt thật. '
              'Chạm vào từng nhánh để đọc chi tiết.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ]),
    );
  }
}

class AvatarShopPage extends StatefulWidget {
  final LocalStore store;
  final StudyLedger ledger;
  final StudentProfile profile;
  const AvatarShopPage({super.key, required this.store,
    required this.ledger, required this.profile});
  @override
  State<AvatarShopPage> createState() => _AvatarShopPageState();
}

class _AvatarShopPageState extends State<AvatarShopPage> {
  AvatarInventory? inventory;
  int xp = 0;
  bool busy = false;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final earned = await widget.ledger.totalXp(widget.profile.id);
      final data = await AvatarStore(widget.store).load(widget.profile.id);
      if (mounted) setState(() { xp = earned; inventory = data; });
    } catch (_) {
      if (mounted) setState(() => error = 'Không đọc được dữ liệu avatar.');
    }
  }

  Future<void> choose(AvatarOption item) async {
    if (busy || inventory == null) return;
    setState(() => busy = true);
    try {
      final earned = await widget.ledger.totalXp(widget.profile.id);
      final store = AvatarStore(widget.store);
      final next = inventory!.owned.containsKey(item.id)
        ? await store.equip(widget.profile.id, item.id)
        : await store.buy(widget.profile.id, item.id, earned);
      if (mounted) setState(() { xp = earned; inventory = next; });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa đủ XP, cấp độ hoặc không lưu được.')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = inventory;
    final level = AvatarStore.levelFromXp(xp);
    return Scaffold(
      appBar: AppBar(title: const Text('Cửa hàng avatar')),
      body: error != null ? Center(child: Text(error!))
        : state == null ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(16), children: [
          Center(child: Text(avatarOptions
            .firstWhere((a) => a.id == state.equipped).icon,
            style: const TextStyle(fontSize: 76))),
          Center(child: Text(widget.profile.name,
            style: const TextStyle(fontSize: 22,
              fontWeight: FontWeight.bold))),
          const SizedBox(height: 8),
          Center(child: Text('XP đạt: ' + xp.toString() + ' · Cấp '
            + level.toString() + ' · Còn '
            + math.max(0, xp - state.spent).toString() + ' XP mở khóa',
            textAlign: TextAlign.center)),
          const SizedBox(height: 10),
          const Text('Mở khóa bằng XP đã kiếm được. '
              'Điểm học tập không bị trừ hay thay đổi.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          for (final item in avatarOptions)
            Card(child: ListTile(
              leading: Text(item.icon, style: const TextStyle(fontSize: 32)),
              title: Text(item.name),
              subtitle: Text(item.cost == 0 ? 'Miễn phí'
                : item.cost.toString() + ' XP · Cấp ' + item.level.toString()),
              trailing: state.equipped == item.id
                ? const Icon(Icons.check_circle, color: Colors.green)
                : Icon(state.owned.containsKey(item.id)
                  ? Icons.face : Icons.lock_outline),
              enabled: !busy,
              onTap: () => choose(item),
            )),
        ]),
    );
  }
}
