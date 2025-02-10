import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
    @EnviedField(varName: 'SUPA_URL', obfuscate: true)
    static String supaUrl = _Env.supaUrl;
    @EnviedField(varName: 'ANON_KEY', obfuscate: true )
    static String anonKey = _Env.anonKey;
}