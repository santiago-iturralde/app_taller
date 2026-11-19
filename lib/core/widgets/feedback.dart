import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/db.dart';
import '../theme/app_theme.dart';

/// Mensaje breve en la parte inferior. Usar [error] para fallas.
void mostrarMensaje(BuildContext context, String texto, {bool error = false, SnackBarAction? accion}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final colores = context.colores;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: error ? colores.peligroSuave : colores.exitoSuave, size: 20),
          const SizedBox(width: Espacio.m),
          Expanded(child: Text(texto)),
        ],
      ),
      action: accion,
      duration: Duration(seconds: error ? 5 : 3),
      width: context.esEscritorio ? 440 : null,
    ));
}

/// Traduce errores técnicos a un mensaje entendible.
String mensajeDeError(Object error) {
  if (error is ErrorDeNegocio) return error.mensaje;
  // Los mensajes del servidor ya están pensados para mostrarse.
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'unauthenticated' => 'Tu sesión venció. Volvé a ingresar.',
      'internal' when (error.message ?? '').toLowerCase() == 'internal' => 'Ocurrió un error en el servidor. Probá de nuevo.',
      'unavailable' when (error.message ?? '').isEmpty => 'El servidor no está disponible. Probá de nuevo en unos minutos.',
      _ => error.message ?? 'Ocurrió un error en el servidor.',
    };
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => 'No tenés permiso para realizar esta acción.',
      'unavailable' => 'Sin conexión. Revisá tu internet e intentá de nuevo.',
      'failed-precondition' => 'La base de datos se está preparando. Probá en unos minutos.',
      'not-found' => 'El registro ya no existe.',
      _ => 'Ocurrió un error (${error.code}). Intentá nuevamente.',
    };
  }
  if (error is FirebaseAuthException) return error.message ?? 'Error de autenticación.';
  return 'Ocurrió un error inesperado. Intentá nuevamente.';
}

/// Ejecuta [accion] mostrando el resultado. Devuelve `true` si salió bien.
Future<bool> ejecutar(BuildContext context, Future<void> Function() accion, {String? exito}) async {
  try {
    await accion();
    if (exito != null && context.mounted) mostrarMensaje(context, exito);
    return true;
  } catch (e, st) {
    debugPrint('Error: $e\n$st');
    if (context.mounted) mostrarMensaje(context, mensajeDeError(e), error: true);
    return false;
  }
}

/// Diálogo de confirmación. Devuelve `true` sólo si el usuario confirma.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String confirmar = 'Confirmar',
  bool peligroso = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(
          style: peligroso ? FilledButton.styleFrom(backgroundColor: context.colores.peligro) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmar),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Abre un formulario: página completa en celular, diálogo en escritorio.
Future<T?> abrirFormulario<T>(BuildContext context, Widget formulario) {
  if (context.esEscritorio) {
    return showDialog<T>(
      context: context,
      builder: (context) {
        final alto = MediaQuery.sizeOf(context).height;
        return Dialog(
          insetPadding: const EdgeInsets.all(Espacio.xl),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 680, maxHeight: alto * 0.9),
            child: formulario,
          ),
        );
      },
    );
  }
  return Navigator.of(context).push<T>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => formulario));
}

/// Abre una pantalla de detalle (siempre como página).
Future<T?> abrirPagina<T>(BuildContext context, Widget pagina) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => pagina));
