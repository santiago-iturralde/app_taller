import 'package:flutter/material.dart';

import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/campos.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/cliente.dart';
import 'cliente_detalle_page.dart';
import 'cliente_form.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  String _consulta = '';
  Future<List<Cliente>>? _busqueda;
  int _limite = 60;

  void _buscar(String q) => setState(() {
        _consulta = q;
        _busqueda = q.isEmpty ? null : Sesion.of(context).clientes.buscar(q, limite: 40);
      });

  @override
  Widget build(BuildContext context) {
    final sesion = Sesion.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-clientes',
        onPressed: () async {
          final c = await abrirFormulario<Cliente>(context, const ClienteForm());
          if (c != null && context.mounted) abrirPagina(context, ClienteDetallePage(clienteId: c.id));
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Nuevo cliente'),
      ),
      body: ContenidoCentrado(
        anchoMaximo: 860,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Espacio.l, Espacio.l, Espacio.l, Espacio.s),
              child: Buscador(onBuscar: _buscar, hint: 'Buscar por nombre, teléfono o DNI'),
            ),
            Expanded(
              child: _busqueda != null
                  ? FutureBuilder<List<Cliente>>(
                      future: _busqueda,
                      builder: (context, s) {
                        if (s.hasError) return const EstadoError();
                        if (!s.hasData) return const Cargando();
                        return _Lista(clientes: s.data!, vacio: EstadoVacio(
                          icono: Icons.search_off_rounded,
                          titulo: 'Sin resultados para "$_consulta"',
                          mensaje: 'Probá con otra parte del nombre o el teléfono.',
                        ));
                      },
                    )
                  : StreamBuilder<List<Cliente>>(
                      stream: sesion.clientes.listar(limite: _limite),
                      builder: (context, s) {
                        if (s.hasError) return EstadoError(error: s.error);
                        if (!s.hasData) return const Cargando();
                        final lista = s.data!;
                        return _Lista(
                          clientes: lista,
                          hayMas: lista.length >= _limite,
                          onMas: () => setState(() => _limite += 60),
                          vacio: const EstadoVacio(
                            icono: Icons.people_alt_outlined,
                            titulo: 'Tu cartera de clientes',
                            mensaje: 'Registrá a tus clientes para tener su historial de trabajos, '
                                'presupuestos y cobros en un solo lugar.',
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.clientes, required this.vacio, this.hayMas = false, this.onMas});
  final List<Cliente> clientes;
  final Widget vacio;
  final bool hayMas;
  final VoidCallback? onMas;

  @override
  Widget build(BuildContext context) {
    if (clientes.isEmpty) return vacio;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Espacio.l, Espacio.s, Espacio.l, 96),
      itemCount: clientes.length + (hayMas ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: Espacio.s),
      itemBuilder: (context, i) {
        if (i == clientes.length) {
          return Center(child: TextButton(onPressed: onMas, child: const Text('Ver más clientes')));
        }
        final c = clientes[i];
        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: Espacio.l, vertical: Espacio.m),
          onTap: () => abrirPagina(context, ClienteDetallePage(clienteId: c.id)),
          child: Row(
            children: [
              Iniciales(c.iniciales),
              const SizedBox(width: Espacio.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.nombre, style: context.textos.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (c.telefono.isNotEmpty || c.documento.isNotEmpty)
                      Text(
                        [c.telefono, c.documento].where((e) => e.isNotEmpty).join(' · '),
                        style: context.textos.bodySmall?.copyWith(color: context.esquema.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.esquema.onSurfaceVariant),
            ],
          ),
        );
      },
    );
  }
}
