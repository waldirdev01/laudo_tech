/// Tipos de equipes policiais (SAMU e Bombeiros foram movidos para EquipeResgateModel)
enum TipoEquipePolicial {
  policiaMilitar('Polícia Militar'),
  policiaCivil('Polícia Civil'),
  prf('PRF'),
  gcm('GCM - Guarda Civil Municipal'),
  outros('Outros');

  final String label;
  const TipoEquipePolicial(this.label);
}

