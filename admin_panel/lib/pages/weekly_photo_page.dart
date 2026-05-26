import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';



import '../models/admin_models.dart';

import '../services/admin_repository.dart';

import '../widgets/admin_layout.dart';

import '../widgets/admin_pagination.dart';

import '../widgets/admin_storage_image.dart';

import '../widgets/confirm_dialog.dart';



class WeeklyPhotoPage extends StatefulWidget {

  const WeeklyPhotoPage({super.key});



  @override

  State<WeeklyPhotoPage> createState() => _WeeklyPhotoPageState();

}



class _WeeklyPhotoPageState extends State<WeeklyPhotoPage> {

  WeeklySpotlight? _spotlight;

  final _pagination = AdminPaginationState();

  List<WeeklyCandidate> _candidates = [];

  bool _loading = true;

  bool _loadingCandidates = false;

  String? _error;



  @override

  void initState() {

    super.initState();

    _loadAll();

  }



  Future<void> _loadCandidatesPage() async {

    setState(() => _loadingCandidates = true);

    try {

      final result = await AdminRepository.instance.fetchWeeklyCandidatesPage(

        pageSize: _pagination.pageSize,

        newestFirst: _pagination.newestFirst,

        startAfter: _pagination.startAfter,

      );

      _pagination.applyPage(

        more: result.hasMore,

        lastDocument: result.lastDocument,

      );

      _candidates = result.items;

    } catch (e) {

      _error = e.toString();

      _candidates = [];

    } finally {

      if (mounted) setState(() => _loadingCandidates = false);

    }

  }



  Future<void> _loadAll() async {

    setState(() {
      _loading = true;
      _error = null;
    });

    try {

      final repo = AdminRepository.instance;

      _spotlight = await repo.fetchWeeklySpotlight();

      await _loadCandidatesPage();

    } catch (e) {

      _error = e.toString();

    } finally {

      if (mounted) setState(() => _loading = false);

    }

  }



  void _onSortChanged(bool newestFirst) {

    _pagination.setNewestFirst(newestFirst);

    _loadCandidatesPage();

  }



  void _goNext() {

    _pagination.nextPage();

    _loadCandidatesPage();

  }



  void _goPrevious() {

    _pagination.previousPage();

    _loadCandidatesPage();

  }



  Widget _headerActions() {

    return AdminPageHeader(

      title: 'Weekly Photo',

      actions: [

        FilledButton.icon(

          onPressed: () async {

            final ok = await showConfirmDialog(

              context,

              title: 'Force draw',

              message: 'Run weekly photo draw now?',

              confirmLabel: 'Draw',

            );

            if (!ok) return;

            await AdminRepository.instance.forceWeeklyDraw();

            await _loadAll();

          },

          icon: const Icon(Icons.casino),

          label: const Text('Force weekly draw'),

        ),

        IconButton(
          onPressed: () {
            _pagination.reset();
            _loadAll();
          },
          icon: const Icon(Icons.refresh),
        ),

      ],

    );

  }



  Widget _candidateTile(WeeklyCandidate c) {

    return ListTile(

      leading: AdminStorageImage(

        httpsUrl: c.photoUrl,

        userId: c.userId,

        babyId: c.babyId,

        badgeId: c.badgeId,

        publicMemoryDocId: c.memoryId,

        width: 56,

        height: 56,

        borderRadius: BorderRadius.circular(8),

      ),

      title: Text('${c.babyName} — ${c.userName}'),

      subtitle: Text('${c.email}\n${c.title}\nLikes: ${c.likes} · Eligible: ${c.eligible}'),

      isThreeLine: true,

      trailing: PopupMenuButton<String>(

        onSelected: (v) async {

          final repo = AdminRepository.instance;

          switch (v) {

            case 'winner':

              await repo.setWeeklyWinner(c.memoryId, c.userId);

              await _loadAll();

            case 'family':

              context.go('/users/${c.userId}');

            case 'hide':

              await repo.hidePublicMemory(c.memoryId);

              await _loadAll();

          }

        },

        itemBuilder: (_) => const [

          PopupMenuItem(value: 'winner', child: Text('Choose as winner')),

          PopupMenuItem(value: 'family', child: Text('Open family')),

          PopupMenuItem(value: 'hide', child: Text('Disable photo')),

        ],

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    final bottomInset = MediaQuery.paddingOf(context).bottom;



    return AdminPagePadding(

      child: CustomScrollView(

        slivers: [

          SliverToBoxAdapter(child: _headerActions()),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          if (_loading)

            const SliverFillRemaining(

              hasScrollBody: false,

              child: Center(child: CircularProgressIndicator()),

            )

          else if (_error != null)

            SliverToBoxAdapter(

              child: Card(

                child: Padding(

                  padding: const EdgeInsets.all(20),

                  child: SelectableText(

                    _error!,

                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),

                  ),

                ),

              ),

            )

          else ...[

            if (_spotlight != null)

              SliverToBoxAdapter(child: _winnerCard(_spotlight!, fmt)),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            const SliverToBoxAdapter(

              child: Text('Candidates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),

            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            SliverToBoxAdapter(

              child: AdminPaginationBar(

                pageIndex: _pagination.pageIndex,

                pageSize: _pagination.pageSize,

                canGoPrevious: _pagination.canGoPrevious,

                canGoNext: _pagination.canGoNext,

                newestFirst: _pagination.newestFirst,

                onNewestFirstChanged: _onSortChanged,

                onPrevious: _goPrevious,

                onNext: _goNext,

              ),

            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            if (_loadingCandidates)

              const SliverToBoxAdapter(

                child: Padding(

                  padding: EdgeInsets.all(24),

                  child: Center(child: CircularProgressIndicator()),

                ),

              )

            else

            SliverToBoxAdapter(

              child: Card(

                clipBehavior: Clip.antiAlias,

                child: Column(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    for (var i = 0; i < _candidates.length; i++) ...[

                      if (i > 0) const Divider(height: 1),

                      _candidateTile(_candidates[i]),

                    ],

                    if (_candidates.isEmpty)

                      const Padding(

                        padding: EdgeInsets.all(24),

                        child: Center(child: Text('No candidates')),

                      ),

                  ],

                ),

              ),

            ),

            SliverToBoxAdapter(child: SizedBox(height: bottomInset + 24)),

          ],

        ],

      ),

    );

  }



  Widget _winnerCard(WeeklySpotlight s, DateFormat fmt) {

    final compact = !AdminLayout.isWide(context) && MediaQuery.sizeOf(context).width < 720;

    final photoSize = compact

        ? (MediaQuery.sizeOf(context).width - AdminLayout.pagePadding(context).horizontal - 40)

            .clamp(120.0, 280.0)

        : 120.0;

    final details = Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Text('Week: ${s.weekId}', style: const TextStyle(fontWeight: FontWeight.w800)),

        Text('Status: ${s.active ? 'active' : 'inactive'}'),

        Text('Baby: ${s.babyName}'),

        Text('Family: ${s.userName} · ${s.email}'),

        Text('Badge: ${s.badgeTitle}'),

        Text('Memory ID: ${s.publicMemoryId}', maxLines: 2, overflow: TextOverflow.ellipsis),

        Text('User ID: ${s.userId}', maxLines: 1, overflow: TextOverflow.ellipsis),

        Text('Draw: ${s.drawnAt != null ? fmt.format(s.drawnAt!) : '—'}'),

        Text('Until: ${s.displayUntil != null ? fmt.format(s.displayUntil!) : '—'}'),

      ],

    );

    final removeBtn = OutlinedButton(

      onPressed: () async {

        await AdminRepository.instance.removeWeeklyWinner();

        await _loadAll();

      },

      child: const Text('Remove winner'),

    );

    final photo = AdminStorageImage(

      httpsUrl: s.photoUrl,

      userId: s.userId,

      babyId: s.babyId,

      badgeId: s.badgeId,

      publicMemoryDocId: s.publicMemoryId,

      width: photoSize,

      height: photoSize,

      borderRadius: BorderRadius.circular(12),

    );



    return Card(

      child: Padding(

        padding: const EdgeInsets.all(20),

        child: compact

            ? Column(

                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [

                  photo,

                  const SizedBox(height: 16),

                  details,

                  const SizedBox(height: 12),

                  removeBtn,

                ],

              )

            : Row(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  photo,

                  const SizedBox(width: 20),

                  Expanded(child: details),

                  const SizedBox(width: 12),

                  removeBtn,

                ],

              ),

      ),

    );

  }

}


