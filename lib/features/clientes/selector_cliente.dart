import 'package:flutter/material.dart';

import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/campos.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/cliente.dart';
import 'cliente_form.dart';

/// Campo de formulario para elegir un cliente: busca por nombre, teléfono
/// o documento, y permite crearlo en el momento si no existe.
class CampoCliente extends FormField<Cliente> {
  CampoCliente({super.key, super.initialValue, required ValueChanged<Cliente> onCambio})
      : super(
          validator: (c) => c == null ? 'Elegí un cliente' : null,
          builder: (state) {
            final context = state.context;
            final cliente = state.value;
            return InkWell(
              borderRadius: BorderRadius.circular(Radios.m),
              onTap: () async {
                final elegido = await elegirCliente(context);
                if (elegido != null) {
                  state.didChange(elegido);
                  onCambio(elegido);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Cliente',
                  errorText: state.errorText,
                  prefixIcon: cliente == null
                      ? const Icon(Icons.person_search_outlined)
                      : Padding(padding: const EdgeInsets.all(10), child: Iniciales(cliente.iniciales, radio: 12)),
                  suffixIcon: const Icon(Icons.unfold_more_rounded),
                ),
                child: Text(
                  cliente == null ? 'Buscar o crear cliente' : cliente.nombre,
                  style: cliente == null ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant) : null,
                ),
              ),
            );
          },
        );
}

Future<Cliente?> elegirCliente(BuildContext context) {
  final sesion = Sesion.of(context);
  final contenido = _BuscadorClientes(sesion: sesion);
  if (context.esEscritorio) {
    return showDialog<Cliente>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620), child: contenido),
      ),
    );
  }
  return showModalBottomSheet<Cliente>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(heightFactor: 0.9, child: contenido),
  );
}

class _BuscadorClientes extends StatefulWidget {
  const _BuscadorClientes({required this.sesion});
  final Sesion sesion;

  @override
  State<_BuscadorClientes> createState() => _BuscadorClientesState();
}

class _BuscadorClientesState extends State<_BuscadorClientes> {
  String _consulta = '';
  Future<List<Cliente>>? _resultados;

  void _buscar(String q) => setState(() {
        _consulta = q;
        _resultados = q.isEmpty ? null : widget.sesion.clientes.buscar(q);
      });

  Future<void> _crear() async {
    final nuevo = await abrirFormulario<Cliente>(context, ClienteForm(nombreInicial: _consulta));
    if (nuevo != null && mounted) Navigator.pop(context, nuevo);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Espacio.l, Espacio.l, Espacio.l, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Elegí un cliente', style: context.textos.titleMedium),
          const SizedBox(height: Espacio.m),
          Buscador(onBuscar: _buscar, hint: 'Nombre, teléfono o DNI', autofocus: true),
          const SizedBox(height: Espacio.s),
          ListTile(
            leading: IconoTile(Icons.person_add_alt_1_rounded, tamanio: 36, color: context.esquema.primary),
            title: Text(_consulta.isEmpty ? 'Nuevo cliente' : 'Crear "$_consulta"'),
            onTap: _crear,
          ),
          const Divider(),
          Expanded(
            child: _resultados == null
                ? StreamBuilder<List<Cliente>>(
                    stream: widget.sesion.clientes.listar(limite: 30),
                    builder: (context, s) => _lista(s.data, s.hasError, titulo: 'Clientes'),
                  )
                : FutureBuilder<List<Cliente>>(
                    future: _resultados,
                    builder: (context, s) => s.connectionState == ConnectionState.waiting
                        ? const Cargando()
                        : _lista(s.data, s.hasError),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _lista(List<Cliente>? clientes, bool error, {String? titulo}) {
    if (error) return const EstadoError();
    if (clientes == null) return const Cargando();
    if (clientes.isEmpty) {
      return EstadoVacio(
        icono: Icons.person_search_outlined,
        titulo: _consulta.isEmpty ? 'Todavía no hay clientes' : 'Sin resultados',
        mensaje: _consulta.isEmpty ? null : 'Podés crearlo con el botón de arriba.',
      );
    }
    return ListView.builder(
      itemCount: clientes.length,
      itemBuilder: (context, i) {
        final c = clientes[i];
        return ListTile(
          leading: Iniciales(c.iniciales, radio: 18),
          title: Text(c.nombre),
          subtitle: c.telefono.isEmpty ? null : Text(c.telefono),
          onTap: () => Navigator.pop(context, c),
        );
      },
    );
  }
}
