import 'package:flutter/material.dart';

import 'face_baby_loading.dart';

class LoadingController extends ChangeNotifier {
  int _count = 0;
  String? _label;

  bool get isLoading => _count > 0;
  String? get label => _label;

  void show([String? label]) {
    _count++;
    if ((label ?? '').trim().isNotEmpty) {
      _label = label!.trim();
    }
    notifyListeners();
  }

  void hide() {
    if (_count <= 0) return;
    _count--;
    if (_count == 0) _label = null;
    notifyListeners();
  }

  Future<T> run<T>(
    Future<T> Function() action, {
    String? label,
  }) async {
    show(label);
    try {
      return await action();
    } finally {
      hide();
    }
  }
}

class LoadingScope extends StatefulWidget {
  final Widget child;

  const LoadingScope({super.key, required this.child});

  static LoadingController? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_LoadingInherited>();
    return scope?.notifier;
  }

  static LoadingController of(BuildContext context) {
    final c = maybeOf(context);
    assert(c != null, 'LoadingScope.of() called with no LoadingScope in context.');
    return c!;
  }

  @override
  State<LoadingScope> createState() => _LoadingScopeState();
}

class _LoadingScopeState extends State<LoadingScope> {
  final LoadingController _controller = LoadingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _LoadingInherited(
      notifier: _controller,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              widget.child,
              FaceBabyLoadingOverlay(visible: _controller.isLoading, label: _controller.label),
            ],
          );
        },
      ),
    );
  }
}

class _LoadingInherited extends InheritedNotifier<LoadingController> {
  const _LoadingInherited({required super.notifier, required super.child});
}

