import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/utils/whatsapp.dart';
import '../../core/widgets/campos.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/negocio.dart';
import '../../data/repositories/admin_repository.dart';
import '../planes/pro.dart';
import 'widgets_admin.dart';

/// Ficha de un negocio para el administrador: plan, vencimiento y acciones.
class AdminNegocioPage extends StatelessWidget {
  AdminNegocioPage({super.key, required this.negocioId});
  final String negocioId;
  final _repo = AdminRepository();

  Future<void> _activar(BuildContext context, Negocio n) async {
    final datos = await showDialog<_DatosActivacion>(context: context, builder: (_) => _DialogoActivar(negocio: n));
    if (datos == null || !context.mounted) return;
    await ejecutar(
      context,
      () => _repo.activarPlan(n.id, datos.plan, datos.meses, monto: datos.monto, nota: datos.nota),
      exito: 'Plan ${datos.plan.nombre} activado',
    );
  }

  Future<void> _prueba(BuildContext context, Negocio n) async {
    final dias = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Dar días de prueba del plan PRO'),
        children: [
          for (final d in [7, 15, 30])
            SimpleDialogOption(onPressed: () => Navigator.pop(context, d), child: Text('$d días')),
        ],
      ),
    );
    if (dias == null || !context.mounted) return;
    await ejecutar(context, () => _repo.darPrueba(n.id, dias), exito: 'Prueba de $dias días activada');
  }

  Future<void> _gratis(BuildContext context, Negocio n) async {
    final ok = await confirmar(
      context,
      titulo: 'Pasar a plan Gratis',
      mensaje: '${n.nombre} pierde las funciones pagas de inmediato. Sus datos no se borran.',
      confirmar: 'Pasar a Gratis',
      peligroso: true,
    );
    if (ok && context.mounted) await ejecutar(context, () => _repo.pasarAGratis(n.id), exito: 'Plan cambiado a Gratis');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Negocio?>(
      stream: _repo.negocio(negocioId),
      builder: (context, s) {
        if (s.hasError) return Scaffold(appBar: AppBar(), body: EstadoError(error: s.error));
        if (!s.hasData) return Scaffold(appBar: AppBar(), body: const Cargando());
        final n = s.data!;
        return Scaffold(
          appBar: AppBar(title: Text(n.nombre)),
          body: ListView(
            padding: const EdgeInsets.all(Espacio.l),
            children: [
              ContenidoCentrado(
                anchoMaximo: 760,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  AppCard(
                    padding: const EdgeInsets.all(Espacio.xl),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        IconoTile(n.rubro.icono, tamanio: 48),
                        const SizedBox(width: Espacio.l),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(n.nombre, style: context.textos.titleLarge),
                            Text(n.rubro.nombre, style: TextStyle(color: context.esquema.onSurfaceVariant)),
                          ]),
                        ),
                        EtiquetaPlanAdmin(negocio: n),
                      ]),
                      const SizedBox(height: Espacio.l),
                      FutureBuilder<(String, int)>(
                        future: (_repo.emailDuenio(n.id), _repo.cantidadMiembros(n.id)).wait,
                        builder: (context, sd) => Wrap(spacing: Espacio.xl, runSpacing: Espacio.s, children: [
                          _Dato('Dueño', sd.data?.$1.isNotEmpty == true ? sd.data!.$1 : '—'),
                          _Dato('Usuarios', sd.hasData ? '${sd.data!.$2}' : '—'),
                          if (n.telefono.isNotEmpty) _Dato('Teléfono', n.telefono),
                          if (n.email.isNotEmpty) _Dato('Email del negocio', n.email),
                          _Dato('Código', n.id, copiable: true),
                        ]),
                      ),
                      if (n.telefono.isNotEmpty) ...[
                        const SizedBox(height: Espacio.m),
                        OutlinedButton.icon(
                          onPressed: () => WhatsApp.enviar(n.telefono, 'Hola! Te escribo de WorkControl por tu plan de "${n.nombre}".'),
                          icon: const Icon(Icons.chat_outlined),
                          label: const Text('Escribirle por WhatsApp'),
                        ),
                      ],
                    ]),
                  ),
                  const Seccion('Plan'),
                  AppCard(
                    padding: const EdgeInsets.all(Espacio.xl),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(etiquetaPlan(n), style: context.textos.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        n.planVence == null
                            ? 'Sin vencimiento'
                            : '${n.vencido ? 'Venció' : 'Vence'} el ${Formato.fecha(n.planVence!)}',
                        style: TextStyle(color: context.esquema.onSurfaceVariant),
                      ),
                      const SizedBox(height: Espacio.l),
                      Wrap(spacing: Espacio.s, runSpacing: Espacio.s, children: [
                        FilledButton.icon(
                          onPressed: () => _activar(context, n),
                          icon: const Icon(Icons.verified_outlined),
                          label: Text(n.plan != Plan.gratis && !n.vencido && !n.prueba ? 'Renovar' : 'Activar plan'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _prueba(context, n),
                          icon: const Icon(Icons.rocket_launch_outlined),
                          label: const Text('Dar prueba'),
                        ),
                        if (n.plan != Plan.gratis)
                          TextButton.icon(
                            onPressed: () => _gratis(context, n),
                            icon: const Icon(Icons.remove_circle_outline_rounded),
                            label: const Text('Pasar a Gratis'),
                          ),
                      ]),
                    ]),
                  ),
                  const Seccion('Historial'),
                  HistorialPlanes(stream: _repo.historial(negocioId: n.id)),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor, {this.copiable = false});
  final String etiqueta;
  final String valor;
  final bool copiable;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(etiqueta, style: context.textos.labelSmall?.copyWith(color: context.esquema.onSurfaceVariant)),
        Row(mainAxisSize: MainAxisSize.min, children: [
          SelectableText(valor),
          if (copiable)
            IconButton(
              tooltip: 'Copiar',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy_rounded, size: 16),
              onPressed: () => Clipboard.setData(ClipboardData(text: valor)),
            ),
        ]),
      ]);
}

class _DatosActivacion {
  const _DatosActivacion(this.plan, this.meses, this.monto, this.nota);
  final Plan plan;
  final int meses;
  final double? monto;
  final String nota;
}

class _DialogoActivar extends StatefulWidget {
  const _DialogoActivar({required this.negocio});
  final Negocio negocio;

  @override
  State<_DialogoActivar> createState() => _DialogoActivarState();
}

class _DialogoActivarState extends State<_DialogoActivar> {
  final _form = GlobalKey<FormState>();
  late Plan _plan = widget.negocio.plan == Plan.basico ? Plan.basico : Plan.pro;
  int _meses = 1;
  final _monto = TextEditingController();
  final _nota = TextEditingController();

  @override
  void dispose() {
    _monto.dispose();
    _nota.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.negocio;
    final suma = n.plan == _plan && !n.vencido && n.planVence != null;
    return AlertDialog(
      title: const Text('Activar o renovar plan'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SegmentedButton<Plan>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: Plan.basico, label: Text('Básico')),
                ButtonSegment(value: Plan.pro, label: Text('PRO')),
              ],
              selected: {_plan},
              onSelectionChanged: (s) => setState(() => _plan = s.first),
            ),
            const SizedBox(height: Espacio.l),
            Wrap(spacing: Espacio.s, children: [
              for (final m in [1, 3, 6, 12])
                ChoiceChip(
                  label: Text(m == 1 ? '1 mes' : '$m meses'),
                  selected: _meses == m,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _meses = m),
                ),
            ]),
            const SizedBox(height: Espacio.s),
            Text(
              suma
                  ? 'Se suma al vencimiento actual (${Formato.fecha(n.planVence!)}).'
                  : 'Cuenta desde hoy.',
              style: context.textos.bodySmall,
            ),
            const SizedBox(height: Espacio.l),
            CampoMonto(controller: _monto, etiqueta: 'Monto cobrado (opcional)', obligatorio: false, permitirCero: true),
            const SizedBox(height: Espacio.m),
            TextField(controller: _nota, decoration: const InputDecoration(labelText: 'Nota (opcional)', hintText: 'Ej: Transferencia 18/11')),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(context, _DatosActivacion(_plan, _meses, Formato.parseMonto(_monto.text), _nota.text.trim()));
          },
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
