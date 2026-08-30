import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';

void main() {
  Widget buildSheet({
    bool showDocument = true,
    bool showCamera = true,
    bool showGallery = true,
    bool showAudio = true,
    ThemeMode themeMode = ThemeMode.light,
    ValueChanged<AttachmentOption?>? onSelected,
  }) {
    return MaterialApp(
      themeMode: themeMode,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return Center(
              child: ElevatedButton(
                onPressed: () async {
                  final option = await showModalBottomSheet<AttachmentOption>(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => AttachmentPickerSheet(
                      showDocument: showDocument,
                      showCamera: showCamera,
                      showGallery: showGallery,
                      showAudio: showAudio,
                    ),
                  );
                  onSelected?.call(option);
                },
                child: const Text('Open Sheet'),
              ),
            );
          },
        ),
      ),
    );
  }

  testWidgets('renders Document, Camera, Gallery, and Audio items by default', (tester) async {
    await tester.pumpWidget(buildSheet());
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.byType(AttachmentPickerSheet), findsOneWidget);
    expect(find.text('Document'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
  });

  testWidgets('hides Document item when showDocument is false', (tester) async {
    await tester.pumpWidget(buildSheet(showDocument: false));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Document'), findsNothing);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
  });

  testWidgets('selecting Camera pops with AttachmentOption.camera', (tester) async {
    AttachmentOption? selected;
    await tester.pumpWidget(buildSheet(onSelected: (val) => selected = val));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();

    expect(selected, AttachmentOption.camera);
    expect(find.byType(AttachmentPickerSheet), findsNothing);
  });

  testWidgets('selecting Gallery pops with AttachmentOption.gallery', (tester) async {
    AttachmentOption? selected;
    await tester.pumpWidget(buildSheet(onSelected: (val) => selected = val));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();

    expect(selected, AttachmentOption.gallery);
    expect(find.byType(AttachmentPickerSheet), findsNothing);
  });

  testWidgets('selecting Audio pops with AttachmentOption.audio', (tester) async {
    AttachmentOption? selected;
    await tester.pumpWidget(buildSheet(onSelected: (val) => selected = val));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Audio'));
    await tester.pumpAndSettle();

    expect(selected, AttachmentOption.audio);
    expect(find.byType(AttachmentPickerSheet), findsNothing);
  });

  testWidgets('selecting Document pops with AttachmentOption.document', (tester) async {
    AttachmentOption? selected;
    await tester.pumpWidget(
      buildSheet(
        showDocument: true,
        onSelected: (val) => selected = val,
      ),
    );
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Document'));
    await tester.pumpAndSettle();

    expect(selected, AttachmentOption.document);
    expect(find.byType(AttachmentPickerSheet), findsNothing);
  });

  testWidgets('renders correctly in dark mode', (tester) async {
    await tester.pumpWidget(buildSheet(themeMode: ThemeMode.dark));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.byType(AttachmentPickerSheet), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
  });
}
