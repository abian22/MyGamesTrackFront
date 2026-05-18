import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants.dart';
import '../services/auth_service.dart';
import '../widgets/switch_app_bar.dart';
import 'login_screen.dart';

/// Perfil: datos del usuario de Firebase y botón para cerrar sesión.
class ProfileScreen extends StatelessWidget {
  final AuthService authService;
  const ProfileScreen({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: kBgDark,
      appBar: const SwitchAppBar(title: 'Perfil'),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _profileAvatar(user),
            const SizedBox(height: 16),
            Text(
              user?.displayName ?? 'Usuario',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user?.email ?? '',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _signOutAndGoToLogin(context, authService),
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  'Cerrar sesión',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSwitchRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Foto del proveedor de login si hay URL; si no, un círculo con la inicial.
Widget _profileAvatar(User? user) {
  final photoUrl = user?.photoURL;
  final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

  if (hasPhoto) {
    return CircleAvatar(
      radius: 50,
      backgroundColor: kSwitchRed,
      backgroundImage: NetworkImage(photoUrl),
    );
  }

  return CircleAvatar(
    radius: 50,
    backgroundColor: kSwitchRed,
    child: Text(
      _initialLetter(user),
      style: const TextStyle(
        fontSize: 36,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

/// Primera letra del nombre o del email; si no hay texto útil, "U".
String _initialLetter(User? user) {
  final name = user?.displayName?.trim();
  if (name != null && name.isNotEmpty) {
    return name[0].toUpperCase();
  }
  final email = user?.email?.trim();
  if (email != null && email.isNotEmpty) {
    return email[0].toUpperCase();
  }
  return 'U';
}

/// Cierra sesión con el servicio compartido y sustituye la ruta por el login.
Future<void> _signOutAndGoToLogin(BuildContext context, AuthService auth) async {
  await auth.signOut();
  if (!context.mounted) return;
  Navigator.pushReplacement(
    context,
    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
  );
}
