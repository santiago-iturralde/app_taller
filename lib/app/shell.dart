import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/componentes.dart';
import '../core/widgets/feedback.dart';
import '../data/models/orden.dart';
import '../features/ajustes/ajustes_page.dart';
import '../features/caja/caja_page.dart';
import '../features/clientes/clientes_page.dart';
import '../features/inicio/inicio_page.dart';
import '../features/planes/planes_page.dart';
import '../features/presupuestos/presupuestos_page.dart';
import '../features/reportes/reportes_page.dart';
import '../features/trabajos/trabajos_page.dart';
import 'sesion.dart';

enum _Seccion {
  inicio('Inicio', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  trabajos('Trabajos', Icons.build_outlined, Icons.build_rounded),
  clientes('Clientes', Icons.people_alt_outlined, Icons.people_alt_rounded),
  presupuestos('Presupuestos', Icons.request_quote_outlined, Icons.request_quote_rounded),
  caja('Caja', Icons.point_of_sale_outlined, Icons.point_of_sale_rounded),
  reportes('Reportes', Icons.insights_outlined, Icons.insights_rounded),
  ajustes('Ajustes', Icons.settings_outlined, Icons.settings_rounded);

  const _Seccion(this.titulo, this.icono, this.iconoActivo);
  final String titulo;
  final IconData icono;
  final IconData iconoActivo;

  /// Secciones de la barra inferior en celular (el resto va en "Más").
  static const movil = [inicio, trabajos, clientes, presupuestos];
}

/// Estructura principal: barra lateral en escritorio, barra inferior en
/// celular.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  _Seccion _actual = _Seccion.inicio;
  EstadoOrden? _filtroTrabajos;

  void _irATrabajos(EstadoOrden? filtro) => setState(() {
        _filtroTrabajos = filtro;
        _actual = _Seccion.trabajos;
      });

  Widget _pagina(_Seccion s) => switch (s) {
        _Seccion.inicio => InicioPage(irATrabajos: _irATrabajos),
        _Seccion.trabajos => TrabajosPage(key: ValueKey(_filtroTrabajos), filtroInicial: _filtroTrabajos),
        _Seccion.clientes => const ClientesPage(),
        _Seccion.presupuestos => const PresupuestosPage(),
        _Seccion.caja => const CajaPage(),
        _Seccion.reportes => const ReportesPage(),
        _Seccion.ajustes => const AjustesPage(),
      };

  void _seleccionar(_Seccion s) => setState(() {
        if (s != _Seccion.trabajos) _filtroTrabajos = null;
        _actual = s;
      });

  @override
  Widget build(BuildContext context) {
    final contenido = KeyedSubtree(key: ValueKey(_actual), child: _pagina(_actual));

    if (context.esEscritorio) {
      return Scaffold(
        body: Row(
          children: [
            _BarraLateral(actual: _actual, onSeleccionar: _seleccionar),
            VerticalDivider(width: 1, color: context.colores.borde),
            Expanded(child: contenido),
          ],
        ),
      );
    }

    final indice = _Seccion.movil.indexOf(_actual);
    return Scaffold(
      body: contenido,
      bottomNavigationBar: NavigationBar(
        selectedIndex: indice < 0 ? _Seccion.movil.length : indice,
        onDestinationSelected: (i) {
          if (i == _Seccion.movil.length) {
            _mostrarMas(context);
          } else {
            _seleccionar(_Seccion.movil[i]);
          }
        },
        destinations: [
          for (final s in _Seccion.movil)
            NavigationDestination(icon: Icon(s.icono), selectedIcon: Icon(s.iconoActivo), label: s.titulo),
          const NavigationDestination(icon: Icon(Icons.menu_rounded), label: 'Más'),
        ],
      ),
    );
  }

  void _mostrarMas(BuildContext context) {
    final negocio = Sesion.of(context).negocio;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in [_Seccion.caja, _Seccion.reportes, _Seccion.ajustes])
              ListTile(
                leading: Icon(s.icono),
                title: Text(s.titulo),
                trailing: (s == _Seccion.reportes && !negocio.esPro) ? const DistintivoPro() : null,
                onTap: () {
                  Navigator.pop(sheet);
                  _seleccionar(s);
                },
              ),
            if (!negocio.esPro)
              ListTile(
                leading: Icon(Icons.workspace_premium_rounded, color: context.colores.pro),
                title: const Text('Pasate a PRO'),
                onTap: () {
                  Navigator.pop(sheet);
                  abrirPagina(context, const PlanesPage());
                },
              ),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: context.colores.peligro),
              title: Text('Cerrar sesión', style: TextStyle(color: context.colores.peligro)),
              onTap: () {
                Navigator.pop(sheet);
                cerrarSesion(context);
              },
            ),
            const SizedBox(height: Espacio.s),
          ],
        ),
      ),
    );
  }
}

class _BarraLateral extends StatelessWidget {
  const _BarraLateral({required this.actual, required this.onSeleccionar});
  final _Seccion actual;
  final ValueChanged<_Seccion> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    final sesion = Sesion.of(context);
    final negocio = sesion.negocio;
    return Container(
      width: 248,
      color: context.esquema.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Espacio.l, Espacio.xl, Espacio.l, Espacio.l),
              child: Row(children: [
                IconoTile(negocio.rubro.icono, tamanio: 40),
                const SizedBox(width: Espacio.m),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(negocio.nombre, style: context.textos.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      negocio.esPro ? 'Plan PRO' : 'Plan Gratis',
                      style: context.textos.bodySmall?.copyWith(color: context.esquema.onSurfaceVariant),
                    ),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Espacio.m),
              child: FilledButton.icon(
                onPressed: () => nuevoTrabajo(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo trabajo'),
              ),
            ),
            const SizedBox(height: Espacio.l),
            for (final s in _Seccion.values.where((s) => s != _Seccion.ajustes))
              _Item(
                seccion: s,
                activo: s == actual,
                onTap: () => onSeleccionar(s),
                extra: (s == _Seccion.reportes && !negocio.esPro) ? const DistintivoPro() : null,
              ),
            const Spacer(),
            if (!negocio.esPro)
              Padding(
                padding: const EdgeInsets.all(Espacio.m),
                child: AppCard(
                  color: context.colores.proSuave,
                  onTap: () => abrirPagina(context, const PlanesPage()),
                  child: Row(children: [
                    Icon(Icons.workspace_premium_rounded, color: context.colores.pro),
                    const SizedBox(width: Espacio.s),
                    const Expanded(child: Text('Pasate a PRO', style: TextStyle(fontWeight: FontWeight.w700))),
                    const Icon(Icons.chevron_right_rounded, size: 18),
                  ]),
                ),
              ),
            _Item(seccion: _Seccion.ajustes, activo: actual == _Seccion.ajustes, onTap: () => onSeleccionar(_Seccion.ajustes)),
            Padding(
              padding: const EdgeInsets.fromLTRB(Espacio.m, 0, Espacio.m, Espacio.m),
              child: ListTile(
                dense: true,
                leading: Iniciales((sesion.usuario.email ?? '?').substring(0, 1).toUpperCase(), radio: 14),
                title: Text(sesion.usuario.email ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  tooltip: 'Cerrar sesión',
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  onPressed: () => cerrarSesion(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.seccion, required this.activo, required this.onTap, this.extra});
  final _Seccion seccion;
  final bool activo;
  final VoidCallback onTap;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final color = activo ? context.esquema.primary : context.esquema.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Espacio.m, vertical: 2),
      child: Material(
        color: activo ? context.esquema.primary.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(Radios.m),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radios.m),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Espacio.m, vertical: 11),
            child: Row(children: [
              Icon(activo ? seccion.iconoActivo : seccion.icono, color: color, size: 22),
              const SizedBox(width: Espacio.m),
              Expanded(
                child: Text(
                  seccion.titulo,
                  style: context.textos.bodyMedium?.copyWith(
                    color: activo ? context.esquema.primary : context.esquema.onSurface,
                    fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (extra != null) extra!,
            ]),
          ),
        ),
      ),
    );
  }
}
