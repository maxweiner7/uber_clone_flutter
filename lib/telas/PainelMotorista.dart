import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uber/util/StatusRequisicao.dart';
import 'package:uber/util/UsuarioFirebase.dart';

class PainelMotorista extends StatefulWidget {
  @override
  _PainelMotoristaState createState() => _PainelMotoristaState();
}

class _PainelMotoristaState extends State<PainelMotorista> {
  List<String> itemsMenu = ["Configurações", "Deslogar"];

  final _controller = StreamController<QuerySnapshot>.broadcast();
  FirebaseFirestore db = FirebaseFirestore.instance;

  _deslogarUsuario() async {
    FirebaseAuth auth = FirebaseAuth.instance;

    await auth.signOut();
    Navigator.pushReplacementNamed(context, "/");
  }

  _escolhaMenuItem(String escolha) {
    switch (escolha) {
      case "Deslogar":
        _deslogarUsuario();
        break;
      case "Configurações":
        break;
    }
  }

  Stream<QuerySnapshot> _adicionarListenerRequisicoes() {
    final stream = db
        .collection("requisicoes")
        .where("status", isEqualTo: StatusRequisicao.AGUARDANDO)
        .snapshots();

    stream.listen((dados) {
      _controller.add(dados);
    });
  }
  _recuperarRequisicaoAtivaMotorista () async {

    //recupera dados do usuario logado
    User firebaseUser = await UsuarioFirebase.getUsuarioAtual();
    
    //recupera requisicao ativa
    DocumentSnapshot documentSnapshot = await db
        .collection("requisicao_ativa_motorista")
    .doc( firebaseUser.uid ).get();

    var dadosRequisicao = documentSnapshot.data();

    if ( dadosRequisicao == null ) {
      _adicionarListenerRequisicoes();
    }else {

      String idRequisicao = dadosRequisicao["id_requisicao"];
      Navigator.pushReplacementNamed(context, "/corrida",
          arguments: idRequisicao);
    }
  }

  @override
  void initState() {
    super.initState();
  /* Recuperar requisicao ativa para verificar se motorista
     está atendendo alguma requisição e envia ele para tela de corrida*/

    _recuperarRequisicaoAtivaMotorista();

  }

  @override
  Widget build(BuildContext context) {
    var mensagemCarregando = Center(
      child: Column(
        children: [Text("Carregando requisições"), CircularProgressIndicator()],
      ),
    );

    var mensagemNaoTemDados = Center(
        child: Text(
      "Voce ainda não tem requisições",
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ));

    return Scaffold(
      appBar: AppBar(
        title: Text("Painel motorista"),
        actions: [
          PopupMenuButton<String>(
            onSelected: _escolhaMenuItem,
            itemBuilder: (context) {
              return itemsMenu.map((String item) {
                return PopupMenuItem<String>(
                  child: Text(item),
                  value: item,
                );
              }).toList();
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _controller.stream,
        builder: (context, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
            case ConnectionState.waiting:
              return mensagemCarregando;
              break;
            case ConnectionState.active:
            case ConnectionState.done:
              if (snapshot.hasError) {
                return Text("Erro ao carregar os dados");
              } else {
                QuerySnapshot querySnapshot = snapshot.data;
                if (querySnapshot.docs.length == 0) {
                  return mensagemNaoTemDados;
                } else {
                  return ListView.separated(
                      itemBuilder: (context, indice) {
                        List<DocumentSnapshot> requisicoes =
                            querySnapshot.docs.toList();
                        DocumentSnapshot item = requisicoes[indice];

                        String idRequisicao = item["id"];
                        String nomePassageiro = item["passageiro"]["nome"];
                        String rua = item["destino"]["rua"];
                        String numero = item["destino"]["numero"];
                        String cidade = item["destino"]["cidade"];

                        return ListTile(
                          title: Text(nomePassageiro),
                          subtitle: Text("Destino: $rua, $numero \n$cidade"),
                          onTap: () {
                            Navigator.pushNamed(context, "/corrida",
                                arguments: idRequisicao);
                          },
                        );
                      },
                      separatorBuilder: (context, indice) => Divider(
                            height: 2,
                            color: Colors.grey,
                          ),
                      itemCount: querySnapshot.docs.length);
                }
              }

              break;
          }
        },
      ),
    );
  }
}
