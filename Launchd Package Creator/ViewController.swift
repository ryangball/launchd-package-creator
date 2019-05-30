//
//  ViewController.swift
//  launchd-package-creator
//
//  Created by Ryan Ball on 4/11/19.
//  Copyright © 2019 Ryan Ball. All rights reserved.
//

import Cocoa
import Foundation
import AppKit

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
var globalSessionType: String? = nil
var emptyRequiredFields = [String]()
var usingApp: Bool = false

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
    @IBOutlet weak var sessionTypeOptions: NSPopUpButton!
    @IBOutlet weak var sessionTypeCheck: NSButton!
    @IBOutlet weak var programArgsOptLabel: NSTextField!
    
    // Create arrays of fields/buttons to clear or disable when using the "Clear" button
    lazy var fieldsToClear: [NSTextField] = [self.daemonIdentifier, self.daemonVersion, self.programArgs, self.targetPath, self.startIntervalSeconds, self.standardOutPathField, self.standardErrorPathField]
    
    lazy var buttonsToClear: [NSButton] = [self.runAtLoad, self.startInterval, self.standardOutPathCheck, self.standardErrorPathCheck, self.sessionTypeCheck, self.sessionTypeOptions]
    
    lazy var fieldsToDisable: [NSTextField] = [self.startIntervalSeconds, self.standardOutPathField, self.standardErrorPathField]
    
    lazy var alwaysRequiredFields: [NSTextField] = [self.daemonIdentifier, self.daemonVersion, self.targetPath]
    
    var sessionTypes: Array = [""]
    
    // Function to display a dialog with an OK button
    func dialogOK(title: String, message: String) -> Void {
        let dialogOK: NSAlert = NSAlert()
        dialogOK.messageText = title
        dialogOK.informativeText = message
        dialogOK.alertStyle = NSAlert.Style.warning
        dialogOK.addButton(withTitle: "OK")
        dialogOK.beginSheetModal(for: self.view.window!, completionHandler: nil)
        return
    }
    
    func fileSaveDialog(title: String, allowedFileTypes: Array<String>, source: String) {
        // Open the File Save dialog box
        let fileSaveDialog = NSSavePanel();
        fileSaveDialog.message                  = title;
        fileSaveDialog.showsResizeIndicator     = true;
        fileSaveDialog.showsHiddenFiles         = false;
        fileSaveDialog.showsTagField            = false;
        fileSaveDialog.canCreateDirectories     = true;
        fileSaveDialog.allowedFileTypes         = allowedFileTypes;
        fileSaveDialog.allowsOtherFileTypes     = false;
        fileSaveDialog.beginSheetModal(for: self.view.window!) { (result) in
            if result == NSApplication.ModalResponse.OK {
                let result = fileSaveDialog.url // Pathname of the file
                
                if (result != nil) {
                    let selectedPath = result!.path
                    //let destination = path
                    _ = extras().copyFile(source: source, destination: selectedPath)
                } else {
                    // User clicked on "Cancel"
                    return
                }
            }
        }
    }
    
    // Function that checks for empty required fields
    func checkRequiredFields() -> Bool {
        
        emptyRequiredFields = []
        
        // Determine which of our required fields are empty, if so add to our emptyRequiredFields array
        for field in alwaysRequiredFields {
            if field.stringValue.isEmpty {
                emptyRequiredFields.append(field.toolTip!)
            }
        }
        
        // If options are selected, make sure their associated values are populated, if not add to our emptyRequiredFields array
        if startInterval.state == NSControl.StateValue.on && startIntervalSeconds.stringValue.isEmpty {
            emptyRequiredFields.append(startIntervalSeconds.toolTip!)
        }
        
        if standardOutPathCheck.state == NSControl.StateValue.on && standardOutPathField.stringValue.isEmpty {
            emptyRequiredFields.append(standardOutPathField.toolTip!)
        }
        
        if standardErrorPathCheck.state == NSControl.StateValue.on && standardErrorPathField.stringValue.isEmpty {
            emptyRequiredFields.append(standardErrorPathField.toolTip!)
        }
        
        if programArgs.isEnabled == true && programArgs.stringValue.isEmpty {
            emptyRequiredFields.append(programArgs.toolTip!)
        }
        
        let dialogText = """
        Please complete all of the required fields to continue:
        
        \(emptyRequiredFields.joined(separator: "\n"))
        """
        
        if !emptyRequiredFields.isEmpty {
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
        // Make sure the program args field is enabled initially
        programArgs.isEnabled = true
        
        if targetExtension == "" {
            // We asume the target is a binary (no extension) so disable the program args field
            programArgs.isEnabled = false
            programArgs.stringValue = ""
            programArgsOptLabel.isHidden = false
            usingApp = false
        } else if targetExtension == "app" {
            // Target has a .app extensin and use set /usr/bin/open as the program args
            programArgs.stringValue = String("/usr/bin/open");
            usingApp = true
            programArgsOptLabel.isHidden = true
        } else {
            do {
                programArgsOptLabel.isHidden = true
                // We attempt to look at the shebang of the file to determine program args
                let targetContents = try String(contentsOfFile: userSelectedTarget)
                let linesOfTarget = targetContents.components(separatedBy: "\n")
                let shebang = String(linesOfTarget[0]);
                if shebang.contains ("bash") {
                    // shebang contains bash
                    programArgs.stringValue = String("/bin/bash");
                } else if shebang.contains ("sh") {
                    // shebang contains sh
                    programArgs.stringValue = String("/bin/sh");
                } else if shebang.contains ("python") {
                    // shebang contains python
                    programArgs.stringValue = String("/usr/bin/python");
                } else {
                    // Either no shebang or we don't know how to deal with the shebang in the file
                    dialogOK(title: "Missing shebang", message: "Your script does not have a proper shebang as the first line. Either add a shebang into the script and try again or manually configure the Program Arguments.")
                }
                usingApp = false
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
            
            // Populate LimitLoadToSessionType PopUp Button
            let sessionTypes: Array = ["System"]
            sessionTypeOptions.removeAllItems()
            for sessionType in sessionTypes {
                sessionTypeOptions.addItem(withTitle: sessionType)
            }
        }
    }
    
    @IBAction func agentRadioAction(_ sender: Any) {
        if agentButton.state == NSControl.StateValue.on {
            daemonButton.state = NSControl.StateValue.off
            globalDaemonType = "agent"
         
            // Populate LimitLoadToSessionType PopUp Button
            let sessionTypes: Array = ["Aqua", "Background", "LoginWindow", "StandardIO"]
            sessionTypeOptions.removeAllItems()
            for sessionType in sessionTypes {
                sessionTypeOptions.addItem(withTitle: sessionType)
            }
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
    
    @IBAction func sessionTypeCheckAction(_ sender: Any) {
        if sessionTypeCheck.state == NSControl.StateValue.on {
            sessionTypeOptions.isEnabled = true
        } else {
            sessionTypeOptions.isEnabled = false
            sessionTypeOptions.selectItem(at: 0)
        }
    }
    
    @IBAction func viewPlistButtonAction(_ sender: Any) {
        mostOfTheDaemonStuff(buildType: "Plist")
    }
    
    // Actions to take when the "Clear" button is pressed
    @IBAction func clearButtonAction(_ sender: Any) {
        
        for field in self.fieldsToClear { field.stringValue = "" }
        for button in self.buttonsToClear { button.state = NSControl.StateValue.off }
        for field in self.fieldsToDisable { field.isEnabled = false }
        daemonButton.state = NSControl.StateValue.on
        agentButton.state = NSControl.StateValue.off
        sessionTypeOptions.isEnabled = false
        sessionTypeOptions.selectItem(at: 0)
        programArgsOptLabel.isHidden = true
        
        // Populate LimitLoadToSessionType PopUp Button
        let sessionTypes: Array = ["System"]
        sessionTypeOptions.removeAllItems()
        for sessionType in sessionTypes {
            sessionTypeOptions.addItem(withTitle: sessionType)
        }
        
        self.daemonIdentifier.becomeFirstResponder()
    }
    
    func mostOfTheDaemonStuff(buildType: String) {
        let anyRequredFieldsEmpty = checkRequiredFields()
        
        let startIntervalFieldIsValid = verifyStartInterval(value: startIntervalSeconds.stringValue)
        
        // If no required fields are empty and the start interval field is valid then continue
        if anyRequredFieldsEmpty == false && startIntervalFieldIsValid == true {
            globalIdentifier = daemonIdentifier.stringValue
            globalVersion = daemonVersion.stringValue
            globalProgramArgs = programArgs.stringValue
            globalTargetPath = targetPath.stringValue
            
            // Determine state of runAtLoad Checkbox, populate value for plist
            if runAtLoad.state == NSControl.StateValue.on {
                globalRunAtLoad = true
            } else {
                globalRunAtLoad = nil
            }
            
            // Determine state of startInterval checkbox, populate value for plist
            if startInterval.state == NSControl.StateValue.on {
                globalStartInterval = startIntervalSeconds.integerValue
            } else {
                globalStartInterval = nil
            }
            
            // Determine if user has selected LaunchDaemon or LaunchAgent, set a global type so we know which directory to place the plist
            if globalDaemonType == "agent" {
                globalDaemonFolderName = "LaunchAgents"
            } else {
                globalDaemonFolderName = "LaunchDaemons"
            }
            
            // Determine state of standardOutPath checkbox, populate value for plist
            if standardOutPathCheck.state == NSControl.StateValue.on {
                globalStandardOutPath = standardOutPathField.stringValue
            }
            
            // Determine state of standardErrorPath checkbox, populate value for plist
            if standardErrorPathCheck.state == NSControl.StateValue.on {
                globalStandardErrorPath = standardErrorPathField.stringValue
            }
            
            // Determine state of sessionType checkbox, populate value for plist
            if sessionTypeCheck.state == NSControl.StateValue.on {
                globalSessionType = sessionTypeOptions.titleOfSelectedItem
            } else {
                globalSessionType = nil
            }
            
            // Determine the filename of the target app/script, build the program args array for plist
            globalTargetPathFileName = (globalTargetPath as NSString).lastPathComponent
            if programArgs.stringValue != "" {
                globalProgramArgsFull = [globalProgramArgs, "/Library/Scripts/\(globalTargetPathFileName)"]
            } else {
                globalProgramArgsFull = ["/Library/Scripts/\(globalTargetPathFileName)"]
            }
            
            // Let the user know LaunchAgent/LimitLoadToSessionType: Aqua is preferred for .apps
            if (usingApp == true) && (globalDaemonType == "agent") && (globalSessionType != "Aqua") || (usingApp == true) && (globalDaemonType == "daemon") {
                
                // Display the alert
                let dialogCustomButton = NSAlert()
                dialogCustomButton.messageText = "Are you sure?"
                dialogCustomButton.informativeText = "When targeting a GUI application it is recommended to use a LaunchAgent with LimitLoadToSessionType: Aqua"
                dialogCustomButton.alertStyle = .warning
                dialogCustomButton.addButton(withTitle: "Create \(buildType) Anyway")
                dialogCustomButton.addButton(withTitle: "Cancel")
                // Include "Do not show this message again" option in future release
                // dialogCustomButton.showsSuppressionButton = true
                dialogCustomButton.beginSheetModal(for: self.view.window!, completionHandler: { (NSModalResponse) -> Void in
                    if (NSModalResponse == NSApplication.ModalResponse.alertSecondButtonReturn) {
                        // User clicked the cancel button
                        return
                    } else if (NSModalResponse == NSApplication.ModalResponse.alertFirstButtonReturn) {
                        // User clicked the continue button
                        create_daemon().build(buildType: buildType)
                        // If the intention is to build a PKG, then show the save dialog
                        //if buildType == "PKG" { _ = self.fileSaveDialog() }
                        //if buildType == "Plist" { NSWorkspace.shared.openFile(preferencesURL.path, withApplication: "TextEdit") }
                        if buildType == "Plist" {
                            self.fileSaveDialog(title: "Choose a save location for the launchd plist.", allowedFileTypes: ["plist"], source: preferencesURL.path)
                        }
                        if buildType == "PKG" {
                            self.fileSaveDialog(title: "Choose a save location for the packaged \(globalDaemonType).", allowedFileTypes: ["pkg"], source: globalPkgTempLocation)
                        }
                    }
                })
            } else {
                create_daemon().build(buildType: buildType)
                // If the intention is to build a PKG, then show the save dialog
                //if buildType == "PKG" { _ = self.fileSaveDialog() }
                //if buildType == "Plist" { NSWorkspace.shared.openFile(preferencesURL.path, withApplication: "TextEdit") }
                if buildType == "Plist" {
                    self.fileSaveDialog(title: "Choose a save location for the launchd plist.", allowedFileTypes: ["plist"], source: preferencesURL.path)
                }
                if buildType == "PKG" {
                    self.fileSaveDialog(title: "Choose a save location for the packaged \(globalDaemonType).", allowedFileTypes: ["pkg"], source: globalPkgTempLocation)
                }
            }
        } else {
            return
        }
    }
    
    @IBAction func createDaemon(_ sender: AnyObject) {
        // This will build the PKG and prompt for a save location
        mostOfTheDaemonStuff(buildType: "PKG")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        globalDaemonType = "daemon"
        programArgsOptLabel.isHidden = true
        startIntervalSeconds.isEnabled = false
        standardOutPathField.isEnabled = false
        standardErrorPathField.isEnabled = false
        sessionTypeOptions.isEnabled = false
        
        // Populate LimitLoadToSessionType PopUp Button
        let sessionTypes: Array = ["System"]
        sessionTypeOptions.autoenablesItems = false
        sessionTypeOptions.removeAllItems()
        for sessionType in sessionTypes {
            sessionTypeOptions.addItem(withTitle: sessionType)
        }
        
        // Set focus to Identifier field
        self.daemonIdentifier.becomeFirstResponder()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}
