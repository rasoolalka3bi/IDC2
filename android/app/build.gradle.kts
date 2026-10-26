plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.idc.idc_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        // معرّف مختلف عن التطبيق الرسمي (com.idc.app) حتى يمكن تثبيت النسختين معًا للتجربة.
        applicationId = "com.idc.employee"
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

    // مفتاح توقيع ثابت حتى تُثبَّت كل نسخة جديدة فوق السابقة. يفك البناء على
    // GitHub الملف release.jks.enc بالسر IDC_SIGNING_KEY، وبدونه يُستخدم مفتاح
    // التجربة الذي يتغير مع كل بناء.
    val releaseStore = file("release.jks")
    val releasePassword = System.getenv("IDC_SIGNING_KEY")
    signingConfigs {
        if (releaseStore.exists() && !releasePassword.isNullOrEmpty()) {
            create("release") {
                storeFile = releaseStore
                storePassword = releasePassword
                keyAlias = "idc"
                keyPassword = releasePassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
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
