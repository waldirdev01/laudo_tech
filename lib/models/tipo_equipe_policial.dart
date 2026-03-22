/// Tipos de equipes policiais (SAMU e Bombeiros foram movidos para EquipeResgateModel)
enum TipoEquipePolicial {
  policiaMilitar('Polícia Militar'),
  policiaCivil('Polícia Civil'),
  prf('PRF'),
  gcm('Guarda Civil Metropolitana'),
  outros('Outros');

  final String label;
  const TipoEquipePolicial(this.label);
}

