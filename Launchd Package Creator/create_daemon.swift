//
//  create_daemon.swift
//  simple-launchdaemon-creator
//
//  Created by Ryan Ball on 4/23/19.
//  Copyright © 2019 Ryan Ball. All rights reserved.
//

// import Cocoa
import Foundation

struct Preferences: Codable {
    // Items that are required in the plist
    var Label: String
    var ProgramArguments: Array<String>
    
    // Items that are not required in the plist
    var RunAtLoad: Bool?
    var StartInterval: Int?
    var StandardOutPath: String?
    var StandardErrorPath: String?
}

public class create_daemon {
    
    var uuid: String = ""
    var tempBuildDir: String = ""
    var baseTempDir: URL!
    var sessionTempDir: URL!
    
    public func build() {
        
        uuid = NSUUID().uuidString
        tempBuildDir = "com.github.ryangball.launchd-package-creator/\(uuid)"
        baseTempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        sessionTempDir = baseTempDir.appendingPathComponent(tempBuildDir, isDirectory: true)
        
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
            // get the documents folder url
            if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                // create the destination url for the text file to be saved
                let fileURL = sessionTempDir.appendingPathComponent("scripts/postinstall")
                
                // Note: if you set atomically to true it will overwrite the file if it exists without a warning
                try postInstallText.write(to: fileURL, atomically: true, encoding: .utf8)
                
                // Set permissions on the postinstall
                var attributes = [FileAttributeKey : Any]()
                attributes[.posixPermissions] = 0o755
                do {
                    try FileManager.default.setAttributes(attributes, ofItemAtPath: fileURL.path)
                }catch let error {
                    print("Permissions error: ", error)
                }
                
            }
        } catch {
            print("error:", error)
        }
        
        // Copy the target script/app
        let destinationURL = sessionTempDir.appendingPathComponent("root/Library/Scripts/\(globalTargetPathFileName)")
        do {
            try FileManager.default.copyItem(atPath: globalTargetPath, toPath: destinationURL.path)
        }
        catch let error as NSError {
            print("Ooops! Something went wrong: \(error)")
        }
    
        // Create the plist
        let preferencesURL = sessionTempDir.appendingPathComponent("/root/Library/\(globalDaemonFolderName)/\(globalIdentifier).plist")
        let preferencesToEncode = Preferences(Label: globalIdentifier, ProgramArguments: globalProgramArgsFull, RunAtLoad: globalRunAtLoad, StartInterval: globalStartInterval, StandardOutPath: globalStandardOutPath, StandardErrorPath: globalStandardErrorPath)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        do {
            let data = try encoder.encode(preferencesToEncode)
            try data.write(to: preferencesURL)
        } catch {
            // Handle error
            print(error)
        }
        
        // Create the .pkg
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
        
        
        shell("/usr/bin/pkgbuild", "--quiet", "--root", "\(pkgRoot.path)", "--install-location", "/", "--scripts", "\(pkgScripts.path)", "--identifier", "\(globalIdentifier)", "--version", "\(globalVersion)", "--ownership", "recommended", "\(globalPkgTempLocation)")
    }
}
