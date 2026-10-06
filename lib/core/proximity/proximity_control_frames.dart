import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

import '../protocol/constants.dart';
import '../security/device_identity.dart';
import 'proximity_types.dart';

class ControlHelloBody {
  const ControlHelloBody({
    required this.peerId,
    required this.nick,
    required this.publicKeyBase64,
    this.wifiSsid,
  });
  final String peerId;
  final String nick;
  final String publicKeyBase64;

  /// Peer's current Wi-Fi name. Not a secret; omitted when unknown.
  final String? wifiSsid;

  Map<String, dynamic> toJson() => {
    'peerId': peerId,
    'nick': nick,
    'publicKeyBase64': publicKeyBase64,
    if (wifiSsid != null && wifiSsid!.isNotEmpty) 'wifiSsid': wifiSsid,
  };

  factory ControlHelloBody.fromJson(Map<String, dynamic> json) =>
      ControlHelloBody(
        peerId: json['peerId'] as String,
        nick: json['nick'] as String,
        publicKeyBase64: json['publicKeyBase64'] as String,
        wifiSsid: json['wifiSsid'] as String?,
      );
}

class ControlInviteBody {
  const ControlInviteBody({
    required this.nick,
    required this.code,
    required this.hostPlan,
    required this.useLanMine,
    required this.useLanTheirs,
    required this.usePrivateNetwork,
  });
  final String nick;
  final String code;
  final List<HostStep> hostPlan;
  final bool useLanMine;
  final bool useLanTheirs;
  final bool usePrivateNetwork;

  Map<String, dynamic> toJson() => {
    'nick': nick,
    'code': code,
    'hostPlan': hostPlan.map((s) => s.toJson()).toList(),
    'useLanMine': useLanMine,
    'useLanTheirs': useLanTheirs,
    'usePrivateNetwork': usePrivateNetwork,
  };

  factory ControlInviteBody.fromJson(Map<String, dynamic> json) =>
      ControlInviteBody(
        nick: json['nick'] as String,
        code: json['code'] as String,
        hostPlan: (json['hostPlan'] as List<dynamic>)
            .map((e) => HostStep.fromJson(e as Map<String, dynamic>))
            .toList(),
        useLanMine: json['useLanMine'] as bool,
        useLanTheirs: json['useLanTheirs'] as bool,
        usePrivateNetwork: json['usePrivateNetwork'] as bool,
      );
}

class ControlAcceptBody {
  const ControlAcceptBody();
  Map<String, dynamic> toJson() => {};
  factory ControlAcceptBody.fromJson(Map<String, dynamic> json) {
    if (json.isNotEmpty) {
      throw FormatException('accept body must be empty');
    }
    return const ControlAcceptBody();
  }
}

class ControlDeclineBody {
  const ControlDeclineBody({required this.reason});
  final String reason;

  Map<String, dynamic> toJson() => {'reason': reason};

  factory ControlDeclineBody.fromJson(Map<String, dynamic> json) =>
      ControlDeclineBody(reason: json['reason'] as String);
}

class ControlSecretBody {
  const ControlSecretBody({
    required this.ssid,
    required this.psk,
    required this.security,
    required this.kind,
  });
  final String ssid;
  final String psk;
  final String security;
  final String kind;
}

/// Receiver tells the initiator whether it still needs the LAN passphrase.
class ControlLanStatusBody {
  const ControlLanStatusBody({required this.needPsk});
  final bool needPsk;

  Map<String, dynamic> toJson() => {'needPsk': needPsk};

  factory ControlLanStatusBody.fromJson(Map<String, dynamic> json) =>
      ControlLanStatusBody(needPsk: json['needPsk'] as bool);
}

class ControlHostFailedBody {
  const ControlHostFailedBody({required this.hostId, required this.method});
  final String hostId;
  final HostMethod method;

  Map<String, dynamic> toJson() => {
    'hostId': hostId,
    'method': method == HostMethod.wifiDirect ? 'wifiDirect' : 'hotspot',
  };

  factory ControlHostFailedBody.fromJson(Map<String, dynamic> json) =>
      ControlHostFailedBody(
        hostId: json['hostId'] as String,
        method: hostMethodFromName(json['method'] as String),
      );
}

class ControlInviteMemberBody {
  const ControlInviteMemberBody({
    required this.newFingerprint,
    required this.nick,
    required this.code,
  });
  final String newFingerprint;
  final String nick;
  final String code;

  Map<String, dynamic> toJson() => {
    'newFingerprint': newFingerprint,
    'nick': nick,
    'code': code,
  };

  factory ControlInviteMemberBody.fromJson(Map<String, dynamic> json) =>
      ControlInviteMemberBody(
        newFingerprint: json['newFingerprint'] as String,
        nick: json['nick'] as String,
        code: json['code'] as String,
      );
}

class ControlSession {
  bool accepted = false;
  String? peerFingerprint;
  String? peerEd25519PublicKeyB64;
  String? peerX25519PublicKeyB64;
}

class ControlFrameCodec {
  ControlFrameCodec(this.identity);
  final DeviceIdentity identity;

  static final _x25519 = X25519();
  static final _aead = Chacha20.poly1305Aead();
  static const _x25519Label = 'blan-ctl-x25519-v1';
  static const _nonceLength = 12;
  static const _macLength = 16;

  Future<Map<String, dynamic>> encode(
    Object body, {
    required ControlSession session,
    List<int>? pskNonce,
  }) async {
    final local = await identity.ensureIdentity();
    final type = _typeOf(body);
    if (body is ControlSecretBody && !session.accepted) {
      throw StateError('secret before accept');
    }

    Map<String, dynamic> bodyJson;
    String? x25519;
    if (body is ControlHelloBody) {
      bodyJson = body.toJson();
      x25519 = base64Encode(
        (await (await _localX25519()).extractPublicKey()).bytes,
      );
    } else if (body is ControlInviteBody) {
      bodyJson = body.toJson();
    } else if (body is ControlAcceptBody) {
      bodyJson = body.toJson();
      session.accepted = true;
    } else if (body is ControlDeclineBody) {
      bodyJson = body.toJson();
    } else if (body is ControlSecretBody) {
      final peerX = session.peerX25519PublicKeyB64;
      if (peerX == null || peerX.isEmpty) {
        throw StateError('hello without x25519');
      }
      final nonce = pskNonce ?? _randomNonce();
      if (nonce.length != _nonceLength) {
        throw ArgumentError.value(nonce, 'pskNonce', 'must be 12 bytes');
      }
      final pskSeal = await _sealPsk(body.psk, peerX, nonce);
      bodyJson = {
        'ssid': body.ssid,
        'pskSeal': pskSeal,
        'security': body.security,
        'kind': body.kind,
      };
    } else if (body is ControlHostFailedBody) {
      bodyJson = body.toJson();
    } else if (body is ControlLanStatusBody) {
      bodyJson = body.toJson();
    } else if (body is ControlInviteMemberBody) {
      bodyJson = body.toJson();
    } else {
      throw ArgumentError.value(body, 'body', 'unknown control frame');
    }

    final payload =
        '$protocolVersion|$type|${local.fingerprint}|${x25519 ?? ''}|${jsonEncode(bodyJson)}';
    final sig = await identity.signUtf8(payload);
    return {
      'v': protocolVersion,
      'type': type,
      'from': local.fingerprint,
      'x25519': ?x25519,
      'body': bodyJson,
      'sig': sig,
    };
  }

  Future<Object> decode(
    Map<String, dynamic> json, {
    required ControlSession session,
  }) async {
    final v = json['v'];
    if (v != protocolVersion) {
      throw FormatException('unsupported control version $v');
    }
    final type = json['type'] as String?;
    final from = json['from'] as String?;
    final sig = json['sig'] as String?;
    final bodyRaw = json['body'];
    if (type == null || from == null || sig == null || bodyRaw is! Map) {
      throw FormatException('malformed control frame');
    }
    final bodyJson = Map<String, dynamic>.from(bodyRaw);
    final xField = (json['x25519'] as String?) ?? '';
    final payload = '$v|$type|$from|$xField|${jsonEncode(bodyJson)}';

    if (type == 'secret' && !session.accepted) {
      throw StateError('secret before accept');
    }

    final publicKey = type == 'hello'
        ? bodyJson['publicKeyBase64'] as String?
        : session.peerEd25519PublicKeyB64;
    if (publicKey == null || publicKey.isEmpty) {
      throw FormatException('missing peer public key');
    }
    final ok = await DeviceIdentity.verifyUtf8(
      publicKeyBase64: publicKey,
      message: payload,
      signatureBase64: sig,
    );
    if (!ok) {
      throw FormatException('bad signature');
    }

    switch (type) {
      case 'hello':
        final body = ControlHelloBody.fromJson(bodyJson);
        session.peerFingerprint = from;
        session.peerEd25519PublicKeyB64 = body.publicKeyBase64;
        session.peerX25519PublicKeyB64 = json['x25519'] as String?;
        return body;
      case 'invite':
        return ControlInviteBody.fromJson(bodyJson);
      case 'accept':
        session.accepted = true;
        return ControlAcceptBody.fromJson(bodyJson);
      case 'decline':
        return ControlDeclineBody.fromJson(bodyJson);
      case 'secret':
        final peerX = session.peerX25519PublicKeyB64;
        if (peerX == null || peerX.isEmpty) {
          throw StateError('hello without x25519');
        }
        final pskSeal = bodyJson['pskSeal'] as String?;
        if (pskSeal == null) {
          throw FormatException('missing pskSeal');
        }
        final psk = await _openPsk(pskSeal, peerX);
        return ControlSecretBody(
          ssid: bodyJson['ssid'] as String,
          psk: psk,
          security: bodyJson['security'] as String,
          kind: bodyJson['kind'] as String,
        );
      case 'hostFailed':
        return ControlHostFailedBody.fromJson(bodyJson);
      case 'lanStatus':
        return ControlLanStatusBody.fromJson(bodyJson);
      case 'inviteMember':
        return ControlInviteMemberBody.fromJson(bodyJson);
      default:
        throw FormatException('unknown control type $type');
    }
  }

  String _typeOf(Object body) {
    if (body is ControlHelloBody) {
      return 'hello';
    }
    if (body is ControlInviteBody) {
      return 'invite';
    }
    if (body is ControlAcceptBody) {
      return 'accept';
    }
    if (body is ControlDeclineBody) {
      return 'decline';
    }
    if (body is ControlSecretBody) {
      return 'secret';
    }
    if (body is ControlHostFailedBody) {
      return 'hostFailed';
    }
    if (body is ControlLanStatusBody) {
      return 'lanStatus';
    }
    if (body is ControlInviteMemberBody) {
      return 'inviteMember';
    }
    throw ArgumentError.value(body, 'body', 'unknown control frame');
  }

  Future<SimpleKeyPair> _localX25519() async {
    final seed = await identity.ed25519Seed();
    final material = sha256.convert([
      ...seed,
      ...utf8.encode(_x25519Label),
    ]).bytes;
    return _x25519.newKeyPairFromSeed(material);
  }

  Future<SecretKey> _sharedSecret(String peerX25519PublicKeyB64) async {
    final local = await _localX25519();
    final remote = SimplePublicKey(
      base64Decode(peerX25519PublicKeyB64),
      type: KeyPairType.x25519,
    );
    return _x25519.sharedSecretKey(keyPair: local, remotePublicKey: remote);
  }

  Future<String> _sealPsk(String psk, String peerX, List<int> nonce) async {
    final key = await _sharedSecret(peerX);
    final box = await _aead.encrypt(
      utf8.encode(psk),
      secretKey: key,
      nonce: nonce,
    );
    final packed = Uint8List(
      nonce.length + box.mac.bytes.length + box.cipherText.length,
    );
    packed.setRange(0, nonce.length, nonce);
    packed.setRange(
      nonce.length,
      nonce.length + box.mac.bytes.length,
      box.mac.bytes,
    );
    packed.setRange(
      nonce.length + box.mac.bytes.length,
      packed.length,
      box.cipherText,
    );
    return base64Encode(packed);
  }

  Future<String> _openPsk(String pskSeal, String peerX) async {
    final packed = base64Decode(pskSeal);
    if (packed.length < _nonceLength + _macLength) {
      throw FormatException('pskSeal too short');
    }
    final nonce = packed.sublist(0, _nonceLength);
    final macBytes = packed.sublist(_nonceLength, _nonceLength + _macLength);
    final cipher = packed.sublist(_nonceLength + _macLength);
    final key = await _sharedSecret(peerX);
    final clear = await _aead.decrypt(
      SecretBox(cipher, nonce: nonce, mac: Mac(macBytes)),
      secretKey: key,
    );
    return utf8.decode(clear);
  }

  List<int> _randomNonce() =>
      List<int>.generate(_nonceLength, (_) => Random.secure().nextInt(256));
}
