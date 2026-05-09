enum CloudLoadStatus {
  loading,
  unauthenticated,
  newUser,
  missingBaby,
  loaded,
  permissionDenied,
  networkError,
  unknownError,
}

class CloudLoadResult {
  final CloudLoadStatus status;
  final String? uid;
  final String? selectedBabyId;
  final Object? error;
  final String? errorCode;

  const CloudLoadResult({
    required this.status,
    this.uid,
    this.selectedBabyId,
    this.error,
    this.errorCode,
  });
}

