import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Estado de paginação por cursor (10 itens por página).
class AdminPaginationState {
  AdminPaginationState({this.pageSize = 10});

  final int pageSize;
  bool newestFirst = true;
  int pageIndex = 0;
  final List<DocumentSnapshot<Map<String, dynamic>>?> _cursors = [null];
  bool hasMore = false;

  DocumentSnapshot<Map<String, dynamic>>? get startAfter => _cursors[pageIndex];

  bool get canGoPrevious => pageIndex > 0;
  bool get canGoNext => hasMore;

  int get displayPage => pageIndex + 1;

  void applyPage({
    required bool more,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
  }) {
    hasMore = more;
    if (lastDocument == null) return;
    final nextIndex = pageIndex + 1;
    while (_cursors.length <= nextIndex) {
      _cursors.add(null);
    }
    _cursors[nextIndex] = lastDocument;
  }

  void setNewestFirst(bool value) {
    if (newestFirst == value) return;
    newestFirst = value;
    reset();
  }

  void reset() {
    pageIndex = 0;
    _cursors
      ..clear()
      ..add(null);
    hasMore = false;
  }

  void nextPage() {
    if (!hasMore) return;
    pageIndex++;
  }

  void previousPage() {
    if (pageIndex <= 0) return;
    pageIndex--;
  }
}

/// Barra: ordenação + anterior/próxima + número da página.
class AdminPaginationBar extends StatelessWidget {
  const AdminPaginationBar({
    super.key,
    required this.pageIndex,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.newestFirst,
    required this.onNewestFirstChanged,
    required this.onPrevious,
    required this.onNext,
    this.pageSize = 10,
  });

  final int pageIndex;
  final bool canGoPrevious;
  final bool canGoNext;
  final bool newestFirst;
  final ValueChanged<bool> onNewestFirstChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final int pageSize;

  @override
  Widget build(BuildContext context) {
    final sortLabel = newestFirst ? 'Newest first' : 'Oldest first';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '$pageSize per page · Page ${pageIndex + 1}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            OutlinedButton.icon(
              onPressed: canGoPrevious ? onPrevious : null,
              icon: const Icon(Icons.chevron_left, size: 20),
              label: const Text('Previous'),
            ),
            OutlinedButton.icon(
              onPressed: canGoNext ? onNext : null,
              icon: const Icon(Icons.chevron_right, size: 20),
              label: const Text('Next'),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.sort, size: 18),
            Text(sortLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Newest'),
                  icon: Icon(Icons.arrow_downward, size: 16),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Oldest'),
                  icon: Icon(Icons.arrow_upward, size: 16),
                ),
              ],
              selected: {newestFirst},
              onSelectionChanged: (s) {
                if (s.isEmpty) return;
                onNewestFirstChanged(s.first);
              },
            ),
          ],
        ),
      ),
    );
  }
}
