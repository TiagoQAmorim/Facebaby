/// Shown on the login footer so you can confirm which bundle is deployed.
const String kAdminBuildLabel = String.fromEnvironment(
  'ADMIN_BUILD_LABEL',
  defaultValue: 'Admin build v5',
);
