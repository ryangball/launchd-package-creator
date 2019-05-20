//
//  ViewController.swift
//  simple-launchdaemon-creator
//
//  Created by Ryan Ball on 4/11/19.
//  Copyright © 2019 Ryan Ball. All rights reserved.
//

import Cocoa
import Foundation

var globalIdentifier: String = ""
var globalProgramArgs: String = ""
var globalTargetPath: String = ""
var globalTargetPathFileName: String = ""
var globalProgramArgsFull: Array = [""]
var globalRunAtLoad: Bool? = nil
var globalStartInterval: Int? = nil
var globalDaemonName: String = ""
var globalVersion: String = ""
var globalDestinationPath: String = ""
var globalDaemonType: String = ""
var globalDaemonFolderName: String = ""
var globalStandardOutPath: String? = nil
var globalStandardErrorPath: String? = nil
var globalPkgTempLocation: String = ""
var optionalRequiredFields = [String]()

class ViewController: NSViewController {

    @IBOutlet weak var daemonButton: NSButton!
    @IBOutlet weak var agentButton: NSButton!
    @IBOutlet weak var daemonIdentifier: NSTextField!
    @IBOutlet weak var daemonVersion: NSTextField!
    @IBOutlet weak var targetPath: NSTextField!
    @IBOutlet weak var programArgs: NSTextField!
    @IBOutlet weak var runAtLoad: NSButton!
    @IBOutlet weak var startInterval: NSButton!
    @IBOutlet weak var startIntervalSeconds: NSTextField!
    @IBOutlet weak var standardOutPathCheck: NSButton!
    @IBOutlet weak var standardOutPathField: NSTextField!
    @IBOutlet weak var standardErrorPathCheck: NSButton!
    @IBOutlet weak var standardErrorPathField: NSTextField!
    @IBOutlet weak var clearButton: NSButton!
    
    // Create arrays of fields/buttons to clear or disable when using the "Clear" button
    lazy var fieldsToClear: [NSTextField] = [self.daemonIdentifier, self.daemonVersion, self.programArgs, self.targetPath, self.startIntervalSeconds, self.standardOutPathField, self.standardErrorPathField]
    
    lazy var buttonsToClear: [NSButton] = [self.runAtLoad, self.startInterval, self.standardOutPathCheck, self.standardErrorPathCheck]
    
    lazy var fieldsToDisable: [NSTextField] = [self.startIntervalSeconds, self.standardOutPathField, self.standardErrorPathField]
    
    lazy var requiredFields: [NSTextField] = [self.daemonIdentifier, self.daemonVersion, self.targetPath]
    
    func dialogOK(title: String, message: String) -> Void {
        let dialogOK: NSAlert = NSAlert()
        dialogOK.messageText = title
        dialogOK.informativeText = message
        dialogOK.alertStyle = NSAlert.Style.warning
        dialogOK.addButton(withTitle: "OK")
        dialogOK.beginSheetModal(for: self.view.window!, completionHandler: nil)
        return
    }
    
    // Function that checks for empty required fields
    func checkRequiredFields() -> Bool {
        
        optionalRequiredFields = []
        
        // Determine our required fields
        for field in requiredFields {
            if field.stringValue.isEmpty {
                optionalRequiredFields.append(field.toolTip!)
            }
        }
        
        // If there are options selected, add their values as required
        if startInterval.state == NSControl.StateValue.on && startIntervalSeconds.stringValue.isEmpty {
            optionalRequiredFields.append(startIntervalSeconds.toolTip!)
        }
        
        if standardOutPathCheck.state == NSControl.StateValue.on && standardOutPathField.stringValue.isEmpty {
            optionalRequiredFields.append(standardOutPathField.toolTip!)
        }
        
        if standardErrorPathCheck.state == NSControl.StateValue.on && standardErrorPathField.stringValue.isEmpty {
            optionalRequiredFields.append(standardErrorPathField.toolTip!)
        }
        
        let dialogText = """
        Please complete all of the required fields to continue:
        
        \(optionalRequiredFields.joined(separator: "\n"))
        """
        
        if !optionalRequiredFields.isEmpty {
            dialogOK(title: "Fields Empty", message: dialogText)
            return true
        } else {
            return false
        }
    }
    
    func verifyStartInterval(value: String) -> Bool {
        let numberCharacters = NSCharacterSet.decimalDigits.inverted
        if value.rangeOfCharacter(from: numberCharacters) == nil {
            return true
        } else {
            dialogOK(title: "Invalid Characters", message: "Please use only digits in the Start Interval Seconds field.")
            return false
        }
    }
    
    func determineProgramArgs (userSelectedTarget:String) -> String {
        let targetExtension = NSURL(fileURLWithPath: userSelectedTarget).pathExtension
        
        if targetExtension == "" {
            programArgs.isEnabled = false
            programArgs.stringValue = ""
        } else if targetExtension == "app" {
            optionalRequiredFields.append(programArgs.toolTip!)
            programArgs.stringValue = String("/usr/bin/open");
        } else {
            do {
                optionalRequiredFields.append(programArgs.toolTip!)
                let targetContents = try String(contentsOfFile: userSelectedTarget)
                let linesOfTarget = targetContents.components(separatedBy: "\n")
                let shebang = String(linesOfTarget[0]);
                if shebang.contains ("bash") {
                    programArgs.stringValue = String("/bin/bash");
                } else if shebang.contains ("sh") {
                    programArgs.stringValue = String("/bin/sh");
                } else if shebang.contains ("python") {
                    programArgs.stringValue = String("/usr/bin/python");
                } else {
                    dialogOK(title: "Missing shebang", message: "Your script does not have a proper shebang as the first line. Either add a shebang into the script or manually configure the Program Arguments.")
                    targetPath.stringValue = ""
                }
            } catch {
                // bad things happened
            }
        }
        return programArgs.stringValue
    }
    
    
    @IBAction func daemonRadioAction(_ sender: Any) {
        if daemonButton.state == NSControl.StateValue.on {
            agentButton.state = NSControl.StateValue.off
            globalDaemonType = "daemon"
        }
    }
    
    @IBAction func agentRadioAction(_ sender: Any) {
        if agentButton.state == NSControl.StateValue.on {
            daemonButton.state = NSControl.StateValue.off
            globalDaemonType = "agent"
        }
    }
    
    @IBAction func selectTarget(_ sender: Any) {
        
        let fileOpenDialog = NSOpenPanel();

        fileOpenDialog.message                  = "Choose the file to be run by the \(globalDaemonType).";
        fileOpenDialog.showsResizeIndicator     = true;
        fileOpenDialog.showsHiddenFiles         = false;
        fileOpenDialog.showsTagField            = false;
        fileOpenDialog.canChooseDirectories     = false;
        fileOpenDialog.canCreateDirectories     = true;
        fileOpenDialog.allowsMultipleSelection  = false;
        fileOpenDialog.allowedFileTypes         = ["sh","py","app","bash", ""];
        fileOpenDialog.beginSheetModal(for: self.view.window!) { [weak self] (result) in
            if result == NSApplication.ModalResponse.OK {
                let result = fileOpenDialog.url // Pathname of the file
                
                if (result != nil) {
                    let path = result!.path
                    self!.targetPath.stringValue = path
                    self!.programArgs.stringValue = ""
                    _ = self!.determineProgramArgs(userSelectedTarget: self!.targetPath.stringValue)
                }
            } else {
                // User clicked on "Cancel"
                return
            }
        }
    }
    
    @IBAction func startIntervalAction(_ sender: Any) {
        if startInterval.state == NSControl.StateValue.on {
            startIntervalSeconds.isEnabled = true
        } else {
            startIntervalSeconds.stringValue = ""
            startIntervalSeconds.isEnabled = false
        }
    }
    
    @IBAction func standardOutPathAction(_ sender: Any) {
        if standardOutPathCheck.state == NSControl.StateValue.on {
            standardOutPathField.isEnabled = true
        } else {
            standardOutPathField.stringValue = ""
            standardOutPathField.isEnabled = false
        }
    }
    
    @IBAction func standardErrorPathAction(_ sender: Any) {
        if standardErrorPathCheck.state == NSControl.StateValue.on {
            standardErrorPathField.isEnabled = true
        } else {
            standardErrorPathField.stringValue = ""
            standardErrorPathField.isEnabled = false
        }
    }
    
    // Actions to take when the "Clear" button is pressed
    @IBAction func clearButtonAction(_ sender: Any) {
        
        for field in self.fieldsToClear { field.stringValue = "" }
        for button in self.buttonsToClear { button.state = NSControl.StateValue.off }
        for field in self.fieldsToDisable { field.isEnabled = false }
        daemonButton.state = NSControl.StateValue.on
        agentButton.state = NSControl.StateValue.off
        self.daemonIdentifier.becomeFirstResponder()
    }
    
    @IBAction func createDaemon(_ sender: AnyObject) {
        
        let anyRequredFieldsEmpty = checkRequiredFields()
        
        let startIntervalFieldIsValid = verifyStartInterval(value: startIntervalSeconds.stringValue)
        
        if anyRequredFieldsEmpty == false || startIntervalFieldIsValid == true {
            globalIdentifier = daemonIdentifier.stringValue
            globalVersion = daemonVersion.stringValue
            globalProgramArgs = programArgs.stringValue
            globalTargetPath = targetPath.stringValue
            if runAtLoad.state == NSControl.StateValue.on {
                globalRunAtLoad = true
            } else {
                globalRunAtLoad = nil
            }
            if startInterval.state == NSControl.StateValue.on {
                globalStartInterval = startIntervalSeconds.integerValue
            } else {
                globalStartInterval = nil
            }
            if globalDaemonType == "agent" {
                globalDaemonFolderName = "LaunchAgents"
            } else {
                globalDaemonFolderName = "LaunchDaemons"
            }
            if standardOutPathCheck.state == NSControl.StateValue.on {
                globalStandardOutPath = standardOutPathField.stringValue
            }
            if standardErrorPathCheck.state == NSControl.StateValue.on {
                globalStandardErrorPath = standardErrorPathField.stringValue
            }
            
            globalTargetPathFileName = (globalTargetPath as NSString).lastPathComponent
            if programArgs.stringValue != "" {
                globalProgramArgsFull = [globalProgramArgs, "/Library/Scripts/\(globalTargetPathFileName)"]
            } else {
                globalProgramArgsFull = ["/Library/Scripts/\(globalTargetPathFileName)"]
            }
            
            create_daemon().build()
            
            let fileSaveDialog = NSSavePanel();
            
            fileSaveDialog.message                  = "Choose a save location for the packaged \(globalDaemonType).";
            fileSaveDialog.showsResizeIndicator     = true;
            fileSaveDialog.showsHiddenFiles         = false;
            fileSaveDialog.showsTagField            = false;
            fileSaveDialog.canCreateDirectories     = true;
            fileSaveDialog.allowedFileTypes         = ["pkg"];
            fileSaveDialog.allowsOtherFileTypes     = false;
            fileSaveDialog.beginSheetModal(for: self.view.window!) { (result) in
                if result == NSApplication.ModalResponse.OK {
                    let result = fileSaveDialog.url // Pathname of the file

                    if (result != nil) {
                        let path = result!.path
                        globalDestinationPath = path
                        _ = extras().copyFile(source: globalPkgTempLocation, destination: globalDestinationPath)
                    } else {
                        // User clicked on "Cancel"
                        return
                    }
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        globalDaemonType = "daemon"
        startIntervalSeconds.isEnabled = false
        standardOutPathField.isEnabled = false
        standardErrorPathField.isEnabled = false
        self.daemonIdentifier.becomeFirstResponder()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

}
