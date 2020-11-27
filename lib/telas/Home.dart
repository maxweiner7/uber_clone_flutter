import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:uber/model/Usuario.dart';
import 'package:uber/telas/Cadastro.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  TextEditingController _controllerEmail =
      TextEditingController(text: "max@gmail.com");
  TextEditingController _controllerSenha =
      TextEditingController(text: "1234567");
  String _mensagemErro = "";
  bool _carregando = false;
  FirebaseAuth auth = FirebaseAuth.instance;

  _abrirTelaCadastro() {
    Navigator.pushNamed(context, "/cadastro");
  }

  _validarCampos() {
    //Recuperar dados dos campos
    String email = _controllerEmail.text;
    String senha = _controllerSenha.text;

    //Valivar campos
    if (email.isNotEmpty && email.contains("@")) {
      if (senha.isNotEmpty && senha.length > 6) {
        Usuario usuario = Usuario();
        usuario.email = email;
        usuario.senha = senha;

        logarUsuario(usuario);
      } else {
        setState(() {
          _mensagemErro = "Preencha a senha! digite mais de 6 caracteres";
        });
      }
    } else {
      setState(() {
        _mensagemErro = "Insira um E-mail valido";
      });
    }
  }

  logarUsuario(Usuario usuario) {

    setState(() {
      _carregando = true;
    });
    auth
        .signInWithEmailAndPassword(
            email: usuario.email, password: usuario.senha)
        .then((FirebaseUser) {
      _redirecionaPainelPorTipoUsuario( FirebaseUser.user.uid );
    }).catchError((error) {
      _mensagemErro = "Erro ao autenticar usuario, verifique e-mail e senha!";
    });
  }

  _redirecionaPainelPorTipoUsuario(String idUsuario) async {
    FirebaseFirestore db = FirebaseFirestore.instance;

    DocumentSnapshot snapshot =
        await db.collection("usuarios").doc(idUsuario).get();

    Map<String, dynamic> dados = snapshot.data();
    String tipoUsuario = dados["tipoUsuario"];

    setState(() {
      _carregando = false;
    });

    switch ( tipoUsuario ) {
      case "motorista" :
        Navigator.pushReplacementNamed(context, "/painel-motorista");
        break;
      case "passageiro" :
        Navigator.pushReplacementNamed(context, "/painel-passageiro");
        break;
    }
  }
  _verificaUsuarioLogado() async {

    User usuarioLogado = await auth.currentUser;
    if( usuarioLogado != null ) {
      String idUsuario = usuarioLogado.uid;
      _redirecionaPainelPorTipoUsuario( idUsuario );
    }

  }
  @override
  void initState() {
    super.initState();
    _verificaUsuarioLogado();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
              image: DecorationImage(
            image: AssetImage("images/fundo.png"),
            fit: BoxFit.cover,
          )),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 32),
                    child:
                        Image.asset("images/logo.png", width: 200, height: 150),
                  ),
                  TextField(
                    controller: _controllerEmail,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(fontSize: 20),
                    decoration: InputDecoration(
                        contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                        hintText: "E-mail",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6))),
                  ),
                  TextField(
                    controller: _controllerSenha,
                    keyboardType: TextInputType.text,
                    obscureText: true,
                    style: TextStyle(fontSize: 20),
                    decoration: InputDecoration(
                        contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                        hintText: "Senha",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6))),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 16, bottom: 10),
                    child: RaisedButton(
                      splashColor: Colors.green,
                      color: Colors.lightBlue,
                      child: Text(
                        "Entrar",
                        style: TextStyle(fontSize: 20, color: Colors.white),
                      ),
                      padding: EdgeInsets.fromLTRB(32, 16, 32, 18),
                      onPressed: () {
                        _validarCampos();
                      },
                    ),
                  ),
                  Center(
                    child: GestureDetector(
                      child: Text(
                        "Não tem conta? cadastre-se!",
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        _abrirTelaCadastro();
                        print("Clicado em cadastrar");
                      },
                    ),
                  ),
                  Padding(padding: EdgeInsets.only(top: 16),
                  child: _carregando ? Center(child: CircularProgressIndicator(
                    backgroundColor: Colors.white ,),)
                      : Container(),),
                  Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(
                      child: Text(
                        _mensagemErro,
                        style: TextStyle(fontSize: 30, color: Colors.red),
                      ),
                    ),
                  )
                ],
              ),
            ),
          )),
    );
  }
}
