import 'dart:async';

import 'package:material_ui/material_ui.dart';

enum HhkToastKind { info, success, error }

/// Transient, non-blocking notification, anchored at the top-right of the app.
/// Never alters page layout or retains messages in device storage.
class HhkToast {
  static OverlayEntry? _active;
  static Timer? _dismissTimer;

  static void show(BuildContext context, String message,
      {HhkToastKind kind = HhkToastKind.info}) {
    final overlay = Overlay.of(context, rootOverlay: true);
    dismiss();
    final isNarrow = MediaQuery.sizeOf(context).width < 430;
    final color = switch (kind) {
      HhkToastKind.success => const Color(0xff166d50),
      HhkToastKind.error => const Color(0xffaa3544),
      HhkToastKind.info => const Color(0xff284b68),
    };
    final icon = switch (kind) {
      HhkToastKind.success => Icons.check_circle_outline,
      HhkToastKind.error => Icons.error_outline,
      HhkToastKind.info => Icons.info_outline,
    };
    final entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        right: 16,
        left: isNarrow ? 16 : null,
        top: MediaQuery.paddingOf(overlayContext).top + 16,
        child: IgnorePointer(
          child: Material(
            color: color,
            elevation: 10,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isNarrow ? 430 : 380),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        message,
                        key: const Key('hhk-toast-message'),
                        style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _active = entry;
    overlay.insert(entry);
    _dismissTimer = Timer(const Duration(seconds: 4), dismiss);
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _active?.remove();
    _active?.dispose();
    _active = null;
  }
}
