plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "com.msc.fingenius"
    compileSdk = 35

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // Must match google-services.json package_name (validated in Phase 0 audit).
        applicationId = "com.msc.fingenius"
        minSdk = 24 // gradient VectorDrawables + ML Kit; Android 7.0+
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO(operator): create android/key.properties + upload keystore for Play.
            // Debug signing keeps `flutter build appbundle` working for assessment demos.
            signingConfig = signingConfigs.getByName("debug")

            // Minification is OFF, deliberately.
            //
            // With R8 on, every profile-photo upload killed the app the moment
            // the cropper opened — release only, debug was fine:
            //
            //   java.lang.NullPointerException
            //     at l.g.inflate(SourceFile:25)
            //     at com.yalantis.ucrop.UCropActivity.onCreateOptionsMenu(...)
            //
            // The menu resource was verified present in the APK (136 ucrop_*
            // resources survive), so this is class minification of uCrop and
            // its AppCompat dependencies, not resource shrinking. A native
            // Activity crash cannot be caught from Dart, so no amount of
            // defensive code in AvatarService can contain it.
            //
            // `proguard-rules.pro` keeps the libraries that are known to
            // resolve types reflectively, and those rules are retained below so
            // minification can be switched back on and validated on-device
            // later. Until that has actually been tested on hardware, shipping
            // a build that reliably works beats one that is 20MB smaller and
            // crashes on a core feature.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
