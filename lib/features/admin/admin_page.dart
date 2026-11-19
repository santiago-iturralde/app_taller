import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/busqueda.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/campos.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/negocio.dart';
import '../../data/repositories/admin_repository.dart';
import 'admin_negocio_page.dart';
import 'widgets_admin.dart';

enum _Filtro { todos, porVencer, vencidos, prueba, pagos, gratis }

/// Panel del administrador de la plataforma: todos los negocios y sus planes.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _repo = AdminRepository();
  _Filtro _filtro = _Filtro.todos;
  String _consulta = '';
  int _limite = 200;

  bool _pasaFiltro(Negocio n) {
    final dias = n.diasRestantes();
    final ok = switch (_filtro) {
      _Filtro.todos => true,
      _Filtro.porVencer => !n.vencido && dias != null && dias <= 7,
      _Filtro.vencidos => n.vencido,
      _Filtro.prueba => n.prueba && !n.vencido,
      _Filtro.pagos => !n.prueba && !n.vencido && n.plan != Plan.gratis,
      _Filtro.gratis => n.planEfectivo == Plan.gratis,
    };
    return ok && (_consulta.isEmpty || Busqueda.coincide(Busqueda.keywords([n.nombre, n.email, n.id]), _consulta));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administración de la plataforma')),
      body: StreamBuilder<List<(Negocio, DateTime?)>>(
        stream: _repo.negocios(limite: _limite),
        builder: (context, s) {
          if (s.hasError) return EstadoError(error: s.error);
          if (!s.hasData) return const Cargando();
          final todos = s.data!;
          final lista = todos.where((e) => _pasaFiltro(e.$1)).toList();
          return ListView(
            padding: const EdgeInsets.all(Espacio.l),
            children: [
              ContenidoCentrado(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _Resumen(negocios: todos.map((e) => e.$1).toList()),
                  const SizedBox(height: Espacio.l),
                  Buscador(onBuscar: (q) => setState(() => _consulta = q), hint: 'Buscar negocio por nombre, email o código'),
                  const SizedBox(height: Espacio.s),
                  Wrap(spacing: Espacio.s, runSpacing: Espacio.s, children: [
                    for (final (f, t) in [
                      (_Filtro.todos, 'Todos'),
                      (_Filtro.porVencer, 'Vencen en 7 días'),
                      (_Filtro.vencidos, 'Vencidos'),
                      (_Filtro.prueba, 'En prueba'),
                      (_Filtro.pagos, 'Pagos'),
                      (_Filtro.gratis, 'Gratis'),
                    ])
                      FilterChip(label: Text(t), selected: _filtro == f, showCheckmark: false, onSelected: (_) => setState(() => _filtro = f)),
                  ]),
                  const SizedBox(height: Espacio.m),
                  if (lista.isEmpty)
                    const SizedBox(height: 200, child: EstadoVacio(icono: Icons.search_off_rounded, titulo: 'No hay negocios con ese filtro'))
                  else
                    for (final (n, creado) in lista) ...[
                      AppCard(
                        onTap: () => abrirPagina(context, AdminNegocioPage(negocioId: n.id)),
                        child: Row(children: [
                          IconoTile(n.rubro.icono, tamanio: 42),
                          const SizedBox(width: Espacio.m),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(n.nombre.isEmpty ? '(sin nombre)' : n.nombre, style: context.textos.titleSmall),
                              Text(
                                [n.rubro.nombre, if (creado != null) 'alta ${Formato.fecha(creado)}'].join(' · '),
                                style: context.textos.bodySmall?.copyWith(color: context.esquema.onSurfaceVariant),
                              ),
                            ]),
                          ),
                          EtiquetaPlanAdmin(negocio: n),
                        ]),
                      ),
                      const SizedBox(height: Espacio.s),
                    ],
                  if (todos.length >= _limite)
                    Center(child: TextButton(onPressed: () => setState(() => _limite += 200), child: const Text('Cargar más negocios'))),
                  const Seccion('Últimos movimientos'),
                  HistorialPlanes(stream: _repo.historial(limite: 20), mostrarNegocio: true),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.negocios});
  final List<Negocio> negocios;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    int contar(bool Function(Negocio) f) => negocios.where(f).length;
    final pagos = contar((n) => !n.prueba && !n.vencido && n.plan != Plan.gratis);
    final prueba = contar((n) => n.prueba && !n.vencido);
    final porVencer = contar((n) => !n.vencido && (n.diasRestantes() ?? 999) <= 7);
    final vencidos = contar((n) => n.vencido);
    return GrillaAdaptable(anchoMinimo: 200, children: [
      Indicador(etiqueta: 'Negocios', valor: '${negocios.length}', icono: Icons.storefront_outlined),
      Indicador(etiqueta: 'Con plan pago', valor: '$pagos', icono: Icons.verified_outlined, color: c.exito),
      Indicador(etiqueta: 'En prueba', valor: '$prueba', icono: Icons.rocket_launch_outlined, color: c.info),
      Indicador(
        etiqueta: 'Vencen en 7 días',
        valor: '$porVencer',
        icono: Icons.event_outlined,
        color: c.alerta,
        detalle: vencidos > 0 ? '$vencidos ya vencidos' : null,
      ),
    ]);
  }
}
