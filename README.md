# 🛠️ WorkControl  - Gestión de Taller en Tiempo Real

> **Solución integral multiplataforma para la administración de reparaciones, generacion de talonarios y presupuestos y gestion de finanzas, potenciada por la infraestructura en la nube de Firebase.**

![Project Status](https://img.shields.io/badge/Status-Completed-brightgreen)
![Tech Stack](https://img.shields.io/badge/Stack-Flutter%20%7C%20Dart%20%7C%20Firebase-orange)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-blue)

## 📖 El Problema:
Muchos talleres mecánicos aún dependen de procesos manuales, planillas de papel o software local que no permite el seguimiento remoto. Los problemas comunes incluyen:
1. **Falta de Trazabilidad:** Dificultad para que el administrador sepa en qué etapa de reparación está cada maquina/vehiculo.
2. **Pérdida de Historial:** Dificultad para acceder rápidamente a lo que se le hizo a un vehículo meses atrás.

## 🚀 La Solución (Architecture)
**WorkControl** ofrece una experiencia fluida tanto para el mecánico como para el dueño del taller, utilizando **Flutter** para una interfaz reactiva y **Firebase** para la persistencia de datos y sincronización en tiempo real.

### Principales Características:
* **Dashboard en Tiempo Real:** Visualización instantánea del estado de las maquinas/vehiculos (En espera, En reparación, Listo).
* **Gestión de Clientes y maquinarias:** Registro detallado con especificaciones técnicas.
* **Seguridad:** Autenticación robusta y reglas de seguridad granulares en la base de datos.

## 🛠️ Stack Tecnológico

| Componente | Tecnología | Razón de la elección |
|------------|------------|-----------------------|
| **Frontend** | **Flutter** | Desarrollo único para Android, iOS y Web con alto rendimiento nativo. |
| **Lenguaje** | **Dart** | Tipado fuerte y excelente manejo de flujos asíncronos para UI reactiva. |
| **Base de Datos**| **Cloud Firestore** | Base de Datos NoSQL que permite sincronización en tiempo real (Offline-first). |
| **Autenticación**| **Firebase Auth** | Manejo seguro de sesiones y perfiles de usuario. |

## ⚡ Cómo correr el proyecto

### Prerrequisitos
* **Flutter SDK** (Versión estable más reciente)
* **Dart SDK**
* Un editor (VS Code o Android Studio)
* Una cuenta en **Firebase Console**

### Instalación y Configuración
1. **Clonar el repositorio**
   ```bash
   git clone 
   cd taller-mecanico
   ```

2. **Instalar dependencias**
   ```bash
   flutter pub get
   ```

3. **Configurar Firebase**
   * Crea un proyecto en [Firebase Console](https://console.firebase.google.com/).
   * Habilita **Authentication** (Email/Password) y **Cloud Firestore**.
   * Descarga el archivo `google-services.json` (para Android) y `GoogleService-Info.plist` (para iOS).
   * Coloca los archivos en sus carpetas correspondientes:
     * Android: `android/app/`
     * iOS: `ios/Runner/`

4. **Ejecutar la App**
   ```bash
   flutter run
   ```

## 🏗️ Estructura de Datos (Firestore)
El proyecto utiliza una estructura de documentos optimizada para lectura rápida:
* `talleres/{tallerId}`: Información del establecimiento.
* `talleres/{tallerId}/vehiculos/{vehiculoId}`: Historial y especificaciones.
* `talleres/{tallerId}/ordenes/{ordenId}`: Estados de reparación, costos y repuestos usados.

## 📸 Screenshots

### Dashboard Principal
<img width="1200" height="675" alt="Dashboard Taller" src="https://github.com/user-attachments/assets/tu-id-imagen-1" />

### Vista de Órdenes y Detalles
<img width="500" height="300" alt="Detalle Reparacion" src="https://github.com/user-attachments/assets/tu-id-imagen-2" /> <img width="500" height="300" alt="Inventario" src="https://github.com/user-attachments/assets/tu-id-imagen-3" />

---

Desarrollado por [Santiago Iturralde](https://github.com/santiago-iturralde) 🛠️🏁
