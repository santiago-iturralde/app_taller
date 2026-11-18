import 'package:flutter/material.dart';

import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/campos.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/comunes.dart';
import '../../data/models/producto.dart';
import 'producto_detalle_page.dart';
import 'producto_form.dart';
import 'widgets_producto.dart';
import '../../data/models/negocio.dart';

enum _Filtro { todos, stockBajo, servicios }

class ProductosPage extends StatefulWidget {
  const ProductosPage({super.key});

  @override
  State<ProductosPage> createState() => _ProductosPageState();
}

class _ProductosPageState extends State<ProductosPage> {
  _Filtro _filtro = _Filtro.todos;
  String _consulta = '';
  Future<List<Producto>>? _busqueda;
  int _limite = 100;

  void _buscar(String q) => setState(() {
    _consulta = q;
    _busqueda = q.isEmpty ? null : Sesion.of(context).productos.buscar(q, limite: 40);
  });

  @override
  Widget build(BuildContext context) {
    final repo = Sesion.of(context).productos;
    return Scaffold(
      appBar: AppBar(title: const Text('Productos y servicios')),
      floatingActionButton: !Sesion.of(context).puede(Permiso.editarCatalogo)
          ? null
          : FloatingActionButton.extended(
              heroTag: 'fab-productos',
              onPressed: () async {
                final p = await abrirFormulario<Producto>(context, const ProductoForm());
                if (p != null && context.mounted) abrirPagina(context, ProductoDetallePage(productoId: p.id));
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuevo'),
            ),
      body: ContenidoCentrado(
        anchoMaximo: 860,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Espacio.l, Espacio.l, Espacio.l, Espacio.s),
              child: Buscador(onBuscar: _buscar, hint: 'Buscar por nombre, código o categoría'),
            ),
            if (_busqueda == null)
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Espacio.l, vertical: Espacio.xs),
                  children: [
                    for (final (f, texto, icono) in [
                      (_Filtro.todos, 'Todos', null),
                      (_Filtro.stockBajo, 'Stock bajo', Icons.warning_amber_rounded),
                      (_Filtro.servicios, 'Servicios', Icons.handyman_outlined),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: Espacio.s),
                        child: FilterChip(
                          label: Text(texto),
                          avatar: icono == null ? null : Icon(icono, size: 16),
                          selected: _filtro == f,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _filtro = f),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: _busqueda != null
                  ? FutureBuilder<List<Producto>>(
                      future: _busqueda,
                      builder: (context, s) {
                        if (s.hasError) return const EstadoError();
                        if (!s.hasData) return const Cargando();
                        return _lista(
                          s.data!,
                          EstadoVacio(icono: Icons.search_off_rounded, titulo: 'Sin resultados para "$_consulta"'),
                        );
                      },
                    )
                  : StreamBuilder<List<Producto>>(
                      stream: _filtro == _Filtro.stockBajo ? repo.conStockBajo() : repo.listar(limite: _limite),
                      builder: (context, s) {
                        if (s.hasError) return EstadoError(error: s.error);
                        if (!s.hasData) return const Cargando();
                        var lista = s.data!;
                        if (_filtro == _Filtro.servicios) lista = lista.where((p) => !p.controlaStock).toList();
                        if (_filtro == _Filtro.stockBajo) lista.sort((a, b) => a.stock.compareTo(b.stock));
                        return _lista(
                          lista,
                          EstadoVacio(
                            icono: _filtro == _Filtro.stockBajo ? Icons.verified_outlined : Icons.inventory_2_outlined,
                            titulo: switch (_filtro) {
                              _Filtro.stockBajo => 'Todo el stock está en orden',
                              _Filtro.servicios => 'Sin servicios cargados',
                              _Filtro.todos => 'Armá tu catálogo',
                            },
                            mensaje: _filtro == _Filtro.todos
                                ? 'Cargá productos (con stock) y servicios con su precio. Después los agregás '
                                      'a trabajos, presupuestos y ventas con un toque, y el stock se descuenta solo.'
                                : null,
                          ),
                          hayMas: _filtro == _Filtro.todos && s.data!.length >= _limite,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lista(List<Producto> lista, Widget vacio, {bool hayMas = false}) {
    if (lista.isEmpty) return vacio;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Espacio.l, Espacio.s, Espacio.l, 96),
      itemCount: lista.length + (hayMas ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: Espacio.s),
      itemBuilder: (context, i) {
        if (i == lista.length) {
          return Center(
            child: TextButton(onPressed: () => setState(() => _limite += 100), child: const Text('Ver más')),
          );
        }
        final p = lista[i];
        return FilaProducto(
          producto: p,
          onTap: () => abrirPagina(context, ProductoDetallePage(productoId: p.id)),
        );
      },
    );
  }
}

/// Buscador del catálogo para agregar un ítem a un trabajo, presupuesto o
/// venta. Permite crear el producto en el momento si no existe.
Future<ItemLinea?> elegirDelCatalogo(BuildContext context) async {
  final contenido = _SelectorProducto(sesion: Sesion.of(context));
  final Producto? p;
  if (context.esEscritorio) {
    p = await showDialog<Producto>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640), child: contenido),
      ),
    );
  } else {
    p = await showModalBottomSheet<Producto>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(heightFactor: 0.9, child: contenido),
    );
  }
  return p?.comoItem();
}

class _SelectorProducto extends StatefulWidget {
  const _SelectorProducto({required this.sesion});
  final Sesion sesion;

  @override
  State<_SelectorProducto> createState() => _SelectorProductoState();
}

class _SelectorProductoState extends State<_SelectorProducto> {
  String _consulta = '';
  Future<List<Producto>>? _resultados;

  void _buscar(String q) => setState(() {
    _consulta = q;
    _resultados = q.isEmpty ? null : widget.sesion.productos.buscar(q);
  });

  Future<void> _crear() async {
    final nuevo = await abrirFormulario<Producto>(context, ProductoForm(nombreInicial: _consulta));
    if (nuevo != null && mounted) Navigator.pop(context, nuevo);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Espacio.l, Espacio.l, Espacio.l, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Agregar del catálogo', style: context.textos.titleMedium),
          const SizedBox(height: Espacio.m),
          Buscador(onBuscar: _buscar, hint: 'Nombre o código', autofocus: true),
          const SizedBox(height: Espacio.s),
          if (widget.sesion.puede(Permiso.editarCatalogo))
            ListTile(
              leading: IconoTile(Icons.add_rounded, tamanio: 36, color: context.esquema.primary),
              title: Text(_consulta.isEmpty ? 'Nuevo producto o servicio' : 'Crear "$_consulta"'),
              onTap: _crear,
            ),
          const Divider(),
          Expanded(
            child: _resultados == null
                ? StreamBuilder<List<Producto>>(
                    stream: widget.sesion.productos.listar(limite: 40),
                    builder: (context, s) => _lista(s.data, s.hasError),
                  )
                : FutureBuilder<List<Producto>>(
                    future: _resultados,
                    builder: (context, s) =>
                        s.connectionState == ConnectionState.waiting ? const Cargando() : _lista(s.data, s.hasError),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _lista(List<Producto>? productos, bool error) {
    if (error) return const EstadoError();
    if (productos == null) return const Cargando();
    if (productos.isEmpty) {
      return EstadoVacio(
        icono: Icons.inventory_2_outlined,
        titulo: _consulta.isEmpty ? 'El catálogo está vacío' : 'Sin resultados',
        mensaje: 'Podés crearlo con el botón de arriba.',
      );
    }
    return ListView.builder(
      itemCount: productos.length,
      itemBuilder: (context, i) {
        final p = productos[i];
        return ListTile(
          leading: Icon(p.tipo.icono),
          title: Text(p.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Align(alignment: Alignment.centerLeft, child: EtiquetaStock(p)),
          trailing: Text(Formato.moneda(p.precio), style: const TextStyle(fontWeight: FontWeight.w700)),
          onTap: () => Navigator.pop(context, p),
        );
      },
    );
  }
}
