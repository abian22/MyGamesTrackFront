# MyGamesTrack (Frontend)

App móvil multiplataforma (**Flutter**) para seguir precios de la Nintendo eShop (España): explora el catálogo, guarda favoritos y consulta alertas cuando un juego rebaja.

Proyecto Final de Ciclo — **DAM**.

> El catálogo y las alertas se alimentan desde **Firebase** (Firestore + FCM). El scraping y la sincronización de precios los gestiona un **backend Node.js** en un repositorio aparte.

---

## Características

- Login con **Google** o **email/contraseña** (sesión persistente).
- **Catálogo** en cuadrícula con paginación (20 juegos por carga).
- **Búsqueda** por nombre con debounce (`tituloLower` en Firestore).
- **Favoritos** por usuario.
- **Alertas** de rebajas: historial en app, badge de no leídas y push FCM en segundo plano.

---

## Tecnologías

- Flutter / Dart
- Firebase Core, Auth, Firestore, Cloud Messaging
- `google_sign_in`

---

## Estructura

```
lib/
├── main.dart                 # Inicio y rutas según sesión
├── constants.dart            # Tema y OAuth Web Client ID (Android)
├── firebase_options.dart     # Generado con FlutterFire CLI
├── screens/
│   ├── login_screen.dart
│   ├── signup_screen.dart
│   ├── main_screen.dart      # Navegación inferior
│   ├── home_screen.dart      # Catálogo + búsqueda
│   ├── favorites_screen.dart
│   ├── notifications_screen.dart
│   └── profile_screen.dart
├── services/
│   ├── auth_service.dart
│   └── notification_service.dart
└── widgets/
    ├── game_card.dart
    └── switch_app_bar.dart
```

---

## Requisitos

- [Flutter](https://docs.flutter.dev/get-started/install) SDK `^3.10`
- Proyecto [Firebase](https://console.firebase.google.com/) con:
  - Authentication (Email/Password + Google)
  - Cloud Firestore
  - Cloud Messaging
- **Android:** `android/app/google-services.json`
- **iOS:** configuración Firebase en Xcode (`GoogleService-Info.plist`)
- Dispositivo físico recomendado para probar **notificaciones push**

---

## Configuración

### 1. Dependencias

```bash
flutter pub get
```

### 2. Firebase (FlutterFire)

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Genera `lib/firebase_options.dart` vinculado a tu proyecto Firebase.

### 3. Google Sign-In en Android

En `lib/constants.dart`, asigna `kGoogleWebClientId` con el **OAuth client ID tipo Web** de Firebase Console (o el `client_type: 3` de `google-services.json`). Sin esto, el login con Google en Android no devuelve `idToken`.

### 4. Firestore

La app espera estas colecciones (rellenadas por el backend):

| Colección | Campos relevantes para la app |
|-----------|-------------------------------|
| `games` | `titulo`, `tituloLower`, `precio`, `imagen`, `descuento` |
| `users` | `favorites` (array de IDs), `fcmTokens` |
| `notifications` | `uid`, `gameTitle`, `oldPrice`, `newPrice`, `leida`, `createdAt` |

**Reglas de Firestore:** no van en este repo; se configuran en [Firebase Console](https://console.firebase.google.com/) → Firestore → **Reglas**. Aunque solo desarrolles en local, la app ya usa Firestore en la nube. Revisa qué reglas tienes activas (a menudo modo prueba con lectura/escritura abierta durante X días). El backend Node usa Admin SDK y **no** está limitado por esas reglas; la app Flutter **sí**.

---

## Ejecución

```bash
flutter run
```

Plataformas soportadas en el proyecto: **Android**, **iOS** (y carpetas web/desktop según configuración Flutter).

```bash
# Iconos de launcher (opcional)
dart run flutter_launcher_icons
```

---

## Comportamiento de las notificaciones

- Al iniciar sesión, la app registra el **token FCM** en el documento del usuario (`fcmTokens`).
- Con la app en **segundo plano o cerrada**, el sistema muestra la push de FCM.
- Con la app en **primer plano**, la lista **Alertas** se actualiza en tiempo real vía Firestore (`StreamBuilder`); no se duplica con notificación local.

Las push las envía el backend cuando detecta una rebaja en un juego favorito.

---

## Pantallas

| Pestaña | Función |
|---------|---------|
| Catálogo | Listado, búsqueda, añadir/quitar favoritos |
| Favoritos | Solo juegos guardados |
| Alertas | Historial de rebajas, marcar leídas, eliminar |
| Perfil | Datos de usuario y cerrar sesión |

---

## Autor

**Abián Camejo Díaz** — Centro Internacional Politécnico · Mayo 2026

---

## Licencia

Proyecto académico. Consulta con el autor antes de uso comercial o redistribución.
