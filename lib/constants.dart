import 'package:flutter/material.dart';

/// OAuth 2.0 client ID tipo **Web** (Firebase Console → Ajustes del proyecto →
/// Tus aplicaciones → SDK de configuración / `google-services.json` → `client_type`: 3).
/// Necesario en Android para que `GoogleSignIn` devuelva `idToken` y funcione Firebase Auth.
const kGoogleWebClientId =
    '21876434470-mkruhih1fkaslbpjdqje4dpqum563b5r.apps.googleusercontent.com';

/// Icono de marca (launcher y UI).
const kAppIconAsset = 'assets/branding/app_icon.png';

const kSwitchRed = Color(0xFFE4000F);
const kSwitchBlue = Color(0xFF0AB9E6);
const kBgDark = Color(0xFF1A1A1A);
const kCardDark = Color(0xFF2A2A2A);
const kBarDark = Color(0xFF111111);
const white = Color.fromARGB(255, 255, 255, 255);
