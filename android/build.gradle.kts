allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    val action = { p: Project ->
        if (p.name == "blue_thermal_printer") { 
            val android = p.extensions.findByName("android")
            if (android != null) {
                try {
                     val getNamespace = android.javaClass.getMethod("getNamespace")
                     val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                     
                     if (getNamespace.invoke(android) == null) {
                         setNamespace.invoke(android, "id.kakzaki.blue_thermal_printer")
                         println("Antigravity: Forced namespace for blue_thermal_printer")
                     }
                } catch (e: Exception) {
                    println("Antigravity: Could not set namespace for ${p.name}: ${e.message}")
                }
            }
        }
    }

    if (project.state.executed) {
        action(project)
    } else {
        afterEvaluate(action)
    }
}