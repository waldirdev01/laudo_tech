/// Numeração dos tipos de barba da imagem de referência (assets/images/barba.png).
/// Guia de Barbas — ao selecionar um item, o usuário preenche o tipo de barba com o nome correspondente.
class TiposBarbaReferencia {
  TiposBarbaReferencia._();

  /// Lista (número da imagem, nome para o laudo) conforme o Guia de Barbas.
  static const List<({int numero, String nome})> tipos = [
    (numero: 1, nome: 'Rosto Limpo'),
    (numero: 2, nome: 'Barba Por Fazer (Curta)'),
    (numero: 3, nome: 'Barba Por Fazer (Média)'),
    (numero: 4, nome: 'Barba Por Fazer (Longa)'),
    (numero: 5, nome: 'Barba Completa'),
    (numero: 6, nome: 'Barba em Forquilha'),
    (numero: 7, nome: 'Barba de Pato'),
    (numero: 8, nome: 'Barba Circular'),
    (numero: 9, nome: 'Cavanhaque'),
    (numero: 10, nome: 'Cavanhaque Prolongado'),
    (numero: 11, nome: 'Âncora'),
    (numero: 12, nome: 'Balbo'),
    (numero: 13, nome: 'Imperial'),
    (numero: 14, nome: 'Van Dyke'),
    (numero: 15, nome: 'Ferradura'),
    (numero: 16, nome: 'Verdi'),
    (numero: 17, nome: 'Garibaldi'),
    (numero: 18, nome: 'Holandesa'),
    (numero: 19, nome: 'Ligao Rusa'),
    (numero: 20, nome: 'Bandholz'),
  ];
}
