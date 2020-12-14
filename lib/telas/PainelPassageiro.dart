import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:io';
import 'package:geocoding/geocoding.dart';
import 'package:uber/model/Destino.dart';
import 'package:uber/model/Requisicao.dart';
import 'package:uber/model/Usuario.dart';
import 'package:uber/util/StatusRequisicao.dart';
import 'package:uber/util/UsuarioFirebase.dart';

class PainelPassageiro extends StatefulWidget {
  @override
  _PainelPassageiroState createState() => _PainelPassageiroState();
}

class _PainelPassageiroState extends State<PainelPassageiro> {
  Completer<GoogleMapController> _controller = Completer();
  List<String> itemsMenu = ["Configurações", "Deslogar"];
  CameraPosition _posicaoCamera =
  CameraPosition(target: LatLng(38.70363978979417, -9.400388462337878));
  Set<Marker> _marcadores = {};
  TextEditingController _controllerDestino =
  TextEditingController(text: "Av. joao naves de avila, 1331");


  //Controles para exibição na tela
  bool _exibirCaixaEnderecoDestino = true;
  String _textBotao = "Chamar Uber";
  Color _corBotao = Colors.lightBlue;
  Function _funcaoBotao;
  String _idRequisicao;
  Position _localPassageiro;
  Map<String, dynamic> _dadosRequisicao;

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

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  _adicionaListenerLocalizacao() {
    var geolocator = Geolocator.getPositionStream(
        desiredAccuracy: LocationAccuracy.high, distanceFilter: 10)
        .listen((Position position) {

          if ( _idRequisicao != null && _idRequisicao.isNotEmpty ) {

            //Atualiza local do passageiro
            UsuarioFirebase.atualizarDadosLocalizacao(
                _idRequisicao,
                position.latitude,
                position.longitude
            );

          } else if ( position != null) {
            setState(() {
              _localPassageiro = position;
            });
          }


    });
  }

  _recuperaUltimaLocalizacaoConhecida() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      if (position != null) {
        // _exibirMarcadorPassageiro( position );


      }
    });
  }

  _movimentarCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  _exibirMarcadorPassageiro(Position local) async {
    double pixelRatio = MediaQuery
        .of(context)
        .devicePixelRatio;
    print("pixelRatio tamanho: " + pixelRatio.toString());

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        "assets/user.png")
        .then((BitmapDescriptor icone) {
      Marker marcadorPassageiro = Marker(
        markerId: MarkerId("marcador-passageiro"),
        position: LatLng(local.latitude, local.longitude),
        infoWindow: InfoWindow(title: "Meu local"),
        icon: icone,
      );
      setState(() {
        _marcadores.add(marcadorPassageiro);
      });
    });
  }

  _chamarUber() async {
    String endercoDestino = _controllerDestino.text;

    if (_controllerDestino.text.isNotEmpty) {
      List<Location> latLong = await locationFromAddress(endercoDestino);

      if (latLong != null && latLong.length > 0) {
        Location latLog = latLong[0];
        Destino destino = Destino();

        destino.latitude = latLog.latitude;
        destino.longitude = latLog.longitude;

        List<Placemark> enderecos =
        await placemarkFromCoordinates(latLog.latitude, latLog.longitude);
        Placemark endereco = enderecos[0];

        destino.cidade = endereco.subAdministrativeArea;
        destino.cep = endereco.postalCode;
        destino.bairro = endereco.subLocality;
        destino.rua = endereco.thoroughfare;
        destino.numero = endereco.subThoroughfare;

        String enderecoConfirmacao = "Cidade: " + destino.cidade;
        enderecoConfirmacao += "\nRua: " + destino.rua + ", " + destino.numero;
        enderecoConfirmacao += "\nBairro: " + destino.bairro;
        enderecoConfirmacao += "\nCep: " + destino.cep;

        showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text("Confirmação do endereço"),
                content: Text(
                  enderecoConfirmacao,
                  style: TextStyle(fontSize: 20, color: Colors.black54),
                ),
                contentPadding: EdgeInsets.all(16),
                actions: [
                  FlatButton(
                    child: Text(
                      "Cancelar",
                      style: TextStyle(color: Colors.red),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  FlatButton(
                    child: Text(
                      "Confirmar",
                      style: TextStyle(color: Colors.green),
                    ),
                    onPressed: () {
                      //salvar requisicao
                      _salvarRequisicao(destino);
                      Navigator.pop(context);
                    },
                  ),
                ],
              );
            });
      }
    }
  }

  _salvarRequisicao(Destino destino) async {
    Requisicao requisicao = Requisicao();

    Usuario passageiro = await UsuarioFirebase.getDadosUsuarioLogado();
    passageiro.latitude = _localPassageiro.latitude;
    passageiro.longitude = _localPassageiro.longitude;

    requisicao.destino = destino;
    requisicao.passageiro = passageiro;
    requisicao.status = StatusRequisicao.AGUARDANDO;

    FirebaseFirestore db = FirebaseFirestore.instance;

    db.collection("requisicoes").doc(requisicao.id)
        .set(requisicao.toMap());

    //salvar requisição ativa
    Map<String, dynamic> dadosRequisicaoAtiva = {};
    dadosRequisicaoAtiva["id_requisicao"] = requisicao.id;
    dadosRequisicaoAtiva["id_usuario"] = passageiro.idUsuario;
    dadosRequisicaoAtiva["status"] = StatusRequisicao.AGUARDANDO;

    db.collection("requisicao_ativa")
        .doc(passageiro.idUsuario)
        .set(dadosRequisicaoAtiva);

    //chama método para alterar interface para o status aguardando
    statusAguardando();

  }


  _alterarBotaoPrincipal(String texto, Color cor, Function funcao) {
    setState(() {
      _textBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });
  }

  _statusUberNaoChamado() {
    _exibirCaixaEnderecoDestino = true;
    _alterarBotaoPrincipal("Chamar Uber", Colors.lightBlue, () {
      _chamarUber();
    });

    Position position = Position(latitude: _localPassageiro.latitude,
        longitude: _localPassageiro.longitude);
    _exibirMarcadorPassageiro(position);

    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 19);
    _movimentarCamera(cameraPosition);
  }

  statusAguardando() {
    _exibirCaixaEnderecoDestino = false;
    _alterarBotaoPrincipal("Cancelar", Colors.redAccent[400], () {
      _cancelarUber();
    });

    double passageiroLat = _dadosRequisicao["passageiro"]["latitude"];
    double passageiroLon = _dadosRequisicao["passageiro"]["longitude"];
    Position position = Position(
        latitude: passageiroLat,
        longitude: passageiroLon);

    _exibirMarcadorPassageiro(position);

    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 19);
    _movimentarCamera(cameraPosition);
  }

  _statusACaminho() {
    _exibirCaixaEnderecoDestino = false;
    _alterarBotaoPrincipal("Motorista a Caminho", Colors.grey[400], () {});
  }

  _cancelarUber() async {
    User firebaseUser = await UsuarioFirebase.getUsuarioAtual();
    FirebaseFirestore db = FirebaseFirestore.instance;
    db.collection("requisicoes")
        .doc(_idRequisicao)
        .update({
      "status": StatusRequisicao.CANCELADA
    }).then((_) =>
        db.collection("requisicao_ativa").doc(firebaseUser.uid).delete());
  }

  _recuperarRequisicaoAtiva() async {
    User firebaseUser = await UsuarioFirebase.getUsuarioAtual();

    FirebaseFirestore db = FirebaseFirestore.instance;

    DocumentSnapshot documentSnapshot = await db.collection("requisicao_ativa")
        .doc(firebaseUser.uid)
        .get();

    if (documentSnapshot.data() != null) {
      Map<String, dynamic> dados = documentSnapshot.data();
      _idRequisicao = dados["id_requisicao"];
      _adicionarListenerRequisicao( _idRequisicao );
    }else {
      _statusUberNaoChamado();
    }
  }

  _adicionarListenerRequisicao(String idRequisicao) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    await db
        .collection("requisicoes")
        .doc(idRequisicao).snapshots().listen((snapshot) {

      if (snapshot.data() != null) {

        Map<String, dynamic> dados = snapshot.data();
        _dadosRequisicao = dados;
        String status = dados["status"];
        _idRequisicao = dados["id_requisicao"];

        switch (status) {
          case StatusRequisicao.AGUARDANDO :
            statusAguardando();
            break;
          case StatusRequisicao.A_CAMINHO :
            _statusACaminho();
            break;
          case StatusRequisicao.VIAGEM :
            break;
          case StatusRequisicao.FINALIZADA :
            break;
        }
      } else {
        _statusUberNaoChamado();
      }
    });

  }

  @override
  void initState() {
    super.initState();

    _recuperarRequisicaoAtiva();

    //_recuperaUltimaLocalizacaoConhecida();
    _adicionaListenerLocalizacao();

    //adicionar listener para requisicão ativa


  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel passageiro"),
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
      body: Container(
        child: Stack(
          children: [
            GoogleMap(
              onMapCreated: _onMapCreated,
              mapType: MapType.normal,
              initialCameraPosition: _posicaoCamera,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              markers: _marcadores,
              zoomControlsEnabled: false,
            ),
            Visibility(
              visible: _exibirCaixaEnderecoDestino,
              child: Stack(
                children: [
                  Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Container(
                          height: 50,
                          width: double.infinity,
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.black26),
                              borderRadius: BorderRadius.circular(3),
                              color: Colors.white),
                          child: TextField(
                            readOnly: true,
                            decoration: InputDecoration(
                                icon: Container(
                                  margin: EdgeInsets.only(left: 20),
                                  child: Icon(
                                    Icons.location_on,
                                    color: Colors.green,
                                  ),
                                ),
                                hintText: "Meu local",
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(left: 15)),
                          ),
                        ),
                      )),
                  Positioned(
                      top: 55,
                      left: 0,
                      right: 0,
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Container(
                          height: 50,
                          width: double.infinity,
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.black26),
                              borderRadius: BorderRadius.circular(3),
                              color: Colors.white),
                          child: TextField(
                            decoration: InputDecoration(
                              icon: Container(
                                margin: EdgeInsets.only(left: 20),
                                child: Icon(
                                  Icons.local_taxi,
                                  color: Colors.black,
                                ),
                              ),
                              hintText: "Digite o destino",
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.only(left: 15),
                            ),
                            controller: _controllerDestino,
                          ),
                        ),
                      ))
                ],
              ),
            ),
            Positioned(
              right: 0,
              left: 0,
              bottom: 0,
              child: Padding(
                padding: Platform.isIOS
                    ? EdgeInsets.fromLTRB(20, 10, 20, 25)
                    : EdgeInsets.all(10),
                child: RaisedButton(
                  splashColor: Colors.black54,
                  color: _corBotao,
                  child: Text(
                    _textBotao,
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                  padding: EdgeInsets.fromLTRB(32, 16, 32, 18),
                  onPressed: _funcaoBotao,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
