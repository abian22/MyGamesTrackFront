import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  // Registrar usuario
  Future<User?> registerUser({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      // Crear usuario en Firebase Authentication
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      User? user = userCredential.user;

      if (user != null) {
        // Guardar datos adicionales en Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'username': username,
          'email': email,
          'createdAt': DateTime.now(),
        });
      }

      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Intentar iniciar sesión si ya existe
        try {
          UserCredential loginCredential = await _auth
              .signInWithEmailAndPassword(email: email, password: password);
          User? existingUser = loginCredential.user;
          if (existingUser != null) {
            // Actualizar datos en Firestore
            await _firestore.collection('users').doc(existingUser.uid).set({
              'uid': existingUser.uid,
              'username': username,
              'email': email,
              'updatedAt': DateTime.now(),
            }, SetOptions(merge: true)); 
            return existingUser;
          }
        } catch (loginError) {
          throw 'El email ya está registrado, pero la contraseña es incorrecta.';
        }
      }
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Error al registrarse: $e';
    }
  }

  // Iniciar sesión con Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw 'Inicio de sesión cancelado';

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      User? user = userCredential.user;

      if (user != null) {
        // Guardar o actualizar datos en Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'username': user.displayName ?? 'Usuario Google',
          'email': user.email,
          'photoURL': user.photoURL,
          'createdAt': DateTime.now(),
        }, SetOptions(merge: true));
      }

      return user;
    } catch (e) {
      throw 'Error al iniciar sesión con Google: $e';
    }
  }

  // Iniciar sesión
  Future<User?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Error al iniciar sesión: $e';
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Obtener usuario actual
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Stream de autenticación
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  // Manejar excepciones de autenticación
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'La contraseña es muy débil';
      case 'email-already-in-use':
        return 'El email ya está registrado';
      case 'invalid-email':
        return 'El email no es válido';
      case 'user-not-found':
        return 'Usuario no encontrado';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      default:
        return 'Error de autenticación: ${e.message}';
    }
  }
}
