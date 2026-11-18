import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../data/creative_port.dart';
import '../data/local_store.dart';

const palette = <int>[
  0xffef4444, 0xfff97316, 0xfffbbf24, 0xff22c55e,
  0xff3b82f6, 0xff8b5cf6, 0xffec4899, 0xff0ea5e9,
  0xff14b8a6, 0xff111827, 0xff6b7280, 0xffffffff,
];

class CreativeDrawingPage extends StatefulWidget {
  final LocalStore store;
  final String profileId;
  final int grade;
  const CreativeDrawingPage({super.key, required this.store,
    required this.profileId, required this.grade});

  @override
  State<CreativeDrawingPage> createState() => _CreativeDrawingPageState();
}

class _CreativeDrawingPageState extends State<CreativeDrawingPage> {
  final strokes = <ArtStroke>[];
  final current = <ArtPoint>[];
  int template = 0;
  int color = palette.first;
  double brush = 6;
  bool loaded = false;
  bool saving = false;
  String? error;
  Future<void> pending = Future<void>.value();
  int? activeDrawingPointer;

  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    try {
      final data = await ArtStore(widget.store).load(widget.profileId, widget.grade);
      if (!mounted) {
        return;
      }
      setState(() {
        template = data.template;
        strokes.addAll(data.strokes);
        loaded = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loaded = true;
          error = 'Không đọc được tranh đã lưu. Tranh cũ vẫn được giữ nguyên.';
        });
      }
    }
  }

  void save() {
    if (error != null) {
      return;
    }
    final doc = ArtDocument(template: template,
      strokes: List<ArtStroke>.from(strokes));
    setState(() => saving = true);
    pending = pending.then((_) => ArtStore(widget.store)
        .save(widget.profileId, widget.grade, doc)).then((_) {
      if (mounted) {
        setState(() => saving = false);
      }
    }).catchError((Object _) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Không thể lưu tranh. Kiểm tra dung lượng máy.';
        });
      }
    });
  }

  ArtPoint point(Offset p, Size s) => ArtPoint(
    (p.dx / s.width).clamp(0.0, 1.0),
    (p.dy / s.height).clamp(0.0, 1.0));

  void begin(Offset p, Size s) {
    if (!loaded || error != null || strokes.length >= 150) {
      return;
    }
    setState(() {
      current.clear();
      current.add(point(p, s));
    });
  }

  void move(Offset p, Size s) {
    if (current.isEmpty || current.length >= 1200) {
      return;
    }
    setState(() => current.add(point(p, s)));
  }

  void finish() {
    if (current.isEmpty) {
      return;
    }
    setState(() {
      strokes.add(ArtStroke(color, brush, List<ArtPoint>.from(current)));
      current.clear();
    });
    save();
  }

  Future<void> changeTemplate(int next) async {
    if (next == template) {
      return;
    }
    if (strokes.isNotEmpty) {
      final approved = await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Đổi mẫu vẽ?'),
          content: const Text('Các nét ở mẫu hiện tại sẽ bị xóa.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Giữ tranh')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Đổi mẫu')),
          ],
        ));
      if (approved != true || !mounted) {
        return;
      }
    }
    setState(() { template = next; strokes.clear(); });
    save();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Vẽ & tô màu'), actions: [
      IconButton(tooltip: 'Hoàn tác', icon: const Icon(Icons.undo),
        onPressed: strokes.isEmpty || error != null ? null : () {
          setState(() => strokes.removeLast());
          save();
        }),
      IconButton(tooltip: 'Xóa tất cả nét', icon: const Icon(Icons.delete_outline),
        onPressed: strokes.isEmpty || error != null ? null : () {
          setState(() => strokes.clear());
          save();
        }),
    ]),
    body: !loaded ? const Center(child: CircularProgressIndicator())
      : error != null ? Center(child: Padding(padding: const EdgeInsets.all(20),
          child: Text(error!, textAlign: TextAlign.center)))
      : ListView(
          // During a stroke, vertical touch movement paints the canvas rather
          // than scrolling its parent. Outside the canvas, scrolling remains.
          physics: activeDrawingPointer == null
              ? null : const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(14), children: [
        Text('Vẽ bằng tay • Lưu riêng cho từng học sinh và lớp',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final entry in ['Tự do', '⭐ Sao', '🏠 Nhà', '☀️ Mặt trời', '🌸 Hoa']
              .asMap().entries)
            ChoiceChip(label: Text(entry.value), selected: template == entry.key,
              onSelected: (_) => changeTemplate(entry.key)),
        ]),
        const SizedBox(height: 12),
        AspectRatio(aspectRatio: 1,
          child: Container(decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xffd8b4fe), width: 2)),
            child: ClipRRect(borderRadius: BorderRadius.circular(16),
              child: LayoutBuilder(builder: (ctx, box) {
                final size = Size(box.maxWidth, box.maxHeight);
                return Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) {
                    if (activeDrawingPointer != null ||
                        !loaded || error != null || strokes.length >= 150) {
                      return;
                    }
                    activeDrawingPointer = event.pointer;
                    begin(event.localPosition, size);
                  },
                  onPointerMove: (event) {
                    if (activeDrawingPointer == event.pointer) {
                      move(event.localPosition, size);
                    }
                  },
                  onPointerUp: (event) {
                    if (activeDrawingPointer == event.pointer) {
                      activeDrawingPointer = null;
                      finish();
                    }
                  },
                  onPointerCancel: (event) {
                    if (activeDrawingPointer == event.pointer) {
                      activeDrawingPointer = null;
                      finish();
                    }
                  },
                  child: CustomPaint(painter: ArtPainter(template, strokes,
                    current, color, brush), child: const SizedBox.expand()),
                );
              })),
          )),
        const SizedBox(height: 12),
        Text(saving ? 'Đang lưu...' : 'Tranh được lưu tự động',
          textAlign: TextAlign.center),
        const SizedBox(height: 14),
        const Text('Chọn màu', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final c in palette)
            InkWell(onTap: () => setState(() => color = c),
              child: Container(width: 36, height: 36, decoration: BoxDecoration(
                color: Color(c), shape: BoxShape.circle,
                border: Border.all(color: c == color
                    ? const Color(0xff7c3aed) : Colors.grey,
                  width: c == color ? 3 : 1))),
            ),
        ]),
        const SizedBox(height: 16),
        Text('Độ dày nét: ${brush.round()}'),
        Slider(value: brush, min: 2, max: 20, divisions: 9,
          onChanged: (next) => setState(() => brush = next)),
        const Text('Chọn màu trắng để tẩy các nét đã vẽ.',
          style: TextStyle(fontSize: 12, color: Colors.black54)),
      ]),
  );
}

class ArtPainter extends CustomPainter {
  final int template;
  final List<ArtStroke> strokes;
  final List<ArtPoint> current;
  final int activeColor;
  final double activeWidth;
  ArtPainter(this.template, this.strokes, this.current,
      this.activeColor, this.activeWidth);

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawColor(Colors.white, BlendMode.src);
    final x = s.width, y = s.height;
    final line = Paint()..color = const Color(0xffcbd5e1)
      ..style = PaintingStyle.stroke..strokeWidth = 3;
    if (template == 1) {
      final star = Path();
      for (var i = 0; i <= 10; i++) {
        final theta = i * math.pi / 5 - math.pi / 2;
        final r = i.isEven ? x * .34 : x * .16;
        final p = Offset(x / 2 + math.cos(theta) * r,
          y / 2 + math.sin(theta) * r);
        if (i == 0) { star.moveTo(p.dx, p.dy); }
        else { star.lineTo(p.dx, p.dy); }
      }
      canvas.drawPath(star, line);
    } else if (template == 2) {
      canvas.drawRect(Rect.fromLTWH(x*.22, y*.43, x*.56, y*.39), line);
      canvas.drawPath(Path()..moveTo(x*.14,y*.43)..lineTo(x*.5,y*.15)
        ..lineTo(x*.86,y*.43), line);
      canvas.drawRect(Rect.fromLTWH(x*.42,y*.62,x*.16,y*.20), line);
      canvas.drawRect(Rect.fromLTWH(x*.61,y*.51,x*.10,y*.10), line);
    } else if (template == 3) {
      canvas.drawCircle(Offset(x*.5,y*.5), x*.2, line);
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6;
        canvas.drawLine(Offset(x*.5 + math.cos(a)*x*.26,
            y*.5 + math.sin(a)*x*.26),
          Offset(x*.5 + math.cos(a)*x*.40,
            y*.5 + math.sin(a)*x*.40), line);
      }
    } else if (template == 4) {
      final c = Offset(x*.5,y*.43);
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        canvas.drawCircle(c + Offset(math.cos(a)*x*.18,
          math.sin(a)*x*.18), x*.12, line);
      }
      canvas.drawCircle(c, x*.09, line);
      canvas.drawLine(Offset(x*.5,y*.54), Offset(x*.5,y*.90), line);
    }
    void stroke(int color, double w, List<ArtPoint> points) {
      if (points.isEmpty) {
        return;
      }
      final ink = Paint()..color = Color(color)..strokeWidth = w
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (points.length == 1) {
        canvas.drawCircle(Offset(points.first.x*x,
          points.first.y*y), w/2, Paint()..color = Color(color));
        return;
      }
      final path = Path()..moveTo(points.first.x*x,points.first.y*y);
      for (final p in points.skip(1)) { path.lineTo(p.x*x,p.y*y); }
      canvas.drawPath(path, ink);
    }
    for (final s in strokes) { stroke(s.color,s.width,s.points); }
    stroke(activeColor,activeWidth,current);
  }

  @override
  bool shouldRepaint(covariant ArtPainter old) => true;
}
