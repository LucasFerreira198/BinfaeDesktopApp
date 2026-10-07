class MilitaryModel {
  final int? id;
  final int saram;
  final String nomeCompleto;
  final String nomeGuerra;
  final String postoGraduacao;
  final String? quadroEspecialidade;
  final String? secao;
  final String? email;
  final List<String> emails;
  final String? celular;
  final String? fotoUrl;
  final bool isInformatica;

  MilitaryModel({
    this.id,
    required this.saram,
    required this.nomeCompleto,
    required this.nomeGuerra,
    required this.postoGraduacao,
    this.quadroEspecialidade,
    this.secao,
    this.email,
    this.emails = const [],
    this.celular,
    this.fotoUrl,
    this.isInformatica = false,
  });

  factory MilitaryModel.fromJson(Map<String, dynamic> json) {
    final rawEmails = json['emails'] as List?;
    final parsedEmails = rawEmails != null
        ? rawEmails.map((e) => e.toString()).toList()
        : (json['email'] != null ? [json['email'].toString()] : <String>[]);

    return MilitaryModel(
      id: json['id'] as int?,
      saram: json['saram'] as int? ?? 0,
      nomeCompleto: json['nome_completo'] as String? ?? '',
      nomeGuerra: json['nome_guerra'] as String? ?? '',
      postoGraduacao: json['posto_graduacao'] as String? ?? '',
      quadroEspecialidade: json['quadro_especialidade'] as String?,
      secao: json['secao'] as String?,
      email: json['email'] as String?,
      emails: parsedEmails,
      celular: json['celular'] as String?,
      fotoUrl: json['foto_url'] as String?,
      isInformatica: json['is_informatica'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'saram': saram,
    'nome_completo': nomeCompleto,
    'nome_guerra': nomeGuerra,
    'posto_graduacao': postoGraduacao,
    'quadro_especialidade': quadroEspecialidade,
    'secao': secao,
    'email': email,
    'emails': emails,
    'celular': celular,
    'foto_url': fotoUrl,
    'is_informatica': isInformatica,
  };

  String? get telefone => celular;
}

class UserModel {
  final int id;
  final String username;
  final bool admin;
  final bool ativo;
  final int? militarId;
  final String? _fotoUrl;
  final MilitaryModel? militar;

  UserModel({
    required this.id,
    required this.username,
    required this.admin,
    required this.ativo,
    this.militarId,
    String? fotoUrl,
    this.militar,
  }) : _fotoUrl = fotoUrl;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      admin: json['admin'] as bool? ?? false,
      ativo: json['ativo'] as bool? ?? true,
      militarId: json['militar_id'] as int?,
      fotoUrl: json['foto_url'] as String?,
      militar: json['militar'] != null ? MilitaryModel.fromJson(json['militar']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'admin': admin,
    'ativo': ativo,
    'militar_id': militarId,
    'foto_url': fotoUrl,
    'militar': militar?.toJson(),
  };

  String? get fotoUrl => _fotoUrl ?? militar?.fotoUrl;

  String get displayName {
    if (militar != null) {
      return '${militar!.postoGraduacao} ${militar!.nomeGuerra}';
    }
    return username;
  }

  String get postoGraduacao => militar?.postoGraduacao ?? '';
  String get nomeGuerra => militar?.nomeGuerra ?? username;
  String get nomeCompleto => militar?.nomeCompleto ?? username;
  int? get saram => militar?.saram;
  String? get celular => militar?.celular;
  String? get telefone => militar?.celular;
  String? get email => militar?.email;
  List<String> get emails => militar?.emails ?? (email != null ? [email!] : []);
  bool get hasEmail => (militar?.email != null && militar!.email!.trim().isNotEmpty) || (militar?.emails.isNotEmpty ?? false);
}
