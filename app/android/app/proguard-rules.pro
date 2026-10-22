# Reglas de R8 para la release (Flutter añade este archivo solo, si existe).
#
# shared_preferences_android 2.5.1 llama a su código Kotlin por JNI (package:jni) y busca estas clases de Kotlin por
# su nombre. Sin estas reglas, R8 las renombra y la release falla al arrancar con NoSuchMethodError (las preferencias
# no cargan). Son las mismas reglas que trae shared_preferences_android 2.5.2 (consumer-rules.pro): cuando la app use
# la 2.5.2 o una posterior, este archivo sobra.
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }
