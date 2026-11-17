import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:taller_reparaciones/core/theme/app_theme.dart';
import 'package:taller_reparaciones/core/widgets/editor_items.dart';
import 'package:taller_reparaciones/data/models/comunes.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_AR'));

  Widget envolver(Widget child) => MaterialApp(
        theme: ThemeData(extensions: const [AppColors.claro]),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  testWidgets('EditorItems calcula el total en vivo', (tester) async {
    List<ItemLinea> ultimo = const [];
    await tester.pumpWidget(envolver(EditorItems(
      inicial: const [],
      sugerencias: const ['Mano de obra'],
      onCambio: (i) => ultimo = i,
    )));

    // Atajo de sugerencia: agrega la línea con la descripción cargada.
    await tester.tap(find.text('Mano de obra'));
    await tester.pumpAndSettle();
    expect(ultimo.single.descripcion, 'Mano de obra');

    await tester.enterText(find.widgetWithText(TextFormField, 'Precio unit.'), '15.000');
    await tester.enterText(find.widgetWithText(TextFormField, 'Cant.'), '2');
    await tester.pumpAndSettle();

    expect(ultimo.single.subtotal, 30000);
    expect(find.text(r'$ 30.000'), findsWidgets); // subtotal y total

    await tester.tap(find.byTooltip('Quitar ítem'));
    await tester.pumpAndSettle();
    expect(ultimo, isEmpty);
    expect(find.text(r'$ 0'), findsOneWidget);
  });
}
