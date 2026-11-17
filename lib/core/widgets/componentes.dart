import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tarjeta base: superficie con borde fino, sin sombras pesadas.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(Espacio.l), this.color});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Etiqueta de estado: siempre ícono + texto, nunca sólo color.
class Etiqueta extends StatelessWidget {
  const Etiqueta({super.key, required this.texto, required this.color, required this.fondo, this.icono, this.compacta = false});

  final String texto;
  final Color color;
  final Color fondo;
  final IconData? icono;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compacta ? 6 : 8, vertical: compacta ? 2 : 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(Radios.s)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: compacta ? 13 : 15, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: context.textos.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: compacta ? 11 : 12),
          ),
        ],
      ),
    );
  }
}

/// Avatar con iniciales.
class Iniciales extends StatelessWidget {
  const Iniciales(this.texto, {super.key, this.radio = 20});
  final String texto;
  final double radio;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radio,
      backgroundColor: context.esquema.primary.withValues(alpha: 0.12),
      foregroundColor: context.esquema.primary,
      child: Text(texto, style: TextStyle(fontWeight: FontWeight.w700, fontSize: radio * 0.7)),
    );
  }
}

/// Ícono dentro de un cuadrado redondeado de color suave.
class IconoTile extends StatelessWidget {
  const IconoTile(this.icono, {super.key, this.color, this.fondo, this.tamanio = 40});
  final IconData icono;
  final Color? color;
  final Color? fondo;
  final double tamanio;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.esquema.primary;
    return Container(
      width: tamanio,
      height: tamanio,
      decoration: BoxDecoration(
        color: fondo ?? c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radios.m),
      ),
      child: Icon(icono, color: c, size: tamanio * 0.5),
    );
  }
}

class EstadoVacio extends StatelessWidget {
  const EstadoVacio({super.key, required this.icono, required this.titulo, this.mensaje, this.accion});

  final IconData icono;
  final String titulo;
  final String? mensaje;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Espacio.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconoTile(icono, tamanio: 64, color: context.esquema.primary),
              const SizedBox(height: Espacio.l),
              Text(titulo, style: context.textos.titleMedium, textAlign: TextAlign.center),
              if (mensaje != null) ...[
                const SizedBox(height: Espacio.s),
                Text(
                  mensaje!,
                  textAlign: TextAlign.center,
                  style: context.textos.bodyMedium?.copyWith(color: context.esquema.onSurfaceVariant, height: 1.45),
                ),
              ],
              if (accion != null) ...[const SizedBox(height: Espacio.xl), accion!],
            ],
          ),
        ),
      ),
    );
  }
}

class EstadoError extends StatelessWidget {
  const EstadoError({super.key, this.error, this.onReintentar});
  final Object? error;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    final texto = error.toString();
    final esIndice = texto.contains('index');
    return EstadoVacio(
      icono: Icons.cloud_off_rounded,
      titulo: 'No pudimos cargar la información',
      mensaje: esIndice
          ? 'La base de datos se está preparando. Probá de nuevo en unos minutos.'
          : 'Revisá tu conexión a internet e intentá nuevamente.',
      accion: onReintentar == null
          ? null
          : OutlinedButton.icon(onPressed: onReintentar, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
    );
  }
}

class Cargando extends StatelessWidget {
  const Cargando({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(padding: EdgeInsets.all(Espacio.xl), child: CircularProgressIndicator(strokeWidth: 3)),
      );
}

/// Encabezado de sección dentro de una página.
class Seccion extends StatelessWidget {
  const Seccion(this.titulo, {super.key, this.accion, this.padding = const EdgeInsets.fromLTRB(0, Espacio.xl, 0, Espacio.m)});
  final String titulo;
  final Widget? accion;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Text(titulo, style: context.textos.titleMedium)),
          if (accion != null) accion!,
        ],
      ),
    );
  }
}

/// Indicador numérico (stat tile). El valor va en color de texto; el
/// color sólo identifica al ícono.
class Indicador extends StatelessWidget {
  const Indicador({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.icono,
    this.color,
    this.detalle,
    this.onTap,
  });

  final String etiqueta;
  final String valor;
  final IconData icono;
  final Color? color;
  final String? detalle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconoTile(icono, color: color, tamanio: 34),
              const SizedBox(width: Espacio.m),
              Expanded(
                child: Text(
                  etiqueta,
                  style: context.textos.bodyMedium?.copyWith(color: context.esquema.onSurfaceVariant, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onTap != null) Icon(Icons.chevron_right_rounded, size: 20, color: context.esquema.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: Espacio.m),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valor, style: context.textos.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          ),
          if (detalle != null) ...[
            const SizedBox(height: 2),
            Text(
              detalle!,
              style: context.textos.bodySmall?.copyWith(color: context.esquema.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Grilla adaptable: 1 columna en celular, más columnas según el ancho.
class GrillaAdaptable extends StatelessWidget {
  const GrillaAdaptable({super.key, required this.children, this.anchoMinimo = 220, this.espacio = Espacio.m});
  final List<Widget> children;
  final double anchoMinimo;
  final double espacio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final columnas = (c.maxWidth / anchoMinimo).floor().clamp(1, children.length.clamp(1, 4));
      final ancho = (c.maxWidth - espacio * (columnas - 1)) / columnas;
      return Wrap(
        spacing: espacio,
        runSpacing: espacio,
        children: [for (final w in children) SizedBox(width: ancho, child: w)],
      );
    });
  }
}

/// Limita el ancho del contenido y lo centra en pantallas grandes.
class ContenidoCentrado extends StatelessWidget {
  const ContenidoCentrado({super.key, required this.child, this.anchoMaximo = kAnchoMaximoContenido});
  final Widget child;
  final double anchoMaximo;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: anchoMaximo), child: child),
      );
}

/// Fila "etiqueta ........ valor" para detalles y totales.
class FilaDato extends StatelessWidget {
  const FilaDato(this.etiqueta, this.valor, {super.key, this.destacado = false, this.colorValor});
  final String etiqueta;
  final String valor;
  final bool destacado;
  final Color? colorValor;

  @override
  Widget build(BuildContext context) {
    final estilo = destacado ? context.textos.titleMedium : context.textos.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(etiqueta, style: estilo?.copyWith(color: destacado ? null : context.esquema.onSurfaceVariant)),
          ),
          Text(valor, style: estilo?.copyWith(fontWeight: FontWeight.w700, color: colorValor)),
        ],
      ),
    );
  }
}

/// Distintivo "PRO" para funciones del plan pago.
class DistintivoPro extends StatelessWidget {
  const DistintivoPro({super.key});

  @override
  Widget build(BuildContext context) => Etiqueta(
        texto: 'PRO',
        color: context.colores.pro,
        fondo: context.colores.proSuave,
        icono: Icons.workspace_premium_rounded,
        compacta: true,
      );
}
