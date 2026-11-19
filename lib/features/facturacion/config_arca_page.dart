import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;

import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/formulario.dart';
import '../../data/models/fiscal.dart';
import '../../data/models/negocio.dart';
import '../planes/pro.dart';

/// Configuración de la facturación electrónica: datos fiscales y conexión
/// con ARCA en tres pasos.
class ConfigArcaPage extends StatelessWidget {
  const ConfigArcaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = Sesion.of(context);
    final repo = sesion.facturacion;
    return Scaffold(
      appBar: AppBar(title: const Text('Facturación electrónica (ARCA)')),
      body: !sesion.negocio.permite(FuncionPro.facturacion)
          ? EstadoVacio(
              icono: Icons.receipt_long_outlined,
              titulo: 'Facturá desde el sistema',
              mensaje: 'Emití facturas A, B y C autorizadas por ARCA desde cada trabajo o venta, con CAE y código QR. '
                  'Disponible desde el plan ${FuncionPro.facturacion.planMinimo.nombre}.',
              accion: FilledButton(onPressed: () => exigirPro(context, FuncionPro.facturacion), child: const Text('Ver planes')),
            )
          : StreamBuilder<ConfigFiscal>(
              stream: repo.config(),
              builder: (context, sc) {
                if (sc.hasError) return EstadoError(error: sc.error);
                if (!sc.hasData) return const Cargando();
                final config = sc.data!;
                return StreamBuilder<Map<AmbienteArca, EstadoArca>>(
                  stream: repo.estado(),
                  builder: (context, se) {
                    final estado = se.data?[config.ambiente] ?? const EstadoArca();
                    return ListView(
                      padding: const EdgeInsets.all(Espacio.l),
                      children: [
                        ContenidoCentrado(
                          anchoMaximo: 760,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            const Seccion('1. Datos fiscales', padding: EdgeInsets.only(bottom: Espacio.m)),
                            _DatosFiscales(config: config),
                            const Seccion('2. Conexión con ARCA'),
                            if (!config.completa)
                              AppCard(child: Text('Completá y guardá los datos fiscales para continuar.', style: TextStyle(color: context.esquema.onSurfaceVariant)))
                            else
                              _Conexion(config: config, estado: estado),
                          ]),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

class _DatosFiscales extends StatefulWidget {
  const _DatosFiscales({required this.config});
  final ConfigFiscal config;

  @override
  State<_DatosFiscales> createState() => _DatosFiscalesState();
}

class _DatosFiscalesState extends State<_DatosFiscales> {
  final _form = GlobalKey<FormState>();
  late final _razon = TextEditingController(text: widget.config.razonSocial.isEmpty ? Sesion.of(context).negocio.nombre : widget.config.razonSocial);
  late final _cuit = TextEditingController(text: widget.config.cuit);
  late final _domicilio = TextEditingController(text: widget.config.domicilio.isEmpty ? Sesion.of(context).negocio.direccion : widget.config.domicilio);
  late final _iibb = TextEditingController(text: widget.config.ingresosBrutos);
  late final _inicio = TextEditingController(text: widget.config.inicioActividades);
  late final _pv = TextEditingController(text: '${widget.config.puntoVenta}');
  late CondicionIva _condicion = widget.config.condicionIva;
  late double _alicuota = widget.config.alicuotaIva;
  late AmbienteArca _ambiente = widget.config.ambiente;
  late ConceptoFactura _concepto = widget.config.concepto;
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in [_razon, _cuit, _domicilio, _iibb, _inicio, _pv]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    if (_ambiente == AmbienteArca.produccion && widget.config.ambiente != AmbienteArca.produccion) {
      final ok = await confirmar(
        context,
        titulo: 'Pasar a producción',
        mensaje: 'Desde ahora las facturas serán reales y se informan a ARCA. '
            'Vas a necesitar el certificado de producción (es distinto al de pruebas).',
        confirmar: 'Pasar a producción',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _guardando = true);
    final repo = Sesion.of(context).facturacion;
    await ejecutar(
      context,
      () => repo.guardarConfig(ConfigFiscal(
        razonSocial: _razon.text.trim(),
        cuit: _cuit.text.replaceAll(RegExp(r'\D'), ''),
        condicionIva: _condicion,
        domicilio: _domicilio.text.trim(),
        ingresosBrutos: _iibb.text.trim(),
        inicioActividades: _inicio.text.trim(),
        puntoVenta: int.parse(_pv.text),
        alicuotaIva: _alicuota,
        ambiente: _ambiente,
        concepto: _concepto,
      )),
      exito: 'Datos fiscales guardados',
    );
    if (mounted) setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    final puedeEditar = Sesion.of(context).puede(Permiso.editarNegocio);
    return AppCard(
      padding: const EdgeInsets.all(Espacio.xl),
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(
            controller: _razon,
            enabled: puedeEditar,
            decoration: const InputDecoration(labelText: 'Razón social', helperText: 'Tal como figura en ARCA'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
          ),
          espacioCampos,
          FilaCampos(children: [
            TextFormField(
              controller: _cuit,
              enabled: puedeEditar,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d-]'))],
              decoration: const InputDecoration(labelText: 'CUIT', hintText: '20-12345678-9'),
              validator: (v) => cuitValido(v ?? '') ? null : 'CUIT inválido',
            ),
            DropdownButtonFormField<CondicionIva>(
              value: _condicion,
              decoration: const InputDecoration(labelText: 'Condición frente al IVA'),
              items: [for (final c in CondicionIva.emisores) DropdownMenuItem(value: c, child: Text(c.etiqueta))],
              onChanged: puedeEditar ? (c) => setState(() => _condicion = c ?? _condicion) : null,
            ),
          ]),
          espacioCampos,
          TextFormField(controller: _domicilio, enabled: puedeEditar, decoration: const InputDecoration(labelText: 'Domicilio comercial')),
          espacioCampos,
          FilaCampos(children: [
            TextFormField(controller: _iibb, enabled: puedeEditar, decoration: const InputDecoration(labelText: 'Ingresos Brutos', hintText: 'N° o "Exento"')),
            TextFormField(controller: _inicio, enabled: puedeEditar, decoration: const InputDecoration(labelText: 'Inicio de actividades', hintText: 'dd/mm/aaaa')),
          ]),
          espacioCampos,
          FilaCampos(children: [
            TextFormField(
              controller: _pv,
              enabled: puedeEditar,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Punto de venta', helperText: 'Tipo "RECE / web services"'),
              validator: (v) {
                final n = int.tryParse(v ?? '') ?? 0;
                return n < 1 || n > 99998 ? 'Inválido' : null;
              },
            ),
            if (_condicion == CondicionIva.responsableInscripto)
              DropdownButtonFormField<double>(
                value: _alicuota,
                decoration: const InputDecoration(labelText: 'IVA de tus precios'),
                items: [for (final a in ConfigFiscal.alicuotas) DropdownMenuItem(value: a, child: Text('${Formato.cantidad(a)}%'))],
                onChanged: puedeEditar ? (a) => setState(() => _alicuota = a ?? _alicuota) : null,
              )
            else
              const SizedBox.shrink(),
          ]),
          espacioCampos,
          DropdownButtonFormField<ConceptoFactura>(
            value: _concepto,
            decoration: const InputDecoration(labelText: 'Qué facturás habitualmente'),
            items: [for (final c in ConceptoFactura.values) DropdownMenuItem(value: c, child: Text(c.etiqueta))],
            onChanged: puedeEditar ? (c) => setState(() => _concepto = c ?? _concepto) : null,
          ),
          espacioCampos,
          SegmentedButton<AmbienteArca>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: AmbienteArca.homologacion, label: Text('Pruebas'), icon: Icon(Icons.science_outlined)),
              ButtonSegment(value: AmbienteArca.produccion, label: Text('Producción'), icon: Icon(Icons.verified_outlined)),
            ],
            selected: {_ambiente},
            onSelectionChanged: puedeEditar ? (s) => setState(() => _ambiente = s.first) : null,
          ),
          const SizedBox(height: Espacio.s),
          Text(
            _ambiente == AmbienteArca.homologacion
                ? 'Modo pruebas: las facturas NO son válidas. Usalo para verificar que todo funcione.'
                : 'Producción: las facturas son reales y se informan a ARCA.',
            style: context.textos.bodySmall?.copyWith(color: context.esquema.onSurfaceVariant),
          ),
          const SizedBox(height: Espacio.l),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: (!puedeEditar || _guardando) ? null : _guardar,
              child: const Text('Guardar datos fiscales'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Conexion extends StatefulWidget {
  const _Conexion({required this.config, required this.estado});
  final ConfigFiscal config;
  final EstadoArca estado;

  @override
  State<_Conexion> createState() => _ConexionState();
}

class _ConexionState extends State<_Conexion> {
  final _certificado = TextEditingController();
  bool _ocupado = false;

  @override
  void dispose() {
    _certificado.dispose();
    super.dispose();
  }

  Future<void> _conBloqueo(Future<void> Function() tarea) async {
    setState(() => _ocupado = true);
    try {
      await tarea();
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _generar() async {
    if (widget.estado.listo) {
      final ok = await confirmar(
        context,
        titulo: 'Generar una nueva solicitud',
        mensaje: 'El certificado actual dejará de funcionar hasta que cargues el nuevo. ¿Continuar?',
        confirmar: 'Generar',
        peligroso: true,
      );
      if (!ok || !mounted) return;
    }
    final repo = Sesion.of(context).facturacion;
    await _conBloqueo(() async {
      String? csr;
      final ok = await ejecutar(context, () async => csr = await repo.generarSolicitud());
      if (ok && mounted && csr != null) await _mostrarCsr(csr!);
    });
  }

  Future<void> _mostrarCsr(String csr) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Solicitud de certificado lista'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Descargá este archivo (o copiá el texto) y cargalo en ARCA siguiendo los pasos de abajo.'),
              const SizedBox(height: Espacio.m),
              Container(
                height: 160,
                padding: const EdgeInsets.all(Espacio.s),
                decoration: BoxDecoration(color: context.colores.fondoSutil, borderRadius: BorderRadius.circular(Radios.s), border: Border.all(color: context.colores.borde)),
                child: SingleChildScrollView(child: SelectableText(csr, style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
              ),
            ]),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: csr));
                if (context.mounted) mostrarMensaje(context, 'Copiado');
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar'),
            ),
            if (kIsWeb)
              FilledButton.icon(
                onPressed: () => _descargar(csr, 'solicitud_${widget.config.cuit}.csr'),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Descargar .csr'),
              ),
          ],
        ),
      );

  void _descargar(String texto, String nombre) {
    final url = 'data:application/pkcs10;base64,${base64Encode(utf8.encode(texto))}';
    html.AnchorElement(href: url)
      ..download = nombre
      ..click();
  }

  Future<void> _guardarCertificado() async {
    final texto = _certificado.text.trim();
    if (!texto.contains('BEGIN CERTIFICATE')) {
      mostrarMensaje(context, 'Pegá el contenido completo del archivo .crt (empieza con -----BEGIN CERTIFICATE-----).', error: true);
      return;
    }
    final repo = Sesion.of(context).facturacion;
    await _conBloqueo(() async {
      final ok = await ejecutar(context, () => repo.guardarCertificado(texto), exito: 'Certificado guardado');
      if (ok) {
        _certificado.clear();
        if (mounted) await _probar();
      }
    });
  }

  Future<void> _probar() async {
    final repo = Sesion.of(context).facturacion;
    await _conBloqueo(() async {
      String? mensaje;
      final ok = await ejecutar(context, () async => mensaje = await repo.probarConexion());
      if (ok && mounted) mostrarMensaje(context, mensaje!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.estado;
    final c = context.colores;
    final homo = widget.config.ambiente == AmbienteArca.homologacion;
    final (texto, color, fondo, icono) = e.listo
        ? ('Conectado', c.exito, c.exitoSuave, Icons.check_circle_outline_rounded)
        : e.esperandoCertificado
            ? ('Esperando certificado', c.alerta, c.alertaSuave, Icons.hourglass_top_rounded)
            : ('Sin configurar', c.neutro, c.neutroSuave, Icons.link_off_rounded);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppCard(
        padding: const EdgeInsets.all(Espacio.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(widget.config.ambiente.etiqueta, style: context.textos.titleSmall)),
            Etiqueta(texto: texto, color: color, fondo: fondo, icono: icono),
          ]),
          if (e.certificadoVence != null) ...[
            const SizedBox(height: Espacio.xs),
            Text('Certificado válido hasta el ${Formato.fecha(e.certificadoVence!)}', style: context.textos.bodySmall),
          ],
          if (e.mensaje != null) ...[
            const SizedBox(height: Espacio.s),
            Text(e.mensaje!, style: context.textos.bodySmall?.copyWith(color: context.esquema.onSurfaceVariant)),
          ],
          const SizedBox(height: Espacio.l),
          Wrap(spacing: Espacio.s, runSpacing: Espacio.s, children: [
            if (e.listo)
              FilledButton.icon(onPressed: _ocupado ? null : _probar, icon: const Icon(Icons.wifi_tethering_rounded), label: const Text('Probar conexión')),
            OutlinedButton.icon(
              onPressed: _ocupado ? null : _generar,
              icon: const Icon(Icons.key_outlined),
              label: Text(e.listo ? 'Renovar certificado' : 'Generar solicitud de certificado'),
            ),
          ]),
          if (_ocupado) const Padding(padding: EdgeInsets.only(top: Espacio.m), child: LinearProgressIndicator()),
        ]),
      ),
      if (!e.listo) ...[
        const SizedBox(height: Espacio.m),
        _Pasos(homologacion: homo, alias: homo ? 'workcontrolhomo' : 'workcontrol'),
        const SizedBox(height: Espacio.m),
        AppCard(
          padding: const EdgeInsets.all(Espacio.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Pegá acá el certificado que te dio ARCA', style: context.textos.titleSmall),
            const SizedBox(height: Espacio.m),
            TextField(
              controller: _certificado,
              minLines: 4,
              maxLines: 8,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(hintText: '-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----'),
            ),
            const SizedBox(height: Espacio.m),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: _ocupado ? null : _guardarCertificado, child: const Text('Guardar certificado y probar')),
            ),
          ]),
        ),
      ],
    ]);
  }
}

/// Instrucciones para obtener el certificado en ARCA.
class _Pasos extends StatelessWidget {
  const _Pasos({required this.homologacion, required this.alias});
  final bool homologacion;
  final String alias;

  @override
  Widget build(BuildContext context) {
    final pasos = homologacion
        ? [
            'Tocá "Generar solicitud de certificado" y descargá el archivo .csr.',
            'Entrá a arca.gob.ar con tu clave fiscal y abrí el servicio "WSASS - Autogestión Certificados Homologación" '
                '(si no lo tenés, adheríte desde el Administrador de Relaciones).',
            'En "Nuevo certificado", poné como nombre "$alias" y pegá el contenido del .csr. Copiá el certificado que te devuelve.',
            'En WSASS, en "Crear autorización a servicio", autorizá ese certificado para el servicio "wsfe".',
            'Pegá el certificado acá abajo y tocá "Guardar certificado y probar".',
          ]
        : [
            'Tocá "Generar solicitud de certificado" y descargá el archivo .csr.',
            'En arca.gob.ar con clave fiscal, abrí "Administración de Certificados Digitales", agregá el alias "$alias" '
                'y subí el .csr. Descargá el certificado (.crt).',
            'En "Administrador de Relaciones de Clave Fiscal", hacé "Nueva relación" con el servicio '
                '"Facturación electrónica" (wsfe) para el certificado "$alias".',
            'En "Administración de puntos de venta y domicilios", creá un punto de venta del tipo '
                '"Factura electrónica - Monotributo / RECE - Web Services" y cargá ese número en los datos fiscales.',
            'Abrí el .crt con el Bloc de notas, copiá todo, pegalo acá abajo y tocá "Guardar certificado y probar".',
          ];
    return AppCard(
      padding: const EdgeInsets.all(Espacio.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Cómo obtener el certificado', style: context.textos.titleSmall),
        const SizedBox(height: Espacio.m),
        for (var i = 0; i < pasos.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Espacio.m),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 12, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
              const SizedBox(width: Espacio.m),
              Expanded(child: Text(pasos[i])),
            ]),
          ),
        Text(
          'La clave privada se genera y guarda cifrada en nuestro servidor: nunca se descarga ni se comparte.',
          style: context.textos.bodySmall?.copyWith(color: context.esquema.onSurfaceVariant),
        ),
      ]),
    );
  }
}
