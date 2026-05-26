import 'admin_auth_service.dart';

enum AdminRole { owner, admin }

AdminRole? parseAdminRole(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'owner':
      return AdminRole.owner;
    case 'admin':
      return AdminRole.admin;
    default:
      return null;
  }
}

String roleLabel(AdminRole role) => switch (role) {
      AdminRole.owner => 'owner',
      AdminRole.admin => 'admin',
    };

abstract final class AdminPermissions {
  static AdminRole? roleOf(AdminProfile? profile) => profile?.role;

  /// Panel access: active + role owner or admin.
  static bool hasPanelAccess(AdminProfile? profile) {
    final r = roleOf(profile);
    return r == AdminRole.owner || r == AdminRole.admin;
  }

  static bool canManageUsers(AdminProfile? profile) => hasPanelAccess(profile);

  static void requireManageUsers(AdminProfile? profile) {
    if (!canManageUsers(profile)) {
      throw StateError('Permission denied.');
    }
  }
}
