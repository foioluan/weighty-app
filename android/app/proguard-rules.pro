# O plugin do Flutter já injeta as regras do engine. As de baixo cobrem o que
# o R8 costuma remover indevidamente nos pacotes que este app usa.

# sqlite3 / drift carregam símbolos nativos por JNI.
-keep class io.flutter.plugins.** { *; }
-keep class com.tekartik.sqflite.** { *; }

# Anotações usadas pelo engine em reflexão.
-keepattributes *Annotation*
-keepattributes Signature

# Silencia avisos de classes opcionais que não usamos.
-dontwarn javax.annotation.**
