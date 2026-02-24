/// Numeração das regiões anatômicas da ficha "EVIDÊNCIAS NO CADÁVER" (CVLI).
/// Referência para o usuário ao registrar lesões/evidências no cadáver.
class EvidenciasCadaverRegioes {
  EvidenciasCadaverRegioes._();

  /// Vista anterior (frente) do corpo — 1 a 28.
  static const List<({int numero, String nome})> vistaAnterior = [
    (numero: 1, nome: 'Frontal'),
    (numero: 2, nome: 'Orbitárias'),
    (numero: 3, nome: 'Malares'),
    (numero: 4, nome: 'Mandibular'),
    (numero: 5, nome: 'Mentoniana'),
    (numero: 6, nome: 'Cervical anterior'),
    (numero: 7, nome: 'Carotidianas'),
    (numero: 8, nome: 'Supraclaviculares'),
    (numero: 9, nome: 'Infraclaviculares'),
    (numero: 10, nome: 'Esternal'),
    (numero: 11, nome: 'Torácicas'),
    (numero: 12, nome: 'Epigástricas'),
    (numero: 13, nome: 'Hipocôndrios'),
    (numero: 14, nome: 'Mesogástrica'),
    (numero: 15, nome: 'Flancos'),
    (numero: 16, nome: 'Hipogástrica'),
    (numero: 17, nome: 'Fossas ilíacas'),
    (numero: 18, nome: 'Pubiana'),
    (numero: 19, nome: 'Inguinal'),
    (numero: 20, nome: 'Vulvar'),
    (numero: 21, nome: 'Braço'),
    (numero: 22, nome: 'Cubital'),
    (numero: 23, nome: 'Antebraço'),
    (numero: 24, nome: 'Palmar'),
    (numero: 25, nome: 'Coxa'),
    (numero: 26, nome: 'Joelho'),
    (numero: 27, nome: 'Perna'),
    (numero: 28, nome: 'Dorso do pé'),
  ];

  /// Vista posterior (costas) do corpo — 1 a 21.
  static const List<({int numero, String nome})> vistaPosterior = [
    (numero: 1, nome: 'Parietal'),
    (numero: 2, nome: 'Occipital'),
    (numero: 3, nome: 'Temporal'),
    (numero: 4, nome: 'Cervical'),
    (numero: 5, nome: 'Supra-escapular'),
    (numero: 6, nome: 'Escapular'),
    (numero: 7, nome: 'Dorsal'),
    (numero: 8, nome: 'Lombar'),
    (numero: 9, nome: 'Ilíaca'),
    (numero: 10, nome: 'Espondiléia'),
    (numero: 11, nome: 'Sacro-coccígea'),
    (numero: 12, nome: 'Glútea'),
    (numero: 13, nome: 'Coxa'),
    (numero: 14, nome: 'Poplíteia'),
    (numero: 15, nome: 'Perna'),
    (numero: 16, nome: 'Pé'),
    (numero: 17, nome: 'Deltóidea'),
    (numero: 18, nome: 'Braço'),
    (numero: 19, nome: 'Cotovelo'),
    (numero: 20, nome: 'Antebraço'),
    (numero: 21, nome: 'Face dorsal mão'),
  ];

  /// Texto para o campo região ao selecionar (evita ambiguidade:
  /// ex. "Coxa" existe em ambas as vistas → "Anterior 25 - Coxa").
  static String textoRegiao(int numero, String nome, {required bool anterior}) {
    final vista = anterior ? 'Anterior' : 'Posterior';
    return '$vista $numero - $nome';
  }
}
