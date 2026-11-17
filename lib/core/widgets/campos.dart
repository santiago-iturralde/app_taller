import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../utils/formato.dart';

/// Campo para importes. Acepta `15.000`, `15000,50`, etc.
class CampoMonto extends StatelessWidget {
  const CampoMonto({
    super.key,
    required this.controller,
    this.etiqueta = 'Importe',
    this.obligatorio = true,
    this.permitirCero = false,
    this.autofocus = false,
    this.onChanged,
    this.textInputAction,
    this.helper,
  });

  final TextEditingController controller;
  final String etiqueta;
  final bool obligatorio;
  final bool permitirCero;
  final bool autofocus;
  final ValueChanged<double?>? onChanged;
  final TextInputAction? textInputAction;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      textInputAction: textInputAction,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
      decoration: InputDecoration(labelText: etiqueta, prefixText: r'$ ', helperText: helper),
      onChanged: onChanged == null ? null : (v) => onChanged!(Formato.parseMonto(v)),
      validator: (v) {
        final texto = v?.trim() ?? '';
        if (texto.isEmpty) return obligatorio ? 'Ingresá un importe' : null;
        final monto = Formato.parseMonto(texto);
        if (monto == null) return 'Importe inválido';
        if (monto < 0 || (!permitirCero && monto == 0)) return 'Tiene que ser mayor a cero';
        return null;
      },
    );
  }
}

/// Buscador con espera (debounce) para no consultar en cada tecla.
class Buscador extends StatefulWidget {
  const Buscador({super.key, required this.onBuscar, this.hint = 'Buscar…', this.autofocus = false});

  final ValueChanged<String> onBuscar;
  final String hint;
  final bool autofocus;

  @override
  State<Buscador> createState() => _BuscadorState();
}

class _BuscadorState extends State<Buscador> {
  final _ctrl = TextEditingController();
  Timer? _espera;

  @override
  void dispose() {
    _espera?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _cambio(String v) {
    setState(() {});
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 350), () => widget.onBuscar(v.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      autofocus: widget.autofocus,
      onChanged: _cambio,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search_rounded),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        suffixIcon: _ctrl.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpiar',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _ctrl.clear();
                  _cambio('');
                },
              ),
      ),
    );
  }
}

/// Selector "‹ Noviembre 2026 ›".
class SelectorMes extends StatelessWidget {
  const SelectorMes({super.key, required this.mes, required this.onCambio});
  final DateTime mes;
  final ValueChanged<DateTime> onCambio;

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final esActual = mes.year == ahora.year && mes.month == ahora.month;
    return Container(
      decoration: BoxDecoration(
        color: context.esquema.surface,
        borderRadius: BorderRadius.circular(Radios.m),
        border: Border.all(color: context.colores.borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Mes anterior',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => onCambio(DateTime(mes.year, mes.month - 1)),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 130),
            child: Text(Formato.mesAnio(mes), textAlign: TextAlign.center, style: context.textos.titleSmall),
          ),
          IconButton(
            tooltip: 'Mes siguiente',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: esActual ? null : () => onCambio(DateTime(mes.year, mes.month + 1)),
          ),
        ],
      ),
    );
  }
}

/// Campo de fecha que abre el calendario.
class CampoFecha extends StatelessWidget {
  const CampoFecha({super.key, required this.etiqueta, required this.valor, required this.onCambio, this.permitirVacio = false, this.primera, this.ultima});

  final String etiqueta;
  final DateTime? valor;
  final ValueChanged<DateTime?> onCambio;
  final bool permitirVacio;
  final DateTime? primera;
  final DateTime? ultima;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Radios.m),
      onTap: () async {
        final ahora = DateTime.now();
        final f = await showDatePicker(
          context: context,
          initialDate: valor ?? ahora,
          firstDate: primera ?? DateTime(ahora.year - 5),
          lastDate: ultima ?? DateTime(ahora.year + 2),
        );
        if (f != null) onCambio(f);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: etiqueta,
          prefixIcon: const Icon(Icons.event_outlined),
          suffixIcon: (permitirVacio && valor != null)
              ? IconButton(tooltip: 'Quitar', icon: const Icon(Icons.close_rounded), onPressed: () => onCambio(null))
              : null,
        ),
        child: Text(valor == null ? 'Sin fecha' : Formato.fecha(valor!)),
      ),
    );
  }
}
