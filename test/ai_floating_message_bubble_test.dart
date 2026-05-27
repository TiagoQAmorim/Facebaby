import 'package:cached_network_image/cached_network_image.dart';
import 'package:facebaby_flutter/models/floating_message_model.dart';
import 'package:facebaby_flutter/widgets/ai/ai_floating_message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const promoImage =
      'https://firebasestorage.googleapis.com/v0/b/demo/o/banner.jpg';

  Widget harness({
    required bool expanded,
    bool showDismissZone = false,
    VoidCallback? onToggleExpanded,
    void Function(Offset)? onPositionChanged,
    VoidCallback? onActionTap,
    VoidCallback? onCloseTap,
    VoidCallback? onDismissDrag,
    VoidCallback? onDragStarted,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 720,
          child: AiFloatingMessageBubble(
            title: 'FaceBaby Plus',
            message: 'Conheça os planos',
            collapsedIcon: '📣',
            attachmentImageUrl: promoImage,
            bannerLayout: true,
            promoLayout: false,
            hasActionButton: true,
            actionLinkLabel: 'Ver planos',
            position: const Offset(48, 120),
            expanded: expanded,
            onToggleExpanded: onToggleExpanded ?? () {},
            onPositionChanged: onPositionChanged ?? (_) {},
            onDismissDrag: onDismissDrag ?? () {},
            onDragEnded: () {},
            allowDragDismiss: true,
            onDragStarted: onDragStarted,
            showDismissZone: showDismissZone,
            showCloseButton: true,
            onCloseTap: onCloseTap,
            onActionTap: onActionTap,
          ),
        ),
      ),
    );
  }

  test('promo_banner type uses megaphone icon emoji', () {
    const msg = FloatingMessage(
      id: 'x',
      title: 'FaceBaby Plus',
      message: 'Conheça os planos',
      type: FloatingMessageType.promoBanner,
    );
    expect(msg.displayIcon, '📣');
  });

  test('premium_offer uses crown emoji', () {
    const msg = FloatingMessage(
      id: 'x',
      title: 'Plus',
      message: 'Oferta',
      type: FloatingMessageType.premiumOffer,
    );
    expect(msg.displayIcon, '👑');
  });

  testWidgets('minimized promo shows icon only, not banner image', (tester) async {
    await tester.pumpWidget(harness(expanded: false));
    await tester.pump();

    expect(find.text('📣'), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.text('Conheça os planos'), findsNothing);
    expect(find.text('Ver planos'), findsNothing);
  });

  testWidgets('expanded text-only message centers title and body', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 720,
            child: AiFloatingMessageBubble(
              title: 'Novidade no FaceBaby',
              message: 'teste',
              collapsedIcon: '📣',
              position: const Offset(48, 120),
              expanded: true,
              onToggleExpanded: () {},
              onPositionChanged: (_) {},
              onDismissDrag: () {},
              onDragEnded: () {},
              showDismissZone: false,
              showCloseButton: true,
              onCloseTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final titleFinder = find.text('Novidade no FaceBaby');
    final bodyFinder = find.text('teste');
    expect(titleFinder, findsOneWidget);
    expect(bodyFinder, findsOneWidget);

    final titleBox = tester.getRect(titleFinder);
    final bodyBox = tester.getRect(bodyFinder);
    final layerBox = tester.getRect(
      find.byKey(const Key('floating_message_expanded_layer')),
    );
    final titleCenterX = titleBox.center.dx;
    final bodyCenterX = bodyBox.center.dx;
    final layerCenterX = layerBox.center.dx;
    expect((titleCenterX - layerCenterX).abs(), lessThan(24));
    expect((bodyCenterX - layerCenterX).abs(), lessThan(24));
    expect(bodyBox.top, greaterThan(titleBox.bottom));
  });

  testWidgets('expanded promo shows large banner and CTA', (tester) async {
    await tester.pumpWidget(harness(expanded: true));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('FaceBaby Plus'), findsOneWidget);
    expect(find.text('Conheça os planos'), findsOneWidget);
    expect(find.text('Ver planos'), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsWidgets);
    // Minimizado no header do card: só emoji, sem segunda miniatura.
    expect(find.text('📣'), findsOneWidget);
  });

  testWidgets('tap minimized expands without CTA or dismiss', (tester) async {
    var toggled = 0;
    var actionTaps = 0;
    var dismissed = 0;

    await tester.pumpWidget(
      harness(
        expanded: false,
        onToggleExpanded: () => toggled++,
        onActionTap: () => actionTaps++,
        onDismissDrag: () => dismissed++,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('📣'));
    await tester.pump();

    expect(toggled, 1);
    expect(actionTaps, 0);
    expect(dismissed, 0);
  });

  testWidgets('dismiss strip hidden when expanded', (tester) async {
    await tester.pumpWidget(
      harness(expanded: true, showDismissZone: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    expect(find.byKey(const Key('floating_message_expanded_scrim')), findsOneWidget);
    expect(find.byKey(const Key('floating_message_expanded_layer')), findsOneWidget);
  });

  testWidgets('expanded shows scrim and cannot be dragged', (tester) async {
    var positionChanges = 0;
    await tester.pumpWidget(
      harness(
        expanded: true,
        onPositionChanged: (_) => positionChanges++,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('floating_message_expanded_scrim')), findsOneWidget);
    expect(find.byKey(const Key('floating_message_expanded_layer')), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('floating_message_expanded_layer')),
      const Offset(120, 120),
    );
    await tester.pump();
    expect(positionChanges, 0);
  });

  testWidgets('expanded close button fires onCloseTap', (tester) async {
    var closed = 0;
    await tester.pumpWidget(
      harness(
        expanded: true,
        onCloseTap: () => closed++,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(closed, 1);
  });

  test('clampCollapsedTopLeft allows full horizontal range', () {
    const viewport = Size(400, 720);
    final layout = AiFloatingMessageBubble.collapsedLayoutSize;
    const inset = AiFloatingMessageBubble.collapsedHorizontalInset;

    final left = AiFloatingMessageBubble.clampCollapsedTopLeft(
      topLeft: const Offset(0, 200),
      viewport: viewport,
    );
    expect(left.dx, inset);

    final right = AiFloatingMessageBubble.clampCollapsedTopLeft(
      topLeft: Offset(viewport.width, 200),
      viewport: viewport,
    );
    expect(right.dx, viewport.width - layout - inset);

    final center = AiFloatingMessageBubble.clampCollapsedTopLeft(
      topLeft: const Offset(150, 200),
      viewport: viewport,
    );
    expect(center.dx, 150);
  });

  test('isDroppedInDismissZone when orb center is in strip', () {
    const viewport = Size(400, 720);
    final stripTop = AiFloatingMessageBubble.dismissStripTop(viewport);
    final topLeft = Offset(168, stripTop - 8);
    expect(
      AiFloatingMessageBubble.isDroppedInDismissZone(
        topLeft: topLeft,
        viewport: viewport,
      ),
      isTrue,
    );
  });

  testWidgets('drag to dismiss strip calls onDismissDrag', (tester) async {
    var dismissed = 0;
    const viewport = Size(400, 720);
    final stripTop = AiFloatingMessageBubble.dismissStripTop(viewport);
    Offset pos = Offset(168, stripTop - 8);

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 720,
              child: AiFloatingMessageBubble(
                title: 'Test',
                message: 'Corpo',
                collapsedIcon: '📣',
                position: pos,
                expanded: false,
                allowDragDismiss: true,
                showDismissZone: true,
                onToggleExpanded: () {},
                onPositionChanged: (o) => setState(() => pos = o),
                onDismissDrag: () => dismissed++,
                onDragEnded: () {},
                onDragStarted: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.dragFrom(
      tester.getCenter(find.text('📣')),
      const Offset(0, 420),
    );
    await tester.pump();

    expect(dismissed, 1);
  });

  testWidgets('collapsed orb uses single circular DecoratedBox with shadow',
      (tester) async {
    await tester.pumpWidget(harness(expanded: false));
    await tester.pump();

    final clipOvals = tester.widgetList<ClipOval>(find.byType(ClipOval));
    expect(clipOvals, isNotEmpty);
    var foundCircularShadow = false;
    for (final decorated
        in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox))) {
      final deco = decorated.decoration;
      if (deco is BoxDecoration &&
          deco.shape == BoxShape.circle &&
          deco.boxShadow != null &&
          deco.boxShadow!.isNotEmpty &&
          deco.color != null) {
        foundCircularShadow = true;
        break;
      }
    }
    expect(foundCircularShadow, isTrue);
  });

  test('defaultCollapsedTopLeft uses baby-card fallback below greeting', () {
    const viewport = Size(390, 780);
    const safe = EdgeInsets.only(top: 44, left: 0, right: 0, bottom: 0);
    final pos = AiFloatingMessageBubble.defaultCollapsedTopLeft(
      viewport: viewport,
      safePadding: safe,
    );
    expect(
      pos.dx,
      viewport.width - AiFloatingMessageBubble.collapsedLayoutSize - 28,
    );
    expect(pos.dy, 330 + safe.top);
    expect(pos.dx, greaterThan(viewport.width * 0.5));
    expect(pos.dy, greaterThan(200));
    expect(pos.dy, lessThan(viewport.height * 0.55));
  });

  testWidgets('minimized state is circular (ClipOval), not chat square shell',
      (tester) async {
    await tester.pumpWidget(harness(expanded: false));
    await tester.pump();

    expect(find.byType(ClipOval), findsWidgets);
    expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
  });

  testWidgets('drag state stays circular with ClipOval', (tester) async {
    await tester.pumpWidget(
      harness(expanded: false, showDismissZone: true),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('📣')),
    );
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();

    expect(find.byType(ClipOval), findsWidgets);
    await gesture.up();
  });

  testWidgets('CTA tap only fires onActionTap when expanded', (tester) async {
    var toggled = 0;
    var actionTaps = 0;

    await tester.pumpWidget(
      harness(
        expanded: true,
        onToggleExpanded: () => toggled++,
        onActionTap: () => actionTaps++,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.widgetWithText(FilledButton, 'Ver planos'));
    await tester.pump();

    expect(actionTaps, 1);
    expect(toggled, lessThanOrEqualTo(1));
  });
}
