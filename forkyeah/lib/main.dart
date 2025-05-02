import 'package:flutter/material.dart';
void main() {
  runApp(MaterialApp(
    home: LoginPage(),
  ));
}

class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('登入')),
      body: Center(child: Text('這裡是登入畫面')),
    );
  }
}
