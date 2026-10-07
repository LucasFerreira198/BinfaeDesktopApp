class InformaticaConfigModel {
  final int id;
  int? militarAntigo1Id;
  String? militarAntigo1Nome;
  int? militarAntigo2Id;
  String? militarAntigo2Nome;
  bool notificarEmailAtivo;
  bool notificarWhatsappAtivo;
  String? whatsappWebhookUrl;
  String? whatsappNumeroGrupo;
  String? smtpHost;
  int smtpPort;
  String? smtpUser;
  String? smtpFrom;

  InformaticaConfigModel({
    required this.id,
    this.militarAntigo1Id,
    this.militarAntigo1Nome,
    this.militarAntigo2Id,
    this.militarAntigo2Nome,
    this.notificarEmailAtivo = true,
    this.notificarWhatsappAtivo = false,
    this.whatsappWebhookUrl,
    this.whatsappNumeroGrupo,
    this.smtpHost,
    this.smtpPort = 587,
    this.smtpUser,
    this.smtpFrom,
  });

  factory InformaticaConfigModel.fromJson(Map<String, dynamic> json) {
    return InformaticaConfigModel(
      id: json['id'] as int? ?? 1,
      militarAntigo1Id: json['militar_antigo_1_id'] as int?,
      militarAntigo1Nome: json['militar_antigo_1_nome'] as String?,
      militarAntigo2Id: json['militar_antigo_2_id'] as int?,
      militarAntigo2Nome: json['militar_antigo_2_nome'] as String?,
      notificarEmailAtivo: json['notificar_email_ativo'] as bool? ?? true,
      notificarWhatsappAtivo: json['notificar_whatsapp_ativo'] as bool? ?? false,
      whatsappWebhookUrl: json['whatsapp_webhook_url'] as String?,
      whatsappNumeroGrupo: json['whatsapp_numero_grupo'] as String?,
      smtpHost: json['smtp_host'] as String?,
      smtpPort: json['smtp_port'] as int? ?? 587,
      smtpUser: json['smtp_user'] as String?,
      smtpFrom: json['smtp_from'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'militar_antigo_1_id': militarAntigo1Id,
    'militar_antigo_2_id': militarAntigo2Id,
    'notificar_email_ativo': notificarEmailAtivo,
    'notificar_whatsapp_ativo': notificarWhatsappAtivo,
    'whatsapp_webhook_url': whatsappWebhookUrl,
    'whatsapp_numero_grupo': whatsappNumeroGrupo,
    'smtp_host': smtpHost,
    'smtp_port': smtpPort,
    'smtp_user': smtpUser,
    'smtp_from': smtpFrom,
  };
}
