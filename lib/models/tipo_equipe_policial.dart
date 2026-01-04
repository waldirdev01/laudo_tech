/// Tipos de equipes policiais/de salvamento
enum TipoEquipePolicial {
  policiaMilitar('Polícia Militar'),
  policiaCivil('Polícia Civil'),
  prf('PRF'),
  bombeiros('Bombeiros'),
  samu('SAMU'),
  outros('Outros');

  final String label;
  const TipoEquipePolicial(this.label);
}

