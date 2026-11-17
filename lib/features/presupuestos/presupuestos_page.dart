import 'package:flutter/material.dart';

import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/campos.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/presupuesto.dart';
import 'presupuesto_detalle_page.dart';
import 'presupuesto_form.dart';
import 'widgets_presupuesto.dart';

Future<void> nuevoPresupuesto(BuildContext context) async {
  final p = await abrirFormulario<Presupuesto>(context, const PresupuestoForm());
  if (p != null && context.mounted) abrirPagina(context, PresupuestoDetallePage(presupuestoId: p.id));
}

class PresupuestosPage extends StatefulWidget {
  const PresupuestosPage({super.key});

  @override
  State<PresupuestosPage> createState() => _PresupuestosPageState();
}

class _PresupuestosPageState extends State<PresupuestosPage> {
  EstadoPresupuesto? _filtro;
  String _consulta = '';
  Future<List<Presupuesto>>? _busqueda;
  int _limite = 60;

  void _buscar(String q) => setState(() {
        _consulta = q;
        _busqueda = q.isEmpty ? null : Sesion.of(context).presupuestos.buscar(q);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Presupuestos')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-presupuestos',
        onPressed: () => nuevoPresupuesto(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo presupuesto'),
      ),
      body: ContenidoCentrado(
        anchoMaximo: 920,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Espacio.l, Espacio.l, Espacio.l, Espacio.s),
              child: Buscador(onBuscar: _buscar, hint: 'Buscar por cliente o N°'),
            ),
            if (_busqueda == null)
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Espacio.l, vertical: Espacio.xs),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: Espacio.s),
                      child: FilterChip(
                        label: const Text('Todos'),
                        selected: _filtro == null,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _filtro = null),
                      ),
                    ),
                    for (final e in EstadoPresupuesto.values)
                      Padding(
                        padding: const EdgeInsets.only(right: Espacio.s),
                        child: FilterChip(
                          label: Text(e.etiqueta),
                          avatar: Icon(e.icono, size: 16),
                          selected: _filtro == e,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _filtro = _filtro == e ? null : e),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(child: _contenido()),
          ],
        ),
      ),
    );
  }

  Widget _contenido() {
    if (_busqueda != null) {
      return FutureBuilder<List<Presupuesto>>(
        future: _busqueda,
        builder: (context, s) {
          if (s.hasError) return const EstadoError();
          if (!s.hasData) return const Cargando();
          return _lista(s.data!, EstadoVacio(icono: Icons.search_off_rounded, titulo: 'Sin resultados para "$_consulta"'));
        },
      );
    }
    return StreamBuilder<List<Presupuesto>>(
      stream: Sesion.of(context).presupuestos.recientes(limite: _limite),
      builder: (context, s) {
        if (s.hasError) return EstadoError(error: s.error);
        if (!s.hasData) return const Cargando();
        final lista = _filtro == null ? s.data! : s.data!.where((p) => p.estado == _filtro).toList();
        return _lista(
          lista,
          EstadoVacio(
            icono: Icons.request_quote_outlined,
            titulo: _filtro == null ? 'Sin presupuestos' : 'Sin presupuestos ${_filtro!.etiqueta.toLowerCase()}s',
            mensaje: _filtro == null ? 'Armá presupuestos prolijos en PDF y mandalos por WhatsApp.' : null,
          ),
          hayMas: s.data!.length >= _limite,
        );
      },
    );
  }

  Widget _lista(List<Presupuesto> lista, Widget vacio, {bool hayMas = false}) {
    if (lista.isEmpty) return vacio;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Espacio.l, Espacio.s, Espacio.l, 96),
      itemCount: lista.length + (hayMas ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: Espacio.s),
      itemBuilder: (context, i) {
        if (i == lista.length) {
          return Center(child: TextButton(onPressed: () => setState(() => _limite += 60), child: const Text('Cargar más')));
        }
        final p = lista[i];
        return TarjetaPresupuesto(presupuesto: p, onTap: () => abrirPagina(context, PresupuestoDetallePage(presupuestoId: p.id)));
      },
    );
  }
}
