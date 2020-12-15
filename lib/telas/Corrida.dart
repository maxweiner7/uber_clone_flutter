import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uber/model/Usuario.dart';
import 'package:uber/util/StatusRequisicao.dart';
import 'package:uber/util/UsuarioFirebase.dart';

class Corrida extends StatefulWidget {
  String idRequisicao;

  Corrida(this.idRequisicao);

  @override
  _CorridaState createState() => _CorridaState();
}

class _CorridaState extends State<Corrida> {
  Completer<GoogleMapController> _controller = Completer();

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  Set<Marker> _marcadores = {};
  CameraPosition _posicaoCamera =
      CameraPosition(target: LatLng(38.70363978979417, -9.400388462337878));

  Map<String, dynamic> _dadosRequisicao;

  //Controles para exibição na tela
  String _textBotao = "Aceitar corrida";
  Color _corBotao = Colors.lightBlue;
  Function _funcaoBotao;
  String _mensagemStatus = "";
  String _idRequisicao;
  Position _localMotorista;
  String _statusRequisicao = StatusRequisicao.AGUARDANDO;

  _alterarBotaoPrincipal(String texto, Color cor, Function funcao) {
    setState(() {
      _textBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });
  }

  _adicionaListenerLocalizacao() {
    var geolocator = Geolocator.getPositionStream(
            desiredAccuracy: LocationAccuracy.high, distanceFilter: 10)
        .listen((Position position) {

      if (position != null) {

        if (_idRequisicao != null && _idRequisicao.isNotEmpty) {
          if (_statusRequisicao != StatusRequisicao.AGUARDANDO) {

            //Atualiza local do passageiro
            UsuarioFirebase.atualizarDadosLocalizacao(
                _idRequisicao, position.latitude, position.longitude);
          }else {//aguardando
            setState(() {
              _localMotorista = position;
            });
            _statusAguardando();
          }
        }
      }
    });
  }

  _recuperaUltimaLocalizacaoConhecida() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    if (position != null) {
      //Atualizar localização em tempo real do motorista

    }
  }

  _movimentarCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  _exibirMarcador(Position local, String icone, String infoWindow) async {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;
    print("pixelRatio tamanho: " + pixelRatio.toString());

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio), icone)
        .then((BitmapDescriptor bitmapDescriptor) {
      Marker marcador = Marker(
        markerId: MarkerId(icone),
        position: LatLng(local.latitude, local.longitude),
        infoWindow: InfoWindow(title: infoWindow),
        icon: bitmapDescriptor,
      );
      setState(() {
        _marcadores.add(marcador);
      });
    });
  }

  _recuperarRequisicao() async {
    String idRequisicao = widget.idRequisicao;

    FirebaseFirestore db = FirebaseFirestore.instance;

    DocumentSnapshot documentSnapshot =
        await db.collection("requisicoes").doc(idRequisicao).get();
  }

  _adicionarListenerRequisicao() async {
    FirebaseFirestore db = FirebaseFirestore.instance;

    await db
        .collection("requisicoes")
        .doc(_idRequisicao)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.data() != null) {
        _dadosRequisicao = snapshot.data();

        Map<String, dynamic> dados = snapshot.data();
        _statusRequisicao = dados["status"];

        switch (_statusRequisicao) {
          case StatusRequisicao.AGUARDANDO:
            _statusAguardando();
            break;
          case StatusRequisicao.A_CAMINHO:
            _statusACaminho();
            break;
          case StatusRequisicao.VIAGEM:
            break;
          case StatusRequisicao.FINALIZADA:
            break;
        }
      }
    });
  }

  _statusAguardando() {
    _alterarBotaoPrincipal("Aceitar corrida", Colors.lightBlue, () {
      _aceitarCorrida();
    });

    if ( _localMotorista != null ) {

      double motoristaLat = _localMotorista.latitude;
      double motoristaLon = _localMotorista.longitude;

      Position position =
      Position(latitude: motoristaLat, longitude: motoristaLon);

      _exibirMarcador(position, "assets/motorista.png", "Motorista");

      CameraPosition cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 19);

      _movimentarCamera(cameraPosition);
    }


  }

  _statusACaminho() {
    _mensagemStatus = "A caminho do passageiro";
    _alterarBotaoPrincipal("Iniciar corrida", Colors.lightBlue, () {
      _iniciarCorrida();
    });

    double latitudePassageiro = _dadosRequisicao["passageiro"]["latitude"];
    double longitudePassageiro = _dadosRequisicao["passageiro"]["longitude"];

    double latitudeMotorista = _dadosRequisicao["motorista"]["latitude"];
    double longitudeMotorista = _dadosRequisicao["motorista"]["longitude"];

    //Exibir dois marcadores
    _exibirDoisMarcadores(
      LatLng(latitudeMotorista, longitudeMotorista),
      LatLng(latitudePassageiro, longitudePassageiro),
    );

    var nLat, nLon, sLat, sLon;

    if (latitudeMotorista <= latitudePassageiro) {
      sLat = latitudeMotorista;
      nLat = latitudePassageiro;
    } else {
      sLat = latitudePassageiro;
      nLat = latitudeMotorista;
    }
    if (longitudeMotorista <= longitudePassageiro) {
      sLon = longitudeMotorista;
      nLon = longitudePassageiro;
    } else {
      sLon = longitudePassageiro;
      nLon = longitudeMotorista;
    }

    _movimentarCameraBounds(LatLngBounds(
      northeast: LatLng(nLat, nLon), //nordeste
      southwest: LatLng(sLat, sLon), //sudoeste
    ));
  }

  _iniciarCorrida() {
    FirebaseFirestore db = FirebaseFirestore.instance;
    db.collection("requisicoes").doc(_idRequisicao).update({
      "origem": {
        "latitude": _dadosRequisicao["motorista"]["latitude"],
        "longitude": _dadosRequisicao["motorista"]["longitude"],
      },
      "status": StatusRequisicao.VIAGEM
    });
    String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
    db
        .collection("requisicao_ativa")
        .doc(idPassageiro)
        .update({"status": StatusRequisicao.VIAGEM});

    String idMotorista = _dadosRequisicao["motorista"]["idUsuario"];
    db
        .collection("requisicao_ativa_motorista")
        .doc(idMotorista)
        .update({"status": StatusRequisicao.VIAGEM});
  }

  _movimentarCameraBounds(LatLngBounds latLngBounds) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newLatLngBounds(latLngBounds, 100));
  }

  _exibirDoisMarcadores(LatLng localMotorista, LatLng localPassageiro) {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    print("pixelRatio tamanho: " + pixelRatio.toString());

    Set<Marker> _listaMarcadores = {};
    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            "assets/motorista.png")
        .then((BitmapDescriptor icone) {
      Marker marcador1 = Marker(
        markerId: MarkerId("marcador-motorista"),
        position: LatLng(localMotorista.latitude, localMotorista.longitude),
        infoWindow: InfoWindow(title: "Local Motorista"),
        icon: icone,
      );
      _listaMarcadores.add(marcador1);
    });

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio), "assets/user.png")
        .then((BitmapDescriptor icone) {
      Marker marcador2 = Marker(
        markerId: MarkerId("marcador-passageiro"),
        position: LatLng(localPassageiro.latitude, localPassageiro.longitude),
        infoWindow: InfoWindow(title: "Local passageiro"),
        icon: icone,
      );
      _listaMarcadores.add(marcador2);
    });
    setState(() {
      _marcadores = _listaMarcadores;
    });
  }

  _aceitarCorrida() async {
    //Recuperar dados motorista

    Usuario motorista = await UsuarioFirebase.getDadosUsuarioLogado();
    motorista.latitude = _localMotorista.latitude;
    motorista.longitude = _localMotorista.longitude;

    FirebaseFirestore db = FirebaseFirestore.instance;
    String idRequisicao = _dadosRequisicao["id"];

    db.collection("requisicoes").doc(idRequisicao).update({
      "motorista": motorista.toMap(),
      "status": StatusRequisicao.A_CAMINHO,
    }).then((_) {
      //atualiza requisicao ativa
      String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
      db.collection("requisicao_ativa").doc(idPassageiro).update({
        "status": StatusRequisicao.A_CAMINHO,
      });

      //salvar requisicao ativa par ao motorista
      String idMotorista = motorista.idUsuario;
      db.collection("requisicao_ativa_motorista").doc(idMotorista).set({
        "id_requisicao": idRequisicao,
        "id_usuario": idMotorista,
        "status": StatusRequisicao.A_CAMINHO,
      });
    });
  }

  @override
  void initState() {
    super.initState();

    _idRequisicao = widget.idRequisicao;
    _adicionarListenerRequisicao();

    //_recuperaUltimaLocalizacaoConhecida();
    _adicionaListenerLocalizacao();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel corrida - " + _mensagemStatus),
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
