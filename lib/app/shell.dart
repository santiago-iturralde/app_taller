import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'app_info.dart';
import '../core/widgets/componentes.dart';
import '../core/widgets/feedback.dart';
import '../data/models/orden.dart';
import '../features/ajustes/ajustes_page.dart';
import '../features/caja/caja_page.dart';
import '../features/clientes/clientes_page.dart';
import '../features/inicio/inicio_page.dart';
import '../features/planes/planes_page.dart';
import '../features/presupuestos/presupuestos_page.dart';
import '../features/productos/productos_page.dart';
import '../features/reportes/reportes_page.dart';
import '../features/trabajos/trabajos_page.dart';
import 'preferencias.dart';
import 'sesion.dart';
import '../data/models/negocio.dart';
import '../features/planes/pro.dart';
import '../features/facturacion/facturas_page.dart';
import '../features/admin/admin_page.dart';

enum _Seccion {
  inicio('Inicio', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  trabajos('Trabajos', Icons.build_outlined, Icons.build_rounded),
  clientes('Clientes', Icons.people_alt_outlined, Icons.people_alt_rounded),
  presupuestos('Presupuestos', Icons.request_quote_outlined, Icons.request_quote_rounded),
  productos('Productos', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
  caja('Caja', Icons.point_of_sale_outlined, Icons.point_of_sale_rounded),
  facturas('Facturas', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
  reportes('Reportes', Icons.insights_outlined, Icons.insights_rounded),
  ajustes('Ajustes', Icons.settings_outlined, Icons.settings_rounded);

  const _Seccion(this.titulo, this.icono, this.iconoActivo);
  final String titulo;
  final IconData icono;
  final IconData iconoActivo;

  /// Secciones de la barra inferior en celular (el resto va en "Más").
  static const movil = [inicio, trabajos, clientes, caja];
  static const masMovil = [presupuestos, productos, facturas, reportes, ajustes];

  /// Si la sección está habilitada en esta versión.
  bool get disponible => this != facturas || AppInfo.facturacionDisponible;
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
    _Seccion.productos => const ProductosPage(),
    _Seccion.caja => const CajaPage(),
    _Seccion.facturas => const FacturasPage(),
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
            Expanded(child: Column(children: [const AvisoPlan(), Expanded(child: contenido)])),
          ],
        ),
      );
    }

    final indice = _Seccion.movil.indexOf(_actual);
    return Scaffold(
      body: Column(children: [const AvisoPlan(), Expanded(child: contenido)]),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.colores.borde)),
        ),
        child: NavigationBar(
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
            for (final s in _Seccion.masMovil.where(
              (s) => s.disponible && s != _Seccion.reportes || Sesion.of(context).puede(Permiso.verReportes),
            ))
              ListTile(
                leading: Icon(s.icono),
                title: Text(s.titulo),
                selected: s == _actual,
                trailing: (s == _Seccion.reportes && !negocio.permite(FuncionPro.reportes)) ? const DistintivoPro() : null,
                onTap: () {
                  Navigator.pop(sheet);
                  _seleccionar(s);
                },
              ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Espacio.l, vertical: Espacio.s),
              child: SelectorTema(),
            ),
            if (Sesion.of(context).esSuperadmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Administración de la plataforma'),
                onTap: () {
                  Navigator.pop(sheet);
                  abrirPagina(context, const AdminPage());
                },
              ),
            if (!negocio.esPro)
              ListTile(
                leading: Icon(Icons.workspace_premium_rounded, color: context.colores.pro),
                title: const Text('Mejorá tu plan'),
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
    final c = context.colores;
    final prefs = PreferenciasScope.of(context);
    final oscuro = context.esOscuro;

    return Container(
      width: 252,
      decoration: BoxDecoration(
        color: c.lateralFondo,
        border: Border(right: BorderSide(color: c.lateralBorde)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Espacio.l, Espacio.xl, Espacio.l, Espacio.l),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Paleta.azul500, Paleta.azul700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(Radios.m),
                    ),
                    child: Icon(negocio.rubro.icono, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: Espacio.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          negocio.nombre,
                          style: context.textos.titleSmall?.copyWith(color: c.lateralTexto),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          etiquetaPlan(negocio),
                          style: context.textos.bodySmall?.copyWith(color: c.lateralTextoSuave),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Espacio.m),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Paleta.azul500, foregroundColor: Colors.white),
                onPressed: () => nuevoTrabajo(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo trabajo'),
              ),
            ),
            const SizedBox(height: Espacio.l),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final s in _Seccion.values.where(
                    (s) => s.disponible && s != _Seccion.ajustes && (s != _Seccion.reportes || sesion.puede(Permiso.verReportes)),
                  ))
                    _Item(
                      seccion: s,
                      activo: s == actual,
                      onTap: () => onSeleccionar(s),
                      extra: (s == _Seccion.reportes && !negocio.permite(FuncionPro.reportes)) ? const DistintivoPro() : null,
                    ),
                ],
              ),
            ),
            if (!negocio.esPro)
              Padding(
                padding: const EdgeInsets.all(Espacio.m),
                child: Material(
                  color: const Color(0x1FFBBF24),
                  borderRadius: BorderRadius.circular(Radios.m),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Radios.m),
                    onTap: () => abrirPagina(context, const PlanesPage()),
                    child: Padding(
                      padding: const EdgeInsets.all(Espacio.m),
                      child: Row(
                        children: [
                          const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFBBF24)),
                          const SizedBox(width: Espacio.s),
                          Expanded(
                            child: Text(
                              'Mejorá tu plan',
                              style: TextStyle(fontWeight: FontWeight.w700, color: c.lateralTexto),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, size: 18, color: c.lateralTextoSuave),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (sesion.esSuperadmin)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Espacio.m, vertical: 2),
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.admin_panel_settings_outlined, color: c.lateralTextoSuave),
                  title: Text('Administración', style: TextStyle(color: c.lateralTexto)),
                  onTap: () => abrirPagina(context, const AdminPage()),
                ),
              ),
            _Item(
              seccion: _Seccion.ajustes,
              activo: actual == _Seccion.ajustes,
              onTap: () => onSeleccionar(_Seccion.ajustes),
            ),
            Divider(color: c.lateralBorde, height: Espacio.l),
            Padding(
              padding: const EdgeInsets.fromLTRB(Espacio.l, 0, Espacio.s, Espacio.m),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Paleta.azul500.withValues(alpha: 0.25),
                    child: Text(
                      (sesion.usuario.email ?? '?').substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Paleta.azul300, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: Espacio.s),
                  Expanded(
                    child: Text(
                      sesion.usuario.email ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textos.bodySmall?.copyWith(color: c.lateralTextoSuave),
                    ),
                  ),
                  IconButton(
                    tooltip: oscuro ? 'Modo claro' : 'Modo oscuro',
                    color: c.lateralTextoSuave,
                    icon: Icon(oscuro ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 20),
                    onPressed: () => prefs.cambiarTema(oscuro ? ThemeMode.light : ThemeMode.dark),
                  ),
                  IconButton(
                    tooltip: 'Cerrar sesión',
                    color: c.lateralTextoSuave,
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    onPressed: () => cerrarSesion(context),
                  ),
                ],
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
    final c = context.colores;
    final color = activo ? Paleta.azul300 : c.lateralTextoSuave;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Espacio.m, vertical: 2),
      child: Material(
        color: activo ? c.lateralActivo : Colors.transparent,
        borderRadius: BorderRadius.circular(Radios.m),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radios.m),
          hoverColor: Colors.white.withValues(alpha: 0.05),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Espacio.m, vertical: 11),
            child: Row(
              children: [
                Icon(activo ? seccion.iconoActivo : seccion.icono, color: color, size: 22),
                const SizedBox(width: Espacio.m),
                Expanded(
                  child: Text(
                    seccion.titulo,
                    style: context.textos.bodyMedium?.copyWith(
                      color: activo ? Colors.white : c.lateralTexto,
                      fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (extra != null) extra!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
