import 'package:flutter/material.dart';

class PlanesScreen extends StatelessWidget {
  const PlanesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Planes y Suscripción"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Elige el plan ideal para tu taller",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

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
              color: Colors.blueGrey,
              isCurrent: true, // Visualmente marcado como actual
              buttonText: "Plan Actual",
              onTap: () {},
            ),

            const SizedBox(height: 20),

            // --- TARJETA PLAN PREMIUM ---
            _buildPlanCard(
              context,
              title: "PLAN PREMIUM",
              price: "\$5.000 / mes",
              features: [
                "Todo lo del Plan Inicial",
                "✅ Generación de Recibos (Talonarios)",
                "✅ Reportes y Estadísticas Avanzadas",
                "✅ Soporte Prioritario",
                "✅ Copia de seguridad en la nube",
              ],
              color: Colors.amber.shade700,
              isPremium: true,
              buttonText: "CONTRATAR AHORA",
              // SOLO AVISO VISUAL
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("La pasarela de pagos estará disponible próximamente."),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),

            const SizedBox(height: 30),
            const Text(
              "Próximamente podrás gestionar tu suscripción directamente desde aquí.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(
      BuildContext context, {
        required String title,
        required String price,
        required List<String> features,
        required Color color,
        required String buttonText,
        required VoidCallback onTap,
        bool isCurrent = false,
        bool isPremium = false,
      }) {
    return Card(
      elevation: isPremium ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPremium ? BorderSide(color: color, width: 2) : BorderSide.none,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isPremium)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "RECOMENDADO",
                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              price,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ...features.map((f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: isPremium ? Colors.green : Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(child: Text(f)),
                ],
              ),
            )),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isCurrent ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: isPremium ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}