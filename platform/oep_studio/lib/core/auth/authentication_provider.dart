import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'authentication_service.dart';
import 'local_authentication_provider.dart';

/// The active [AuthenticationService] -- today always
/// [LocalAuthenticationProvider]. Overridden in tests with a fake, and
/// this is the one place a future real
/// `OepIdentityAuthenticationProvider` would be substituted in.
final authenticationServiceProvider = Provider<AuthenticationService>((ref) => LocalAuthenticationProvider());
