import 'dart:convert';
import 'dart:math';

import 'catalog_repository.dart';
import 'local_store.dart';
import '../features/study/quiz_evaluator.dart';

class ArtPoint {
  final double x, y;
  const ArtPoint(this.x, this.y);
  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  factory ArtPoint.parse(dynamic raw) {
    final p = Map<String, dynamic>.from(raw as Map);
    final x = (p['x'] as num).toDouble(), y = (p['y'] as num).toDouble();
    if (!x.isFinite || !y.isFinite || x < 0 || x > 1 || y < 0 || y > 1) {
      throw const FormatException('Invalid drawing point');
    }
    return ArtPoint(x, y);
  }
}

class ArtStroke {
  final int color;
  final double width;
  final List<ArtPoint> points;
  const ArtStroke(this.color, this.width, this.points);
  Map<String, dynamic> toJson() => {
    'color': color, 'width': width,
    'points': points.map((p) => p.toJson()).toList(),
  };
  factory ArtStroke.parse(dynamic raw) {
    final m = Map<String, dynamic>.from(raw as Map);
    final w = (m['width'] as num).toDouble();
    final points = (m['points'] as List).map(ArtPoint.parse).toList();
    if (w < 1 || w > 32 || points.isEmpty || points.length > 1200) {
      throw const FormatException('Invalid art stroke');
    }
    return ArtStroke((m['color'] as num).toInt(), w, points);
  }
}

class ArtDocument {
  final int template;
  final List<ArtStroke> strokes;
  const ArtDocument({this.template = 0, this.strokes = const []});
  Map<String, dynamic> toJson() => {
    'version': 1, 'template': template,
    'strokes': strokes.map((s) => s.toJson()).toList(),
  };
  factory ArtDocument.parse(String raw) {
    final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    if (m['version'] != 1 || m['template'] is! int ||
        (m['template'] as int) < 0 || (m['template'] as int) > 4) {
      throw const FormatException('Unsupported art document');
    }
    final strokes = (m['strokes'] as List).map(ArtStroke.parse).toList();
    if (strokes.length > 150) {
      throw const FormatException('Art too large');
    }
    return ArtDocument(template: m['template'] as int, strokes: strokes);
  }
}

class ArtStore {
  final LocalStore db;
  ArtStore(this.db);
  String key(String profile, int grade) => 'art:v1:$profile:$grade';
  Future<ArtDocument> load(String profile, int grade) async {
    final raw = await db.read(key(profile, grade));
    return raw == null ? const ArtDocument() : ArtDocument.parse(raw);
  }
  Future<void> save(String profile, int grade, ArtDocument art) async {
    final encoded = jsonEncode(art.toJson());
    ArtDocument.parse(encoded);
    await db.update(key(profile, grade), (previous) {
      if (previous != null) ArtDocument.parse(previous);
      return encoded;
    });
  }
}

class ReviewCard {
  final int id;
  final String prompt, answer, lesson;
  const ReviewCard(this.id, this.prompt, this.answer, this.lesson);
}

class ReviewDeck {
  static const intervals = <int>[
    60000, 300000, 1800000, 14400000, 86400000, 259200000, 604800000
  ];

  static List<ReviewCard> fromPack(GradePack pack) {
    final lessons = <int, String>{};
    for (final l in pack.lessons) {
      if (l['id'] is num && l['isActive'] != 0) {
        lessons[(l['id'] as num).toInt()] = l['title']?.toString() ?? '';
      }
    }
    final rows = <int, ReviewCard>{};
    for (final q in pack.questions) {
      if (q['isActive'] == 0 || q['id'] is! num ||
          q['lessonId'] is! num || !QuizEvaluator.canGrade(q)) continue;
      final lessonId = (q['lessonId'] as num).toInt();
      if (!lessons.containsKey(lessonId)) {
        continue;
      }
      final type = q['questionType']?.toString();
      if (!{'single_choice', 'true_false', 'fill_number'}.contains(type)) {
        continue;
      }
      final prompt = q['questionText']?.toString().trim() ?? '';
      if (prompt.isEmpty) {
        continue;
      }
      String answer = '';
      if (type == 'single_choice') {
        final correct = QuizEvaluator.options(q)
            .where((option) => QuizEvaluator.correct(q, option)).toList();
        if (correct.length != 1) {
          continue;
        }
        answer = correct.single;
      } else if (type == 'true_false') {
        answer = QuizEvaluator.correct(q, 'Đúng') ? 'Đúng' : 'Sai';
      } else {
        answer = q['correctAnswer']?.toString().trim() ?? '';
      }
      if (answer.isEmpty) {
        continue;
      }
      final id = (q['id'] as num).toInt();
      rows.putIfAbsent(id, () => ReviewCard(id, prompt, answer, lessons[lessonId]!));
    }
    return rows.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  static int nextIndex(int previous, String rating) {
    if (rating == 'hard') {
      return 0;
    }
    if (rating == 'medium') {
      return min(previous + 1, 6).clamp(0, 6);
    }
    if (rating == 'easy') {
      return min(previous + 2, 6).clamp(0, 6);
    }
    throw ArgumentError.value(rating, 'rating');
  }
}

class ReviewDue {
  final int intervalIndex, atMillis;
  const ReviewDue(this.intervalIndex, this.atMillis);
  Map<String, dynamic> toJson() => {
    'index': intervalIndex, 'at': atMillis,
  };
  factory ReviewDue.parse(dynamic raw) {
    final m = Map<String, dynamic>.from(raw as Map);
    final index = (m['index'] as num).toInt();
    final time = (m['at'] as num).toInt();
    if (index < 0 || index >= ReviewDeck.intervals.length || time < 0) {
      throw const FormatException('Invalid memory record');
    }
    return ReviewDue(index, time);
  }
}

class MemoryRoomStore {
  final LocalStore db;
  MemoryRoomStore(this.db);
  String _key(String profile, int grade) => 'memory:v1:$profile:$grade';
  Map<int, ReviewDue> _decode(String? raw) {
    if (raw == null) {
      return {};
    }
    final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    if (m['version'] != 1 || m['reviews'] is! Map) {
      throw const FormatException('Invalid memory schema');
    }
    return Map<String, dynamic>.from(m['reviews'] as Map).map(
      (id, value) => MapEntry(int.parse(id), ReviewDue.parse(value)));
  }
  Future<Map<int, ReviewDue>> load(String profile, int grade) async =>
      _decode(await db.read(_key(profile, grade)));

  Future<ReviewDue> rate(String profile, int grade, int id,
      String rating, DateTime now) async {
    if (id <= 0 || grade < 1 || grade > 5) {
      throw ArgumentError('Invalid review');
    }
    late ReviewDue updated;
    await db.update(_key(profile, grade), (raw) {
      final records = _decode(raw);
      final index = ReviewDeck.nextIndex(records[id]?.intervalIndex ?? -1, rating);
      updated = ReviewDue(index, now.millisecondsSinceEpoch +
          ReviewDeck.intervals[index]);
      records[id] = updated;
      return jsonEncode({'version': 1, 'reviews': records.map(
        (key, value) => MapEntry(key.toString(), value.toJson()))});
    });
    return updated;
  }
}

class LessonBranch {
  final String title, content;
  const LessonBranch(this.title, this.content);
}

class MindMapDeck {
  static List<LessonBranch> fromLesson(GradePack pack, int id) {
    final found = pack.lessons.where((l) => l['id'] == id && l['isActive'] != 0);
    if (found.isEmpty) {
      return [];
    }
    final summary = found.first['summarySimple']?.toString().trim() ?? '';
    final result = <LessonBranch>[];
    if (summary.isNotEmpty) result.add(LessonBranch('Tổng quan', summary));
    for (final c in pack.cardsFor(id)) {
      final title = c['title']?.toString().trim() ?? '';
      final content = c['content']?.toString().trim() ?? '';
      if (title.isNotEmpty && content.isNotEmpty) {
        result.add(LessonBranch(title, content));
      }
    }
    return result.take(12).toList();
  }
}

class AvatarOption {
  final String id, icon, name;
  final int cost, level;
  const AvatarOption(this.id, this.icon, this.name, this.cost, this.level);
}

const avatarOptions = <AvatarOption>[
  AvatarOption('av_cat', '🐱', 'Mèo con', 0, 1),
  AvatarOption('av_dog', '🐶', 'Cún con', 0, 1),
  AvatarOption('av_panda', '🐼', 'Gấu Panda', 50, 2),
  AvatarOption('av_lion', '🦁', 'Sư tử', 100, 3),
  AvatarOption('av_unicorn', '🦄', 'Kỳ lân', 200, 4),
  AvatarOption('av_dragon', '🐉', 'Rồng vàng', 300, 5),
  AvatarOption('av_robot', '🤖', 'Robot', 150, 3),
  AvatarOption('av_alien', '👽', 'Bạn ngoài hành tinh', 250, 5),
  AvatarOption('av_ninja', '🥷', 'Ninja', 400, 6),
  AvatarOption('av_wizard', '🧙', 'Phù thủy', 500, 7),
  AvatarOption('av_astronaut', '🧑‍🚀', 'Phi hành gia', 800, 8),
  AvatarOption('av_crown', '👑', 'Vương miện', 1000, 9),
];

class AvatarInventory {
  final Map<String, int> owned;
  final String equipped;
  const AvatarInventory(this.owned, this.equipped);
  factory AvatarInventory.initial() =>
      const AvatarInventory({'av_cat': 0, 'av_dog': 0}, 'av_cat');
  int get spent => owned.values.fold<int>(0, (a, b) => a + b);
  Map<String, dynamic> toJson() =>
      {'version': 1, 'owned': owned, 'equipped': equipped};
  factory AvatarInventory.parse(String raw) {
    final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    if (m['version'] != 1 || m['owned'] is! Map || m['equipped'] is! String) {
      throw const FormatException('Invalid avatar schema');
    }
    final owned = Map<String, dynamic>.from(m['owned'] as Map).map(
        (key, value) => MapEntry(key, (value as num).toInt()));
    if (!owned.containsKey('av_cat') || !owned.containsKey('av_dog') ||
        !owned.containsKey(m['equipped']) ||
        owned.entries.any((e) => !avatarOptions.any(
          (a) => a.id == e.key && a.cost == e.value))) {
      throw const FormatException('Invalid avatar purchase');
    }
    return AvatarInventory(owned, m['equipped'] as String);
  }
}

class AvatarStore {
  final LocalStore db;
  AvatarStore(this.db);
  String _key(String profile) => 'avatar:v1:$profile';
  static int levelFromXp(int xp) => 1 + max(0, xp) ~/ 100;
  Future<AvatarInventory> load(String profile) async {
    final raw = await db.read(_key(profile));
    return raw == null ? AvatarInventory.initial() : AvatarInventory.parse(raw);
  }
  Future<AvatarInventory> buy(String profile, String id, int earnedXp) async {
    final options = avatarOptions.where((a) => a.id == id);
    if (options.isEmpty) {
      throw ArgumentError.value(id, 'id');
    }
    final option = options.first;
    late AvatarInventory result;
    await db.update(_key(profile), (raw) {
      final old = raw == null ? AvatarInventory.initial() : AvatarInventory.parse(raw);
      if (old.owned.containsKey(id)) {
        result = old;
        return jsonEncode(old.toJson());
      }
      if (levelFromXp(earnedXp) < option.level ||
          earnedXp - old.spent < option.cost) {
        throw StateError('Not enough XP or level');
      }
      result = AvatarInventory({...old.owned, id: option.cost}, old.equipped);
      return jsonEncode(result.toJson());
    });
    return result;
  }
  Future<AvatarInventory> equip(String profile, String id) async {
    late AvatarInventory result;
    await db.update(_key(profile), (raw) {
      final old = raw == null ? AvatarInventory.initial() : AvatarInventory.parse(raw);
      if (!old.owned.containsKey(id)) {
        throw StateError('Avatar not owned');
      }
      result = AvatarInventory(old.owned, id);
      return jsonEncode(result.toJson());
    });
    return result;
  }
}
