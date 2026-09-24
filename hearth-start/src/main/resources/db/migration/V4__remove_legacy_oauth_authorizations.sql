-- OAuth authorizations created before the principal fix contain a serialized
-- HearthPrincipal and cannot be read by Spring Security's Jackson allow-list.
-- Authorization codes and access tokens are disposable; consent grants stay.
DELETE FROM oauth2_authorization
WHERE attributes IS NOT NULL
  AND CONVERT(attributes USING utf8mb4) LIKE '%HearthPrincipal%';
