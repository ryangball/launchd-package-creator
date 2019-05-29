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
    
    public func build(buildType: String) {
        
        uuid = NSUUID().uuidString
        tempBuildDir = "com.github.ryangball.launchd-package-creator/\(uuid)"
        baseTempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        sessionTempDir = baseTempDir.appendingPathComponent(tempBuildDir, isDirectory: true)
        preferencesURL = sessionTempDir.appendingPathComponent("/root/Library/\(globalDaemonFolderName)/\(globalIdentifier).plist")
        componentPlistURL = sessionTempDir.appendingPathComponent("/build/component.plist")
        
        let subPaths = [
            "root/Library/\(globalDaemonFolderName)",
            "root/Library/Scripts",
            "scripts",
            "build",
            ]
        
        subPaths.forEach { subPath in
            let url = sessionTempDir.appendingPathComponent(subPath)
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
                //print("path created: \(url)")
            } catch let error {
                print("error: \(error)")
            }
        }
        
        // Create the pkg postinstall script
        func createPostinstall() {
            let postInstallText = """
            #!/bin/bash
            
            # Set permissions on LaunchDaemon and Script
            chown root:wheel "/Library/\(globalDaemonFolderName)/\(globalIdentifier).plist"
            chmod 644 "/Library/\(globalDaemonFolderName)/\(globalIdentifier).plist"
            chown -R root:wheel "/Library/Scripts/\(globalTargetPathFileName)"
            chmod -R 755 "/Library/Scripts/\(globalTargetPathFileName)"
            
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
        
//        func encodePlist(PlistData: String, Destination: URL) {
//            let preferencesToEncode = ComponentPlist(BundleIsRelocatable: false, BundleIsVersionChecked: false, BundleOverwriteAction: "upgrade", RootRelativeBundlePath: "/Library/Scripts/\(globalTargetPathFileName)")
//            let encoder = PropertyListEncoder()
//            encoder.outputFormat = .xml
//            do {
//                let data = try encoder.encode(preferencesToEncode)
//                try data.write(to: Destination)
//            } catch {
//                // Handle error
//                print(error)
//            }
//            // Code goes here
//        }
        
        func createComponentPlist() {
            let preferencesToEncode = ComponentPlist(BundleIsRelocatable: false, BundleIsVersionChecked: false, BundleOverwriteAction: "upgrade", RootRelativeBundlePath: "/Library/Scripts/\(globalTargetPathFileName)")
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
            let destinationURL = sessionTempDir.appendingPathComponent("root/Library/Scripts/\(globalTargetPathFileName)")
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
            
            shell("/usr/bin/pkgbuild", "--quiet", "--root", "\(pkgRoot.path)", "--install-location", "/", "--scripts", "\(pkgScripts.path)", "--identifier", "\(globalIdentifier)", "--version", "\(globalVersion)", "--ownership", "recommended", "--component-plist", "\(componentPlistURL.path)", "\(globalPkgTempLocation)")
        }
        
        if buildType == "PKG" {
            createPostinstall()
            createComponentPlist()
            copyTarget()
            createPlist()
            createPKG()
        } else if buildType == "Plist" {
            createPlist()
        }
        
    }
}
