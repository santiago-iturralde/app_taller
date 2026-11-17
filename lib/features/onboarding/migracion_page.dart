import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/migracion_legacy.dart';

/// Pasa los datos del sistema anterior al nuevo formato. Es automático,
/// no borra nada y se puede reintentar sin duplicar información.
class MigracionPage extends StatefulWidget {
  const MigracionPage({super.key, required this.usuario, required this.onListo});
  final User usuario;
  final VoidCallback onListo;

  @override
  State<MigracionPage> createState() => _MigracionPageState();
}

class _MigracionPageState extends State<MigracionPage> {
  double _progreso = 0;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _migrar();
  }

  Future<void> _migrar() async {
    setState(() {
      _error = null;
      _progreso = 0.02;
    });
    try {
      await MigracionLegacy().migrar(
        uid: widget.usuario.uid,
        email: widget.usuario.email ?? '',
        progreso: (p) {
          if (mounted) setState(() => _progreso = p);
        },
      );
      if (mounted) widget.onListo();
    } catch (e, st) {
      debugPrint('Migración: $e\n$st');
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Espacio.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconoTile(_error == null ? Icons.auto_awesome_rounded : Icons.error_outline_rounded, tamanio: 72,
                    color: _error == null ? context.esquema.primary : context.colores.peligro),
                const SizedBox(height: Espacio.xl),
                Text(
                  _error == null ? 'Estamos actualizando tu sistema' : 'No pudimos terminar la actualización',
                  style: context.textos.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Espacio.s),
                Text(
                  _error == null
                      ? 'Pasamos tus clientes, trabajos, presupuestos y gastos al nuevo formato. '
                          'Tarda unos segundos y no se pierde nada.'
                      : '${mensajeDeError(_error!)}\nTus datos están a salvo: podés reintentar sin problema.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.esquema.onSurfaceVariant, height: 1.45),
                ),
                const SizedBox(height: Espacio.xl),
                if (_error == null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: _progreso, minHeight: 8),
                  )
                else
                  Wrap(spacing: Espacio.s, children: [
                    FilledButton.icon(onPressed: _migrar, icon: const Icon(Icons.refresh_rounded), label: const Text('Reintentar')),
                    TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Salir')),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
