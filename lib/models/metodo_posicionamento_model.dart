enum MetodoPosicionamentoVestigio {
  nenhum('Sem posicionamento'),
  marcoZero('Marco zero'),
  gps('GPS');

  final String label;
  const MetodoPosicionamentoVestigio(this.label);

  static MetodoPosicionamentoVestigio? fromName(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}
