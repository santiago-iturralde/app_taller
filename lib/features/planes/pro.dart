import 'package:flutter/material.dart';

import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/negocio.dart';
import 'planes_page.dart';

/// Devuelve `true` si el negocio puede usar [funcion]. Si no, muestra la
/// invitación a pasarse a PRO y devuelve `false`.
Future<bool> exigirPro(BuildContext context, FuncionPro funcion) async {
  if (Sesion.of(context).negocio.permite(funcion)) return true;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: IconoTile(Icons.workspace_premium_rounded, color: context.colores.pro, fondo: context.colores.proSuave, tamanio: 56),
      title: Text('${funcion.nombre} es una función PRO'),
      content: const Text(
        'Con el plan PRO tenés reportes, recibos impresos, exportación a Excel y todo lo que vayamos sumando.',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ahora no')),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            abrirPagina(context, const PlanesPage());
          },
          child: const Text('Ver planes'),
        ),
      ],
    ),
  );
  return false;
}
