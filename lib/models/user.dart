class MilitaryModel {
  final int saram;
  final String nomeCompleto;
  final String nomeGuerra;
  final String postoGraduacao;
  final String? quadroEspecialidade;
  final String? secao;
  final String? email;
  final String? celular;

  MilitaryModel({
    required this.saram,
    required this.nomeCompleto,
    required this.nomeGuerra,
    required this.postoGraduacao,
    this.quadroEspecialidade,
    this.secao,
    this.email,
    this.celular,
  });

  factory MilitaryModel.fromJson(Map<String, dynamic> json) {
    return MilitaryModel(
      saram: json['saram'] as int? ?? 0,
      nomeCompleto: json['nome_completo'] as String? ?? '',
      nomeGuerra: json['nome_guerra'] as String? ?? '',
      postoGraduacao: json['posto_graduacao'] as String? ?? '',
      quadroEspecialidade: json['quadro_especialidade'] as String?,
      secao: json['secao'] as String?,
      email: json['email'] as String?,
      celular: json['celular'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'saram': saram,
    'nome_completo': nomeCompleto,
    'nome_guerra': nomeGuerra,
    'posto_graduacao': postoGraduacao,
    'quadro_especialidade': quadroEspecialidade,
    'secao': secao,
    'email': email,
    'celular': celular,
  };

  String? get telefone => celular;
}

class UserModel {
  final int id;
  final String username;
  final bool admin;
  final bool ativo;
  final int? militarId;
  final MilitaryModel? militar;

  UserModel({
    required this.id,
    required this.username,
    required this.admin,
    required this.ativo,
    this.militarId,
    this.militar,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      admin: json['admin'] as bool? ?? false,
      ativo: json['ativo'] as bool? ?? true,
      militarId: json['militar_id'] as int?,
      militar: json['militar'] != null ? MilitaryModel.fromJson(json['militar']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'admin': admin,
    'ativo': ativo,
    'militar_id': militarId,
    'militar': militar?.toJson(),
  };

  String get displayName {
    if (militar != null) {
      return '${militar!.postoGraduacao} ${militar!.nomeGuerra}';
    }
    return username;
  }

  String get postoGraduacao => militar?.postoGraduacao ?? '';
  String get nomeGuerra => militar?.nomeGuerra ?? username;
  String get nomeCompleto => militar?.nomeCompleto ?? username;
  String? get celular => militar?.celular;
  String? get telefone => militar?.celular;
}

