import 'package:flutter/material.dart';

class MagazineMemoryLayout extends StatelessWidget {
  final Widget photo;
  final Widget body;

  const MagazineMemoryLayout({super.key, required this.photo, required this.body});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 600;
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(20), child: photo),
              const SizedBox(height: 14),
              body,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(aspectRatio: 4 / 5, child: photo),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEEE6F6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(14),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: body,
              ),
            ),
          ],
        );
      },
    );
  }
}

