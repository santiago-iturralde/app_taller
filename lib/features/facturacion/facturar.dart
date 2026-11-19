import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/cliente.dart';
import '../../data/models/fiscal.dart';
import '../../data/models/negocio.dart';
import '../planes/pro.dart';
import 'config_arca_page.dart';
import 'factura_detalle_page.dart';

/// Factura un trabajo (`origenTipo: 'orden'`) o un cobro (`'pago'`).
/// Los importes los toma el servidor del registro guardado.
Future<void> facturar(
  BuildContext context, {
  required String origenTipo,
  required String origenId,
  required double total,
  required String nombreCliente,
  String? clienteId,
}) async {
  final sesion = Sesion.of(context);
  if (!await exigirPro(context, FuncionPro.facturacion) || !context.mounted) return;

  final config = await sesion.facturacion.config().first;
  final estado = (await sesion.facturacion.estado().first)[config.ambiente];
  if (!context.mounted) return;
  if (!config.completa || !(estado?.listo ?? false)) {
    final configurar = await confirmar(
      context,
      titulo: 'Falta configurar la facturación',
      mensaje: sesion.puede(Permiso.editarNegocio)
          ? 'Antes de facturar hay que cargar los datos fiscales y conectar el sistema con ARCA.'
          : 'Pedile al dueño del negocio que configure la facturación electrónica.',
      confirmar: sesion.puede(Permiso.editarNegocio) ? 'Configurar ahora' : 'Entendido',
    );
    if (configurar && context.mounted && sesion.puede(Permiso.editarNegocio)) abrirPagina(context, const ConfigArcaPage());
    return;
  }

  final cliente = clienteId == null || clienteId.isEmpty ? null : await sesion.clientes.obtener(clienteId);
  if (!context.mounted) return;
  final facturaId = await showDialog<String>(
    context: context,
    builder: (_) => _DialogoFacturar(
      config: config,
      total: total,
      cliente: cliente,
      nombreCliente: nombreCliente,
      emitir: (receptor, concepto) => sesion.facturacion.emitir(
        origenTipo: origenTipo,
        origenId: origenId,
        receptor: receptor,
        concepto: concepto,
      ),
    ),
  );
  if (facturaId != null && context.mounted) {
    mostrarMensaje(context, 'Factura autorizada por ARCA');
    abrirPagina(context, FacturaDetallePage(facturaId: facturaId));
  }
}

class _DialogoFacturar extends StatefulWidget {
  const _DialogoFacturar({
    required this.config,
    required this.total,
    required this.cliente,
    required this.nombreCliente,
    required this.emitir,
  });

  final ConfigFiscal config;
  final double total;
  final Cliente? cliente;
  final String nombreCliente;
  final Future<String> Function(ReceptorFactura, ConceptoFactura) emitir;

  @override
  State<_DialogoFacturar> createState() => _DialogoFacturarState();
}

class _DialogoFacturarState extends State<_DialogoFacturar> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.cliente?.nombre ?? widget.nombreCliente);
  late final _doc = TextEditingController(text: _docInicial().replaceAll(RegExp(r'\D'), ''));
  late String _docTipo = _tipoInicial();
  late CondicionIva _condicion = widget.cliente?.condicionIva ?? CondicionIva.consumidorFinal;
  late ConceptoFactura _concepto = widget.config.concepto;
  bool _emitiendo = false;
  String? _error;

  String _docInicial() => widget.cliente?.documento ?? '';

  String _tipoInicial() {
    final d = _docInicial().replaceAll(RegExp(r'\D'), '');
    if (d.length == 11) return 'cuit';
    if (d.length == 7 || d.length == 8) return 'dni';
    return 'consumidor_final';
  }

  @override
  void dispose() {
    _nombre.dispose();
    _doc.dispose();
    super.dispose();
  }

  String get _letra => ReceptorFactura.letraPara(widget.config.condicionIva, _condicion);

  Future<void> _emitir() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _emitiendo = true;
      _error = null;
    });
    try {
      final id = await widget.emitir(
        ReceptorFactura(
          nombre: _nombre.text.trim().isEmpty ? 'Consumidor final' : _nombre.text.trim(),
          docTipo: _docTipo,
          docNro: _doc.text,
          condicionIva: _docTipo == 'consumidor_final' ? CondicionIva.consumidorFinal : _condicion,
        ),
        _concepto,
      );
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _emitiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esA = _letra == 'A';
    return AlertDialog(
      title: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border.all(color: context.esquema.onSurface, width: 2), borderRadius: BorderRadius.circular(Radios.s)),
          child: Text(_letra, style: context.textos.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: Espacio.m),
        Expanded(child: Text('Factura $_letra por ${Formato.moneda(widget.total)}')),
      ]),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (widget.config.ambiente == AmbienteArca.homologacion)
                Padding(
                  padding: const EdgeInsets.only(bottom: Espacio.m),
                  child: Etiqueta(
                    texto: 'Modo pruebas: sin validez fiscal',
                    color: context.colores.alerta,
                    fondo: context.colores.alertaSuave,
                    icono: Icons.science_outlined,
                  ),
                ),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'consumidor_final', label: Text('Cons. final')),
                  ButtonSegment(value: 'dni', label: Text('DNI')),
                  ButtonSegment(value: 'cuit', label: Text('CUIT')),
                ],
                selected: {_docTipo},
                onSelectionChanged: (s) => setState(() {
                  _docTipo = s.first;
                  if (_docTipo != 'cuit' && (_condicion == CondicionIva.responsableInscripto || _condicion == CondicionIva.monotributo)) {
                    _condicion = CondicionIva.consumidorFinal;
                  }
                }),
              ),
              const SizedBox(height: Espacio.l),
              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre o razón social'),
                validator: (v) => (_docTipo != 'consumidor_final' && (v == null || v.trim().isEmpty)) ? 'Obligatorio' : null,
              ),
              if (_docTipo != 'consumidor_final') ...[
                const SizedBox(height: Espacio.l),
                TextFormField(
                  controller: _doc,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: _docTipo == 'cuit' ? 'CUIT (sin guiones)' : 'DNI'),
                  validator: (v) {
                    final d = v ?? '';
                    if (_docTipo == 'cuit') return cuitValido(d) ? null : 'CUIT inválido';
                    return (d.length == 7 || d.length == 8) ? null : 'DNI inválido';
                  },
                ),
              ],
              if (_docTipo == 'cuit') ...[
                const SizedBox(height: Espacio.l),
                DropdownButtonFormField<CondicionIva>(
                  value: _condicion,
                  decoration: const InputDecoration(labelText: 'Condición frente al IVA del cliente'),
                  items: [for (final c in CondicionIva.values) DropdownMenuItem(value: c, child: Text(c.etiqueta))],
                  onChanged: (c) => setState(() => _condicion = c ?? _condicion),
                ),
              ],
              const SizedBox(height: Espacio.l),
              DropdownButtonFormField<ConceptoFactura>(
                value: _concepto,
                decoration: const InputDecoration(labelText: 'Concepto'),
                items: [for (final c in ConceptoFactura.values) DropdownMenuItem(value: c, child: Text(c.etiqueta))],
                onChanged: (c) => setState(() => _concepto = c ?? _concepto),
              ),
              if (esA) ...[
                const SizedBox(height: Espacio.m),
                Text(
                  'En la factura A se discrimina el IVA (${Formato.cantidad(widget.config.alicuotaIva)}%).',
                  style: context.textos.bodySmall,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: Espacio.l),
                Container(
                  padding: const EdgeInsets.all(Espacio.m),
                  decoration: BoxDecoration(color: context.colores.peligroSuave, borderRadius: BorderRadius.circular(Radios.m)),
                  child: Text(_error!, style: TextStyle(color: context.colores.peligro)),
                ),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _emitiendo ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton.icon(
          onPressed: _emitiendo ? null : _emitir,
          icon: _emitiendo
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.verified_outlined),
          label: Text(_emitiendo ? 'Pidiendo CAE a ARCA…' : 'Emitir factura'),
        ),
      ],
    );
  }
}
