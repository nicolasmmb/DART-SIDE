// ignore_for_file: non_constant_identifier_names

import 'dart:convert';

const int KDESCRICAO_TAMANHO_MAXIMO = 10;
const String KDESCRICAO_VAZIA = '';
const String KCREDITO = 'c';
const String KDEBITO = 'd';

class InfoTransacao {
  final int valor;
  final String tipo;
  final String descricao;
  final DateTime realizada_em;

  InfoTransacao(this.valor, this.tipo, this.descricao, this.realizada_em);

  Map<String, dynamic> toMap() {
    return {
      'valor': valor,
      'tipo': tipo,
      'descricao': descricao,
      'realizada_em': realizada_em.toIso8601String(),
    };
  }
}

class InfoSaldo {
  final int limite;
  final int total;
  final DateTime data_extrato = DateTime.now();

  InfoSaldo(this.limite, this.total);

  Map<String, dynamic> toMap() {
    return {
      'limite': limite,
      'total': total,
      'data_extrato': data_extrato.toIso8601String(),
    };
  }
}

class ExtratoOutput {
  final InfoSaldo saldo;
  final List<InfoTransacao> ultimas_transacoes;

  ExtratoOutput(this.saldo, this.ultimas_transacoes);

  Map<String, dynamic> toMap() {
    return {
      'saldo': saldo.toMap(),
      'ultimas_transacoes': ultimas_transacoes.map((e) => e.toMap()).toList(),
    };
  }

  // to json
  String toJson() {
    return toMap().toString();
  }
}

class TransacaoInput {
  final int valor;
  final String tipo;
  final String descricao;

  TransacaoInput(this.valor, this.tipo, this.descricao);

  Map<String, dynamic> toMap() {
    return {
      'valor': valor,
      'tipo': tipo,
      'descricao': descricao,
    };
  }

  // to json
  String toJson() {
    return toMap().toString();
  }

  // from json
  factory TransacaoInput.fromJson(String body) {
    var dados = json.decode(body);
    var valor = dados['valor'];
    if (valor is double) {
      throw Exception('Valor deve ser inteiro');
    }
    return TransacaoInput(
      dados['valor'] as int,
      dados['tipo'] as String,
      dados['descricao'] as String,
    );
  }

  bool Validar() {
    return (tipo == KCREDITO || tipo == KDEBITO) &&
        descricao.length <= KDESCRICAO_TAMANHO_MAXIMO &&
        descricao != KDESCRICAO_VAZIA;
  }
}
