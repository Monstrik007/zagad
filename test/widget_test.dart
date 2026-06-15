import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zagad/game/game_controller.dart';
import 'package:zagad/main.dart';

void main() {
  testWidgets('App loads home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GameController(),
        child: const ZagadApp(),
      ),
    );
    expect(find.text('Загадчики'), findsOneWidget);
    expect(find.text('Создать комнату'), findsOneWidget);
  });
}
