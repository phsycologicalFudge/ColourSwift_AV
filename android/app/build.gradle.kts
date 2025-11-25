plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
        import java.io.FileInputStream

val localSigningFile = rootProject.file("local-signing.properties")
val hasLocalSigning = localSigningFile.exists()

val localSigningProps = Properties()
if (hasLocalSigning) {
    localSigningProps.load(FileInputStream(localSigningFile))
}

android {
    namespace = "com.colourswift.cssecurity"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.colourswift.cssecurity"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasLocalSigning) {
                keyAlias = localSigningProps["keyAlias"] as String
                keyPassword = localSigningProps["keyPassword"] as String
                storeFile = file(localSigningProps["storeFile"] as String)
                storePassword = localSigningProps["storePassword"] as String
            }
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false

            if (hasLocalSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.android.billingclient:billing-ktx:6.2.0")
}
