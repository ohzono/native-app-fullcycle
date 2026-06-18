import ProjectDescription

let project = Project(
    name: "iosApp",
    targets: [
        .target(
            name: "iosApp",
            destinations: .iOS,
            product: .app,
            bundleId: "com.example.iosApp",
            deploymentTargets: .iOS("15.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [:],
                "CFBundleShortVersionString": "1.0",
                "CFBundleVersion": "1"
            ]),
            sources: ["Sources/**"],
            resources: [],
            scripts: [
                .pre(
                    script: """
                    cd "$SRCROOT/.."
                    ./gradlew :shared:embedAndSignAppleFrameworkForXcode
                    """,
                    name: "Embed KMP Framework",
                    basedOnDependencyAnalysis: false
                )
            ],
            settings: .settings(base: [
                "FRAMEWORK_SEARCH_PATHS": "$(inherited) $(SRCROOT)/../shared/build/xcode-frameworks/$(CONFIGURATION)/$(SDK_NAME)",
                "OTHER_LDFLAGS": "$(inherited) -framework Shared"
            ])
        )
    ]
)
