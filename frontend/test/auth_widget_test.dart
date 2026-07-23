import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/auth/presentation/register_screen.dart';
import 'package:frontend/features/auth/domain/bloc/auth_bloc.dart';
import 'package:frontend/features/auth/domain/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  testWidgets('RegisterScreen renders text fields and button', (WidgetTester tester) async {
    final mockDio = Dio();
    final mockStorage = FlutterSecureStorage();
    final authRepo = AuthRepository(dio: mockDio, storage: mockStorage);
    
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => AuthBloc(authRepository: authRepo),
          child: RegisterScreen(),
        ),
      ),
    );

    // Verify presence of text fields
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Verify presence of register button
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
  });
}
