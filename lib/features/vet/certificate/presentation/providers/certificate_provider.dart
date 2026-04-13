import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/certificate_repository.dart';
import '../../domain/vet_certificate_model.dart';

/// Provides the list of all certificates issued by the vet.
final certificateListProvider =
    FutureProvider.autoDispose<List<VetCertificateModel>>((ref) async {
  final repo = ref.watch(certificateRepositoryProvider);
  final result = await repo.getCertificates();
  return result.when(
    success: (certs) => certs,
    failure: (e) => throw Exception(e.message),
  );
});

/// Provides a single certificate by ID.
final selectedCertificateProvider = FutureProvider.autoDispose
    .family<VetCertificateModel, String>((ref, id) async {
  final repo = ref.watch(certificateRepositoryProvider);
  final result = await repo.getCertificateById(id);
  return result.when(
    success: (cert) => cert,
    failure: (e) => throw Exception(e.message),
  );
});
