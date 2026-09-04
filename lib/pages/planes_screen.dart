import 'package:flutter/material.dart';
import '../theme.dart'; // Importamos el tema para mantener la identidad visual

class PlanesScreen extends StatelessWidget {
  const PlanesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Planes y Suscripción"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          children: [
            // Cabecera ilustrativa
            Icon(Icons.rocket_launch_rounded, size: 60, color: AppTheme.primaryBlue.withOpacity(0.8)),
            const SizedBox(height: 16),
            const Text(
              "Elige el plan ideal\npara tu taller",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.primaryBlue, height: 1.2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Desbloqueá todo el potencial de tu negocio",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // --- TARJETA PLAN GRATIS ---
            _buildPlanCard(
              context,
              title: "PLAN INICIAL",
              price: "GRATIS",
              features: [
                "Gestión de Clientes ilimitada",
                "Registro de Reparaciones",
                "Presupuestos en PDF",
                "Control de Egresos",
              ],
              color: Colors.grey.shade400,
              headerColor: AppTheme.primaryBlue,
              isCurrent: true,
              buttonText: "Plan Actual",
              onTap: () {},
            ),

            const SizedBox(height: 24),

            // --- TARJETA PLAN PREMIUM ---
            _buildPlanCard(
              context,
              title: "PLAN PREMIUM",
              price: "\$5.000",
              period: "/ mes",
              features: [
                "Todo lo del Plan Inicial",
                "Generación de Recibos (Talonarios)",
                "Reportes y Estadísticas Avanzadas",
                "Soporte Prioritario",
                "Copia de seguridad en la nube",
              ],
              color: Colors.amber.shade600,
              headerColor: Colors.amber.shade800,
              isPremium: true,
              buttonText: "CONTRATAR AHORA",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("🚀 La pasarela de pagos estará disponible próximamente."),
                    backgroundColor: AppTheme.primaryBlue,
                    duration: Duration(seconds: 3),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),
            Text(
              "Próximamente podrás gestionar tu suscripción directamente desde aquí.",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(
      BuildContext context, {
        required String title,
        required String price,
        String period = "",
        required List<String> features,
        required Color color,
        required Color headerColor,
        required String buttonText,
        required VoidCallback onTap,
        bool isCurrent = false,
        bool isPremium = false,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPremium ? color : Colors.grey.shade300,
          width: isPremium ? 2.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPremium ? color.withOpacity(0.2) : Colors.black.withOpacity(0.05),
            blurRadius: isPremium ? 20 : 10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Recomendado (Solo Premium)
          if (isPremium)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.workspace_premium, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    "MÁS ELEGIDO",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: headerColor, letterSpacing: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      price,
                      style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: isPremium ? Colors.black87 : AppTheme.primaryBlue),
                    ),
                    if (period.isNotEmpty)
                      Text(
                        period,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 24),

                // Lista de características
                ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isPremium ? Icons.check_circle : Icons.check_circle_outline,
                        size: 20,
                        color: isPremium ? Colors.green.shade600 : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          f,
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontWeight: isPremium ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),

                const SizedBox(height: 8),

                // Botón
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isCurrent ? null : onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPremium ? color : Colors.grey.shade200,
                      foregroundColor: isPremium ? Colors.white : Colors.grey.shade600,
                      elevation: isPremium ? 4 : 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      buttonText,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isPremium ? Colors.white : Colors.grey.shade600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}