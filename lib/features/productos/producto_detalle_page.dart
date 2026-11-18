import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/producto.dart';
import 'producto_form.dart';
import 'widgets_producto.dart';
import '../../data/models/negocio.dart';

class ProductoDetallePage extends StatelessWidget {
  const ProductoDetallePage({super.key, required this.productoId});
  final String productoId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Producto?>(
      stream: Sesion.of(context).productos.observar(productoId),
      builder: (context, s) {
        if (s.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: EstadoError(error: s.error),
          );
        }
        if (s.connectionState == ConnectionState.waiting) return Scaffold(appBar: AppBar(), body: const Cargando());
        final p = s.data;
        if (p == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EstadoVacio(icono: Icons.search_off_rounded, titulo: 'El producto ya no existe'),
          );
        }
        return _Detalle(p: p);
      },
    );
  }
}

class _Detalle extends StatelessWidget {
  const _Detalle({required this.p});
  final Producto p;

  Future<void> _eliminar(BuildContext context) async {
    final ok = await confirmar(
      context,
      titulo: 'Eliminar ${p.tipo.etiqueta.toLowerCase()}',
      mensaje: '¿Eliminar "${p.nombre}" del catálogo? Los trabajos y ventas donde se usó no se modifican.',
      confirmar: 'Eliminar',
      peligroso: true,
    );
    if (!ok || !context.mounted) return;
    final hecho = await ejecutar(
      context,
      () => Sesion.of(context).productos.eliminar(p.id),
      exito: 'Eliminado del catálogo',
    );
    if (hecho && context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final margen = p.margen;
    return Scaffold(
      appBar: AppBar(
        title: Text(p.tipo.etiqueta),
        actions: [
          if (Sesion.of(context).puede(Permiso.editarCatalogo))
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => abrirFormulario(context, ProductoForm(producto: p)),
            ),
          if (Sesion.of(context).puede(Permiso.eliminarRegistros))
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'eliminar') _eliminar(context);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'eliminar',
                  child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Eliminar')),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Espacio.l),
        children: [
          ContenidoCentrado(
            anchoMaximo: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  padding: const EdgeInsets.all(Espacio.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconoTile(p.tipo.icono, tamanio: 48),
                          const SizedBox(width: Espacio.l),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.nombre, style: context.textos.titleLarge),
                                if (p.codigo.isNotEmpty || p.categoria.isNotEmpty)
                                  Text(
                                    [p.codigo, p.categoria].where((e) => e.isNotEmpty).join(' · '),
                                    style: TextStyle(color: context.esquema.onSurfaceVariant),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Espacio.l),
                      Wrap(
                        spacing: Espacio.xxl,
                        runSpacing: Espacio.m,
                        children: [
                          _Dato('Precio de venta', Formato.moneda(p.precio)),
                          if (p.costo > 0) _Dato('Costo', Formato.moneda(p.costo)),
                          if (margen != null) _Dato('Margen', '${margen.toStringAsFixed(0)}%'),
                        ],
                      ),
                    ],
                  ),
                ),
                if (p.controlaStock) ...[
                  const SizedBox(height: Espacio.m),
                  _Stock(p: p),
                  const Seccion('Movimientos de stock'),
                  _Movimientos(productoId: p.id),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(etiqueta, style: context.textos.labelSmall?.copyWith(color: context.esquema.onSurfaceVariant)),
      Text(valor, style: context.textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
    ],
  );
}

class _Stock extends StatelessWidget {
  const _Stock({required this.p});
  final Producto p;

  Future<void> _mover(BuildContext context, {required bool ajuste}) async {
    final ctrl = TextEditingController(text: ajuste ? Formato.cantidad(p.stock) : '');
    final nota = TextEditingController();
    final valor = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ajuste ? 'Ajustar stock' : 'Ingresar mercadería'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ajuste
                  ? 'Indicá cuántas unidades hay realmente (por ejemplo, después de contar).'
                  : '¿Cuántas unidades entraron?',
            ),
            const SizedBox(height: Espacio.l),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
              decoration: InputDecoration(labelText: ajuste ? 'Stock real' : 'Cantidad'),
            ),
            const SizedBox(height: Espacio.m),
            TextField(
              controller: nota,
              decoration: InputDecoration(
                labelText: 'Nota (opcional)',
                hintText: ajuste ? 'Ej: Recuento mensual' : 'Ej: Factura proveedor 1234',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, Formato.parseMonto(ctrl.text)),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (valor == null || !context.mounted) return;
    final cantidad = ajuste ? valor - p.stock : valor;
    if (cantidad == 0) return;
    await ejecutar(
      context,
      () => Sesion.of(context).productos.moverStock(
        p.id,
        cantidad,
        ajuste ? MotivoStock.ajuste : MotivoStock.ingreso,
        referencia: nota.text.trim(),
      ),
      exito: 'Stock actualizado',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(Espacio.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stock disponible', style: TextStyle(color: context.esquema.onSurfaceVariant)),
                    Text(
                      Formato.cantidad(p.stock),
                      style: context.textos.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (p.stockMinimo > 0)
                      Text('Aviso con ${Formato.cantidad(p.stockMinimo)} o menos', style: context.textos.bodySmall),
                  ],
                ),
              ),
              EtiquetaStock(p, compacta: false),
            ],
          ),
          if (Sesion.of(context).puede(Permiso.ajustarStock)) ...[
            const SizedBox(height: Espacio.l),
            Wrap(
              spacing: Espacio.s,
              runSpacing: Espacio.s,
              children: [
                FilledButton.icon(
                  onPressed: () => _mover(context, ajuste: false),
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Ingresar mercadería'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _mover(context, ajuste: true),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Ajustar stock'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Movimientos extends StatelessWidget {
  const _Movimientos({required this.productoId});
  final String productoId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MovimientoStock>>(
      stream: Sesion.of(context).productos.movimientos(productoId),
      builder: (context, s) {
        if (s.hasError) return EstadoError(error: s.error);
        if (!s.hasData) return const Cargando();
        if (s.data!.isEmpty) {
          return AppCard(
            child: Text('Todavía no hay movimientos.', style: TextStyle(color: context.esquema.onSurfaceVariant)),
          );
        }
        return AppCard(
          padding: const EdgeInsets.symmetric(vertical: Espacio.s),
          child: Column(
            children: [
              for (final m in s.data!)
                ListTile(
                  leading: IconoTile(
                    m.motivo.icono,
                    tamanio: 36,
                    color: m.cantidad > 0 ? context.colores.exito : context.colores.peligro,
                    fondo: m.cantidad > 0 ? context.colores.exitoSuave : context.colores.peligroSuave,
                  ),
                  title: Text(
                    m.referencia.isEmpty ? m.motivo.etiqueta : '${m.motivo.etiqueta} · ${m.referencia}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      Formato.fechaHora(m.fecha),
                      'quedaron ${Formato.cantidad(m.stockResultante)}',
                      if (m.usuarioEmail.isNotEmpty) m.usuarioEmail,
                    ].join(' · '),
                    maxLines: 2,
                  ),
                  trailing: Text(
                    '${m.cantidad > 0 ? '+' : ''}${Formato.cantidad(m.cantidad)}',
                    style: context.textos.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
