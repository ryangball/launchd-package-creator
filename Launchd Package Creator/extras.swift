//
//  dialog.swift
//  launchd-package-creator
//
//  Created by Ryan Ball on 4/15/19.
//  Copyright © 2019 Ryan Ball. All rights reserved.
//

import Cocoa
import Foundation

public class extras {
    
    // Generate a generic warning with OK button
//    public func dialogOK(question: String, text: String) -> Bool {
//        let dialogOK: NSAlert = NSAlert()
//        dialogOK.messageText = question
//        dialogOK.informativeText = text
//        dialogOK.alertStyle = NSAlert.Style.warning
//        dialogOK.addButton(withTitle: "OK")
//        return dialogOK.runModal() == .alertFirstButtonReturn
//    }
    
    public func copyFile(source: String, destination: String) -> Bool {
        do {
            if FileManager.default.fileExists(atPath: destination) {
                try FileManager.default.removeItem(at: URL(string: "file://\(destination)")!)
            }
            try FileManager.default.copyItem(atPath: source, toPath: destination)
        } catch let error as NSError {
            print("Cannot copy item at \(source) to \(destination): \(error)")
            return false
        }
        return true
    }
    
    
}
