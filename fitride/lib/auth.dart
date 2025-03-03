import 'package:firebase_auth/firebase_auth.dart';

class Auth {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Add this method to initialize persistence
  Future<void> initAuth() async {
    // Set persistence to LOCAL which will maintain the user session
    await _firebaseAuth.setPersistence(Persistence.LOCAL);
  }

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    // Set persistence before signing in
    await initAuth();
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    // Set persistence before creating user
    await initAuth();
    await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
  
  // Add a method to check if user is already authenticated
  bool isUserLoggedIn() {
    return currentUser != null;
  }
}