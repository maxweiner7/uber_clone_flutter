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
  Position _localMotorista;

  //Controles para exibição na tela
  String _textBotao = "Aceitar corrida";
  Color _corBotao = Colors.lightBlue;
  Function _funcaoBotao;

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
      _exibirMarcadorPassageiro(position);
      _posicaoCamera = CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 19);
      _movimentarCamera(_posicaoCamera);

      setState(() {
        _localMotorista = position;
      });
    });
  }

  _recuperaUltimaLocalizacaoConhecida() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      if (position != null) {
        // _exibirMarcadorPassageiro( position );

        _posicaoCamera = CameraPosition(
            target: LatLng(position.latitude, position.longitude), zoom: 19);
        _movimentarCamera(_posicaoCamera);
        _exibirMarcadorPassageiro(position);
        _localMotorista = position;
      }
    });
  }

  _movimentarCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  _exibirMarcadorPassageiro(Position local) async {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;
    print("pixelRatio tamanho: " + pixelRatio.toString());

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            "assets/motorista.png")
        .then((BitmapDescriptor icone) {
      Marker marcadorPassageiro = Marker(
        markerId: MarkerId("marcador-motorista"),
        position: LatLng(local.latitude, local.longitude),
        infoWindow: InfoWindow(title: "Meu local"),
        icon: icone,
      );
      setState(() {
        _marcadores.add(marcadorPassageiro);
      });
    });
  }

  _recuperarRequisicao() async {
    String idRequisicao = widget.idRequisicao;

    FirebaseFirestore db = FirebaseFirestore.instance;

    DocumentSnapshot documentSnapshot =
        await db.collection("requisicoes").doc(idRequisicao).get();

    _dadosRequisicao = documentSnapshot.data();
    _adicionarListenerRequisicao();
  }

  _adicionarListenerRequisicao() async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    String idRequisicao = _dadosRequisicao["id"];
    await db
        .collection("requisicoes")
        .doc(idRequisicao)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.data() != null) {
        Map<String, dynamic> dados = snapshot.data();
        String status = dados["status"];

        switch (status) {
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
    _alterarBotaoPrincipal("Aceitar corrida", Colors.grey, () {
      _aceitarCorrida();
    });
    ;
  }

  _statusACaminho() {
    _alterarBotaoPrincipal("A caminho do passageiro", Colors.lightBlue, null);
    double latitudePassageiro = _dadosRequisicao["passageiro"]["latitude"];
    double longetudePassageiro = _dadosRequisicao["passageiro"]["longitude"];

    double latitudeMotorista = _dadosRequisicao["motorista"]["latitude"];
    double longetudeMotorista = _dadosRequisicao["motorista"]["longitude"];

    _exibirDoisMarcadores(
      LatLng(latitudeMotorista, longetudeMotorista),
      LatLng(latitudePassageiro, longetudePassageiro),
    );
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
      _movimentarCamera(CameraPosition(
          target: LatLng(localMotorista.latitude, localMotorista.longitude),
          zoom: 18));
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

    _recuperaUltimaLocalizacaoConhecida();
    _adicionaListenerLocalizacao();

    //recuperar requisicao e
    // adicionar listener para mudanºa de status
    _recuperarRequisicao();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel corrida"),
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
