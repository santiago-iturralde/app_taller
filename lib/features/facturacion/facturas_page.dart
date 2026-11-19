import 'package:flutter/material.dart';

import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/campos.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/fiscal.dart';
import '../../data/models/negocio.dart';
import '../planes/pro.dart';
import 'config_arca_page.dart';
import 'factura_detalle_page.dart';

/// Facturas electrónicas emitidas en el mes.
class FacturasPage extends StatefulWidget {
  const FacturasPage({super.key});

  @override
  State<FacturasPage> createState() => _FacturasPageState();
}

class _FacturasPageState extends State<FacturasPage> {
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final sesion = Sesion.of(context);
    if (!sesion.negocio.permite(FuncionPro.facturacion)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Facturas')),
        body: EstadoVacio(
          icono: Icons.receipt_long_outlined,
          titulo: 'Facturación electrónica ARCA',
          mensaje: 'Emití facturas A, B y C desde cada trabajo o venta, con CAE y código QR.',
          accion: FilledButton(onPressed: () => exigirPro(context, FuncionPro.facturacion), child: const Text('Ver planes')),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Facturas'),
        actions: [
          if (sesion.puede(Permiso.editarNegocio))
            IconButton(
              tooltip: 'Configuración de ARCA',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => abrirPagina(context, const ConfigArcaPage()),
            ),
        ],
      ),
      body: ContenidoCentrado(
        anchoMaximo: 860,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(Espacio.l),
            child: Center(child: SelectorMes(mes: _mes, onCambio: (m) => setState(() => _mes = m))),
          ),
          Expanded(
            child: StreamBuilder<List<Factura>>(
              stream: sesion.facturacion.delMes(_mes),
              builder: (context, s) {
                if (s.hasError) return EstadoError(error: s.error);
                if (!s.hasData) return const Cargando();
                final lista = s.data!;
                final autorizadas = lista.where((f) => f.estado == EstadoFactura.autorizada);
                final neto = autorizadas.fold(0.0, (t, f) => t + (f.esNotaCredito ? -f.total : f.total));
                if (lista.isEmpty) {
                  return const EstadoVacio(
                    icono: Icons.receipt_long_outlined,
                    titulo: 'Sin facturas este mes',
                    mensaje: 'Facturá desde el detalle de un trabajo o desde una venta en Caja.',
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(Espacio.l, 0, Espacio.l, Espacio.xxl),
                  children: [
                    if (sesion.puede(Permiso.verTotalesCaja)) ...[
                      Indicador(
                        etiqueta: 'Facturado en ${Formato.mes(_mes).toLowerCase()}',
                        valor: Formato.moneda(neto),
                        icono: Icons.receipt_long_outlined,
                        detalle: '${autorizadas.length} comprobantes autorizados (las notas de crédito restan)',
                      ),
                      const SizedBox(height: Espacio.m),
                    ],
                    AppCard(
                      padding: const EdgeInsets.symmetric(vertical: Espacio.s),
                      child: Column(children: [
                        for (final f in lista)
                          ListTile(
                            onTap: () => abrirPagina(context, FacturaDetallePage(facturaId: f.id)),
                            leading: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: context.esquema.onSurfaceVariant),
                                borderRadius: BorderRadius.circular(Radios.s),
                              ),
                              child: Text(f.letra, style: const TextStyle(fontWeight: FontWeight.w900)),
                            ),
                            title: Text('${f.esNotaCredito ? 'NC' : 'FC'} ${f.numeroCompleto} · ${f.receptorNombre}', maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Align(alignment: Alignment.centerLeft, child: EtiquetaFactura(f, compacta: true)),
                            ),
                            trailing: Text(
                              '${f.esNotaCredito ? '−' : ''}${Formato.moneda(f.total)}',
                              style: context.textos.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                      ]),
                    ),
                  ],
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
