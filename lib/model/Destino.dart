import 'dart:ffi';

class Destino {

  String _rua;
  String _numero;
  String _cidade;
  String _bairro;
  String _cep;
  double _latitude;
  double _longetude;
  Map<dynamic, dynamic> _coordenadas ;


  Destino();


  Map get coordenadas => _coordenadas;

  set coordenadas(Map value) {
    _coordenadas = value;
  }

  double get longetude => _longetude;

  set longetude(double value) {
    _longetude = value;
  }

  double get latitude => _latitude;

  set latitude(double value) {
    _latitude = value;
  }

  String get cep => _cep;

  set cep(String value) {
    _cep = value;
  }

  String get bairro => _bairro;

  set bairro(String value) {
    _bairro = value;
  }

  String get cidade => _cidade;

  set cidade(String value) {
    _cidade = value;
  }

  String get numero => _numero;

  set numero(String value) {
    _numero = value;
  }

  String get rua => _rua;

  set rua(String value) {
    _rua = value;
  }
}