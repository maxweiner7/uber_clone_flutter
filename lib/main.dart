import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'Rotas.dart';
import 'telas/Home.dart';

final ThemeData temaPadrao = ThemeData(
  primaryColor: Color(0xff37474f),
  accentColor: Color(0xff546e7a),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Uber',
      debugShowCheckedModeBanner: false,
      home: Home(),
      initialRoute: "/",
      onGenerateRoute: Rotas.gerarRotas,
      theme: temaPadrao,
    );
  }
}