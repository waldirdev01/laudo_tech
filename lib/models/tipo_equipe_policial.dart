/// Tipos de equipes policiais (SAMU e Bombeiros foram movidos para EquipeResgateModel)
enum TipoEquipePolicial {
  policiaMilitar('Polícia Militar'),
  policiaCivil('Polícia Civil'),
  prf('PRF'),
  outros('Outros');

  final String label;
  const TipoEquipePolicial(this.label);
}

