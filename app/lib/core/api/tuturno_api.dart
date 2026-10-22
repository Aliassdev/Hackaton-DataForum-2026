import 'models.dart';

export 'models.dart';

/// Contrato con el backend (docs/ARQUITECTURA.md, sección 8).
///
/// Las implementaciones lanzan [ApiException] con un mensaje que se puede enseñar al usuario.
abstract interface class TuTurnoApi {
  Future<AskResponse> ask(AskRequest request);

  Future<GradeResponse> grade(GradeRequest request);

  Future<HealthResponse> health();
}
