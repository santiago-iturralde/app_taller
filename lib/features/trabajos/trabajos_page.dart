import 'package:flutter/material.dart';

import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/campos.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/orden.dart';
import 'orden_detalle_page.dart';
import 'orden_form.dart';
import 'widgets_orden.dart';

Future<void> nuevoTrabajo(BuildContext context) async {
  final o = await abrirFormulario<Orden>(context, const OrdenForm());
  if (o != null && context.mounted) abrirPagina(context, OrdenDetallePage(ordenId: o.id));
}

class TrabajosPage extends StatefulWidget {
  const TrabajosPage({super.key, this.filtroInicial});

  /// Permite abrir la lista ya filtrada (por ejemplo desde el inicio).
  final EstadoOrden? filtroInicial;

  @override
  State<TrabajosPage> createState() => _TrabajosPageState();
}

enum _Vista { enCurso, historial }

class _TrabajosPageState extends State<TrabajosPage> {
  _Vista _vista = _Vista.enCurso;
  late EstadoOrden? _filtro = widget.filtroInicial;
  String _consulta = '';
  Future<List<Orden>>? _busqueda;
  int _limiteHistorial = 40;

  void _buscar(String q) => setState(() {
        _consulta = q;
        _busqueda = q.isEmpty ? null : Sesion.of(context).ordenes.buscar(q);
      });

  @override
  Widget build(BuildContext context) {
    final rubro = Sesion.of(context).negocio.rubro;
    return Scaffold(
      appBar: AppBar(title: const Text('Trabajos')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-trabajos',
        onPressed: () => nuevoTrabajo(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo trabajo'),
      ),
      body: ContenidoCentrado(
        anchoMaximo: 920,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Espacio.l, Espacio.l, Espacio.l, Espacio.s),
              child: Buscador(
                onBuscar: _buscar,
                hint: 'Buscar por cliente, ${rubro.equipo.toLowerCase()}, ${rubro.identificador.toLowerCase()} o N°',
              ),
            ),
            if (_busqueda == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Espacio.l, vertical: Espacio.s),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_Vista>(
                    segments: const [
                      ButtonSegment(value: _Vista.enCurso, label: Text('En curso'), icon: Icon(Icons.pending_actions_rounded)),
                      ButtonSegment(value: _Vista.historial, label: Text('Historial'), icon: Icon(Icons.history_rounded)),
                    ],
                    selected: {_vista},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => _vista = s.first),
                  ),
                ),
              ),
            Expanded(child: _contenido()),
          ],
        ),
      ),
    );
  }

  Widget _contenido() {
    final sesion = Sesion.of(context);
    if (_busqueda != null) {
      return FutureBuilder<List<Orden>>(
        future: _busqueda,
        builder: (context, s) {
          if (s.hasError) return const EstadoError();
          if (!s.hasData) return const Cargando();
          return _Lista(
            ordenes: s.data!,
            vacio: EstadoVacio(icono: Icons.search_off_rounded, titulo: 'Sin resultados para "$_consulta"'),
          );
        },
      );
    }

    if (_vista == _Vista.historial) {
      return StreamBuilder<List<Orden>>(
        stream: sesion.ordenes.cerradas(limite: _limiteHistorial),
        builder: (context, s) {
          if (s.hasError) return EstadoError(error: s.error);
          if (!s.hasData) return const Cargando();
          return _Lista(
            ordenes: s.data!,
            hayMas: s.data!.length >= _limiteHistorial,
            onMas: () => setState(() => _limiteHistorial += 40),
            vacio: const EstadoVacio(
              icono: Icons.history_rounded,
              titulo: 'Sin trabajos cerrados',
              mensaje: 'Acá vas a ver los trabajos entregados y cancelados.',
            ),
          );
        },
      );
    }

    return StreamBuilder<List<Orden>>(
      stream: sesion.ordenes.activas(),
      builder: (context, s) {
        if (s.hasError) return EstadoError(error: s.error);
        if (!s.hasData) return const Cargando();
        final todas = s.data!;
        final conteo = {for (final e in EstadoOrden.activos) e: todas.where((o) => o.estado == e).length};
        final filtradas = _filtro == null ? todas : todas.where((o) => o.estado == _filtro).toList();
        return Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Espacio.l, vertical: Espacio.xs),
                children: [
                  _Filtro(texto: 'Todos', cantidad: todas.length, activo: _filtro == null, onTap: () => setState(() => _filtro = null)),
                  for (final e in EstadoOrden.activos)
                    _Filtro(
                      texto: e.etiqueta,
                      icono: e.icono,
                      cantidad: conteo[e]!,
                      activo: _filtro == e,
                      onTap: () => setState(() => _filtro = _filtro == e ? null : e),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _Lista(
                ordenes: filtradas,
                vacio: EstadoVacio(
                  icono: Icons.inventory_2_outlined,
                  titulo: _filtro == null ? 'No hay trabajos en curso' : 'Nada en "${_filtro!.etiqueta}"',
                  mensaje: _filtro == null ? 'Registrá un trabajo cuando un cliente te deje algo para hacer.' : null,
                  accion: _filtro == null
                      ? FilledButton.icon(
                          onPressed: () => nuevoTrabajo(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Nuevo trabajo'),
                        )
                      : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Filtro extends StatelessWidget {
  const _Filtro({required this.texto, required this.cantidad, required this.activo, required this.onTap, this.icono});
  final String texto;
  final int cantidad;
  final bool activo;
  final VoidCallback onTap;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Espacio.s),
      child: FilterChip(
        selected: activo,
        showCheckmark: false,
        avatar: icono == null ? null : Icon(icono, size: 16),
        label: Text('$texto  $cantidad'),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.ordenes, required this.vacio, this.hayMas = false, this.onMas});
  final List<Orden> ordenes;
  final Widget vacio;
  final bool hayMas;
  final VoidCallback? onMas;

  @override
  Widget build(BuildContext context) {
    if (ordenes.isEmpty) return vacio;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Espacio.l, Espacio.s, Espacio.l, 96),
      itemCount: ordenes.length + (hayMas ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: Espacio.s),
      itemBuilder: (context, i) {
        if (i == ordenes.length) {
          return Center(child: TextButton(onPressed: onMas, child: const Text('Cargar más')));
        }
        final o = ordenes[i];
        return TarjetaOrden(orden: o, onTap: () => abrirPagina(context, OrdenDetallePage(ordenId: o.id)));
      },
    );
  }
}
