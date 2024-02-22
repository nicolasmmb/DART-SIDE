// ignore_for_file: non_constant_identifier_names, prefer_interpolation_to_compose_strings, depend_on_referenced_packages, unused_local_variable, constant_identifier_names

import 'dart:convert';
import 'dart:io';
import 'package:DART_SIDE/models.dart';
import 'package:dotenv/dotenv.dart';
import 'package:postgres/postgres.dart';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

late Connection cnx;

// Queries
const Q_CLIENTE_INFOS = r'SELECT limite, saldo FROM clientes WHERE id = $1 LIMIT 1 FOR UPDATE;';
const Q_EXTRATO =
    r'SELECT valor, tipo, descricao, realizada_em FROM transacoes WHERE cliente_id = $1 ORDER BY realizada_em DESC LIMIT 10;';
const Q_UPDATE_CRED_DEB =
    r"UPDATE clientes SET saldo = CASE WHEN $1 = 'c' THEN saldo + $2 ELSE saldo - $2 END WHERE id = $3 RETURNING saldo;";
const Q_INSERT_INFO = r"INSERT INTO transacoes (cliente_id, valor, tipo, descricao) VALUES ($1, $2, $3, $4);";

// Constantes
const C_LIMITES = [100000, 80000, 1000000, 10000000, 500000];

final router = Router()
  ..get('/ping', pingHandler)
  ..post('/clientes/<id>/transacoes', transacaoHandler)
  ..get('/clientes/<id>/extrato', extratoHandler);

Future<Response> extratoHandler(Request req) async {
  int id = int.parse(req.params['id']!);
  if (id > 5) {
    return Response.notFound('Id não encontrado\n');
  }

  var info_cliente = await cnx.execute(Q_CLIENTE_INFOS, parameters: [id]);
  late int saldo, limite;
  for (var row in info_cliente) {
    limite = row[0] as int;
    saldo = row[1] as int;
  }

  var info_transacao = await cnx.execute(Q_EXTRATO, parameters: [id]);
  var transacoes = <InfoTransacao>[];

  for (var row in info_transacao) {
    var info = InfoTransacao(
      row[0] as int,
      row[1] as String,
      row[2] as String,
      row[3] as DateTime,
    );
    transacoes.add(info);
  }

  return Response(
    200,
    body: jsonEncode(
      {
        'saldo': {
          'limite': limite,
          'total': saldo,
          'data_extrato': DateTime.now().toIso8601String(),
        },
        'ultimas_transacoes': transacoes
            .map((e) => {
                  'valor': e.valor,
                  'tipo': e.tipo,
                  'descricao': e.descricao,
                  'realizada_em': e.realizada_em.toIso8601String(),
                })
            .toList(),
      },
    ),
  );
}

Future<Response> transacaoHandler(Request req) async {
  int id = int.parse(req.params['id']!);
  if (id > 5) {
    return Response.notFound('Id não encontrado\n');
  }

  late TransacaoInput transacao;
  String body = await req.readAsString();
  try {
    transacao = TransacaoInput.fromJson(body);
  } catch (e) {
    return Response(422);
  }

  if (!transacao.Validar()) {
    return Response(422);
  }

  var limite = C_LIMITES[id - 1];
  late int saldo;
  try {
    var info_cliente = await cnx.execute(Q_UPDATE_CRED_DEB, parameters: [transacao.tipo, transacao.valor, id]);
    for (var row in info_cliente) {
      saldo = row[0] as int;
    }
  } catch (e) {
    return Response(422);
  }

  var insert_transacao =
      await cnx.execute(Q_INSERT_INFO, parameters: [id, transacao.valor, transacao.tipo, transacao.descricao]);

  return Response(200, body: jsonEncode({'saldo': saldo, 'limite': limite}));
}

Future main() async {
  var LOCAL_PATH = Platform.script.resolve('../../').toFilePath() + ".env";
  var env = DotEnv(includePlatformEnvironment: true)..load([LOCAL_PATH]);

  final String DB_HOST = env['DB_HOST']!;
  final String DB_PORT = env['DB_PORT']!;
  final String DB_NAME = env['DB_NAME']!;
  final String DB_USER = env['DB_USER']!;
  final String DB_PASS = env['DB_PASS']!;

  final String SERVER_PORT = env['SERVER_PORT']!;
  final String SERVER_ADDR = env['SERVER_ADDR']!;

  cnx = await Connection.open(
    Endpoint(
      host: DB_HOST,
      port: int.parse(DB_PORT),
      database: DB_NAME,
      username: DB_USER,
      password: DB_PASS,
    ),
    settings: ConnectionSettings(
      sslMode: SslMode.disable,
    ),
  );

  var handler = const Pipeline().addMiddleware(logRequests()).addHandler(router);
  var server = await serve(handler, SERVER_ADDR, int.parse(SERVER_PORT));
  print('Server listening on ${server.address.host}:${server.port}');
}

//
Response pingHandler(Request req) {
  return Response.ok('Pong\n');
}

Response notFoundHandler(Request req) {
  return Response.notFound('Not Found\n');
}
