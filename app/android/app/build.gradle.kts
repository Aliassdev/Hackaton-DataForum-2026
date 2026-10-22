import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de la release (app/README.md, «Firma de la release»). android/key.properties no va a git: dice dónde está
// el almacén de claves (storeFile) y trae storePassword, keyAlias y keyPassword. Si no existe, la release se firma
// con la clave de depuración de este ordenador, con un aviso, para que nadie se quede sin poder compilar.
val propiedadesFirma = rootProject.file("key.properties")
val firmaRelease: Properties? =
    if (propiedadesFirma.isFile) Properties().apply { propiedadesFirma.inputStream().use { load(it) } } else null

if (firmaRelease == null && gradle.startParameter.taskNames.any { it.contains("Release") }) {
    // Con logger.error porque Flutter llama a Gradle con -q y un warn no se vería.
    logger.error(
        """
        |AVISO de TuTurno: no hay android/key.properties, así que esta release va firmada con la clave de depuración.
        |Sirve para probar, pero no se puede publicar ni instalar encima de la TuTurno publicada (otra firma).
        |Para firmarla con la clave de release, mira «Firma de la release» en app/README.md.
        """.trimMargin(),
    )
}

android {
    namespace = "com.example.tuturno"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Debug y profile. La release se publica como io.github.aliassdev.tuturno (androidComponents, más abajo).
        applicationId = "com.example.tuturno"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        firmaRelease?.let { firma ->
            create("release") {
                // Una ruta relativa se lee desde android/, la carpeta de key.properties.
                storeFile = firma.getProperty("storeFile")?.let { rootProject.file(it) }
                storePassword = firma.getProperty("storePassword")
                keyAlias = firma.getProperty("keyAlias")
                keyPassword = firma.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (firmaRelease != null) "release" else "debug")
        }
    }
}

// La release es io.github.aliassdev.tuturno; debug y profile siguen siendo com.example.tuturno, así que las dos
// conviven en el mismo móvil. El namespace y el paquete de Kotlin (com.example.tuturno) no cambian.
androidComponents {
    onVariants(selector().withBuildType("release")) { variant ->
        variant.applicationId.set("io.github.aliassdev.tuturno")
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
