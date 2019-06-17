//
//  create_daemon.swift
//  launchd-package-creator
//
//  Created by Ryan Ball on 4/23/19.
//  Copyright © 2019 Ryan Ball. All rights reserved.
//

import Foundation

var preferencesURL: URL!

struct Preferences: Codable {
    // Items that are required in the plist
    var Label: String
    var ProgramArguments: Array<String>
    
    // Items that are not required in the plist
    var RunAtLoad: Bool?
    var StartInterval: Int?
    var StandardOutPath: String?
    var StandardErrorPath: String?
    var LimitLoadToSessionType: String?
}

struct ComponentPlistRoot : Codable {
    let array : [ComponentPlist]
}

struct ComponentPlist: Codable {
    var BundleIsRelocatable: Bool
    var BundleIsVersionChecked: Bool
    var BundleOverwriteAction: String
    var RootRelativeBundlePath: String
}

public class create_daemon: NSObject {
    
    var uuid: String = ""
    var tempBuildDir: String = ""
    var baseTempDir: URL!
    var sessionTempDir: URL!
    var componentPlistURL: URL!
    var postInstallChownLines: String = ""
    
    public func build(buildType: String) {
        
        uuid = NSUUID().uuidString
        tempBuildDir = "com.github.ryangball.launchd-package-creator/\(uuid)"
        baseTempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        sessionTempDir = baseTempDir.appendingPathComponent(tempBuildDir, isDirectory: true)
        preferencesURL = sessionTempDir.appendingPathComponent("/root/Library/\(globalDaemonFolderName)/\(globalIdentifier).plist")
        componentPlistURL = sessionTempDir.appendingPathComponent("/build/component.plist")
        
        var subPaths = [
            "root/Library/\(globalDaemonFolderName)",
            "scripts",
            "build",
            ]
        
        if globalPackageTarget == true {
            subPaths.append("root/\((globalTargetPathInPlist as NSString).deletingLastPathComponent)")
        }
        
        subPaths.forEach { subPath in
            let url = sessionTempDir.appendingPathComponent(subPath)
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            } catch let error {
                print("error: \(error)")
            }
        }
        
        // Create the pkg postinstall script
        func createPostinstall() {
            if globalPackageTarget == true {
                postInstallChownLines = """
                chown -R root:wheel "\(globalTargetPathInPlist)"
                chmod -R 755 "\(globalTargetPathInPlist)"
                """
            } else {
                postInstallChownLines = ""
            }
            
            let postInstallText = """
            #!/bin/bash
            
            # Set permissions on launchd \(globalDaemonType) files
            chown root:wheel "/Library/\(globalDaemonFolderName)/\(globalIdentifier).plist"
            chmod 644 "/Library/\(globalDaemonFolderName)/\(globalIdentifier).plist"
            \(postInstallChownLines)
            
            exit 0
            """
            
            do {
                // create the destination url for the text file to be saved
                let fileURL = sessionTempDir.appendingPathComponent("scripts/postinstall")
                
                // Note: if you set atomically to true it will overwrite the file if it exists without a warning
                try postInstallText.write(to: fileURL, atomically: true, encoding: .utf8)
                
                // Set permissions on the postinstall
                var attributes = [FileAttributeKey : Any]()
                attributes[.posixPermissions] = 0o755
                do {
                    try FileManager.default.setAttributes(attributes, ofItemAtPath: fileURL.path)
                } catch let error {
                    print("Permissions error: ", error)
                }
            } catch {
                print("error:", error)
            }
        }
        
        // Create the component plist
        func createComponentPlist() {
            let preferencesToEncode = ComponentPlist(BundleIsRelocatable: false, BundleIsVersionChecked: false, BundleOverwriteAction: "upgrade", RootRelativeBundlePath: "\(globalTargetPathInPlist)")
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .xml
            do {
                let data = try encoder.encode([preferencesToEncode].self)
                try data.write(to: componentPlistURL)
            } catch {
                // Handle error
                print(error)
            }
        }
        
        // Copy the target script/app
        func copyTarget() {
            let destinationURL = sessionTempDir.appendingPathComponent("root/\(globalTargetPathInPlist)")
            _ = extras().copyFile(source: globalTargetPath, destination: destinationURL.path)
        }
    
        // Create the plist
        func createPlist() {
            let preferencesToEncode = Preferences(Label: globalIdentifier, ProgramArguments: globalProgramArgsFull, RunAtLoad: globalRunAtLoad, StartInterval: globalStartInterval, StandardOutPath: globalStandardOutPath, StandardErrorPath: globalStandardErrorPath, LimitLoadToSessionType: globalSessionType)
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .xml
            do {
                let data = try encoder.encode(preferencesToEncode)
                try data.write(to: preferencesURL)
            } catch {
                // Handle error
                print(error)
            }
        }
        
        // Create the .pkg using shell commands
        func createPKG() {
            @discardableResult
            func shell(_ args: String...) -> Int32 {
                let task = Process()
                task.launchPath = "/usr/bin/env"
                task.arguments = args
                task.launch()
                task.waitUntilExit()
                return task.terminationStatus
            }
            
            let pkgRoot = sessionTempDir.appendingPathComponent("/root/")
            let pkgScripts = sessionTempDir.appendingPathComponent("/scripts/")
            let pkgBuildDir = sessionTempDir.appendingPathComponent("build/")
            globalPkgTempLocation = "\(pkgBuildDir.path)/hello.pkg"
            
            // If we are packaging an app use a component plist, otherwise it is not needed
            if (usingApp == true) && (globalPackageTarget == true) {
                createComponentPlist()
                shell("/usr/bin/pkgbuild", "--quiet", "--root", "\(pkgRoot.path)", "--install-location", "/", "--scripts", "\(pkgScripts.path)", "--identifier", "\(globalIdentifier)", "--version", "\(globalVersion)", "--ownership", "recommended", "--component-plist", "\(componentPlistURL.path)", "\(globalPkgTempLocation)")
            } else {
                shell("/usr/bin/pkgbuild", "--quiet", "--root", "\(pkgRoot.path)", "--install-location", "/", "--scripts", "\(pkgScripts.path)", "--identifier", "\(globalIdentifier)", "--version", "\(globalVersion)", "--ownership", "recommended", "\(globalPkgTempLocation)")
            }
        }
        
        if buildType == "PKG" {
            createPostinstall()
            if globalPackageTarget == true {
                copyTarget()
            }
            createPlist()
            createPKG()
        } else if buildType == "Plist" {
            createPlist()
        }
    }
}
