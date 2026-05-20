import 'dart:io';
import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../../services/memory_album_image_cache.dart';
import '../../services/memory_album_pdf_generator.dart';
import '../../services/memory_album_pdf_quality.dart';
import '../../theme/app_theme.dart';
import '../../utils/memory_album_pdf.dart';
import '../../utils/memory_share_transport.dart';
import '../../utils/portal_layout.dart';

/// Gera o PDF do álbum com progresso, cancelamento e ecrã final de partilha.
class MemoryAlbumExportPage extends StatefulWidget {
  const MemoryAlbumExportPage({
    super.key,
    required this.babyName,
    required this.strings,
    required this.labels,
    required this.pages,
    required this.quality,
  });

  final String babyName;
  final MemoryAlbumPdfStrings strings;
  final MemoryAlbumPdfPageLabels labels;
  final List<MemoryAlbumPageInput> pages;
  final MemoryAlbumPdfQuality quality;

  @override
  State<MemoryAlbumExportPage> createState() => _MemoryAlbumExportPageState();
}

class _MemoryAlbumExportPageState extends State<MemoryAlbumExportPage> {
  final _cancelToken = MemoryAlbumCancelToken();
  MemoryAlbumGenerationProgress? _progress;
  MemoryAlbumGenerateResult? _result;
  String? _errorMessage;
  bool _running = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    try {
      final result = await MemoryAlbumPdfGenerator.instance.generate(
        babyName: widget.babyName,
        strings: widget.strings,
        labels: widget.labels,
        pages: widget.pages,
        quality: widget.quality,
        cancelToken: _cancelToken,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _running = false;
      });
      if (result.skippedImages > 0) {
        final s = S.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.memoriesAlbumSkippedImages(result.skippedImages)),
          ),
        );
      }
    } on MemoryAlbumCanceledException {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).memoriesAlbumCanceled)),
      );
    } on MemoryAlbumNetworkException {
      _fail(S.of(context).memoriesAlbumErrorNetwork);
    } on MemoryAlbumStorageException {
      _fail(S.of(context).memoriesAlbumErrorStorage);
    } catch (e) {
      _fail('${S.of(context).memoriesAlbumError} ($e)');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _running = false;
    });
  }

  void _onCancel() {
    _cancelToken.cancel();
    if (!_running) {
      Navigator.pop(context);
      return;
    }
  }

  String _statusText(S s, MemoryAlbumGenerationProgress p) {
    switch (p.phase) {
      case MemoryAlbumGenerationPhase.preparing:
        return s.memoriesAlbumProgressPreparing;
      case MemoryAlbumGenerationPhase.images:
        return s.memoriesAlbumProgressImages(
          p.imageCurrent ?? 0,
          p.imageTotal ?? 0,
        );
      case MemoryAlbumGenerationPhase.building:
        return s.memoriesAlbumProgressBuilding(
          p.buildCurrent ?? 0,
          p.buildTotal ?? 0,
        );
      case MemoryAlbumGenerationPhase.saving:
        return s.memoriesAlbumProgressSaving;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final progress = _progress;
    final fraction = progress?.overallFraction ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.memoriesAlbumExportTitle),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _onCancel,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _result != null
              ? _ReadyPanel(
                  filePath: _result!.filePath,
                  onShare: () => sharePdfFile(_result!.filePath),
                  onCopyToDownloads: () async {
                    try {
                      final bytes = await File(_result!.filePath).readAsBytes();
                      await savePdfBytes(bytes, _result!.fileName);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s.memoriesAlbumSavedSnack)),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('${s.memoriesAlbumSaveFailedSnack} ($e)'),
                        ),
                      );
                    }
                  },
                )
              : _errorMessage != null
                  ? _ErrorPanel(
                      message: _errorMessage!,
                      onClose: () => Navigator.pop(context),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 32),
                        Icon(
                          Icons.menu_book_rounded,
                          size: 56,
                          color: AppTheme.primaryPink.withAlpha(200),
                        ),
                        const SizedBox(height: 28),
                        LinearProgressIndicator(
                          value: fraction > 0 ? fraction : null,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          progress != null
                              ? _statusText(s, progress)
                              : s.memoriesAlbumProgressPreparing,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: portalSp(context, 15),
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: _onCancel,
                          child: Text(s.memoriesAlbumCancelBtn),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _ReadyPanel extends StatelessWidget {
  const _ReadyPanel({
    required this.filePath,
    required this.onShare,
    required this.onCopyToDownloads,
  });

  final String filePath;
  final VoidCallback onShare;
  final Future<void> Function() onCopyToDownloads;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Icon(Icons.check_circle_rounded,
            size: 64, color: AppTheme.mint.withAlpha(230)),
        const SizedBox(height: 20),
        Text(
          s.memoriesAlbumPdfReadyTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          filePath,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: portalSp(context, 12),
            color: AppTheme.textSecondary,
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: onShare,
          icon: const Icon(Icons.ios_share_rounded),
          label: Text(s.memoriesAlbumShareAction),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => onCopyToDownloads(),
          icon: const Icon(Icons.download_rounded),
          label: Text(s.memoriesAlbumSaveAction),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Icon(Icons.error_outline_rounded,
            size: 56, color: Colors.red.shade300),
        const SizedBox(height: 20),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: portalSp(context, 15),
            color: AppTheme.textPrimary,
          ),
        ),
        const Spacer(),
        FilledButton(onPressed: onClose, child: Text(S.of(context).cancel)),
      ],
    );
  }
}
