plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.mtg_lifecounter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Firma dell'app: **una chiave sola**, quella del progetto (`app/signing/mtg-lifecounter.jks`),
    // usata sia in locale sia dalla pipeline. Se le due firme differiscono Android rifiuta
    // l'aggiornamento con `INSTALL_FAILED_UPDATE_INCOMPATIBLE` e l'unico modo di installare e'
    // disinstallare prima, perdendo vite, colori e timer; Play Protect, dal canto suo, segnala
    // l'APK come app non riconosciuta. La chiave sta quindi nel repo apposta: e' l'unico modo
    // perche' firma locale e firma della pipeline siano identiche **per costruzione**, senza
    // segreti da configurare e senza dipendere da dove la macchina tiene il debug keystore di
    // sistema. E' di fatto una chiave "debug" (l'app e' personale e non va sul Play Store),
    // ma la password vive qui dentro, e vale la stessa regola della chiave: **non si cambia e
    // non si rigenera mai**, altrimenti ogni telefono deve essere disinstallato un'ultima volta.
    //
    // Una password sola, non due: il keystore e' PKCS12 e quel formato una password per la
    // chiave non ce l'ha (e' lo store a custodirla). `keytool` accetta `-keypass` e lo ignora
    // in silenzio, quindi una `keyPassword` diversa da `storePassword` fa fallire la firma con
    // "Given final block not properly padded".
    val signingPassword = "xB3TrNEcmGtz8Pk25nFsaX4MgIOQhWvD"

    signingConfigs {
        create("mtg") {
            storeFile = file("signing/mtg-lifecounter.jks")
            storePassword = signingPassword
            keyAlias = "mtg"
            keyPassword = signingPassword
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.mtg_lifecounter"
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

    buildTypes {
        // Anche la debug, e non solo la release: `flutter run` installa una build debug, e deve
        // poter aggiornare la stessa app che installa l'APK della release senza disinstallare
        // niente. Senza questa riga la debug resterebbe firmata col keystore di sistema
        // (`~/.android/debug.keystore`, la cui posizione dipende da `ANDROID_SDK_HOME`) e
        // tornerebbe la firma diversa.
        debug {
            signingConfig = signingConfigs.getByName("mtg")
        }
        release {
            signingConfig = signingConfigs.getByName("mtg")
        }
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
