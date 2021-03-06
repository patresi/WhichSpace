//
//  AppDelegate.swift
//  WhichSpace
//
//  Created by George on 27/10/2015.
//  Copyright © 2015 George Christou. All rights reserved.
//

import Cocoa
import Sparkle

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, SUUpdaterDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var application: NSApplication!
    @IBOutlet weak var workspace: NSWorkspace!
    @IBOutlet weak var updater: SUUpdater!

    let spacesMonitorFile = "~/Library/Preferences/com.apple.spaces.plist"

    let statusBarItem = NSStatusBar.systemStatusBar().statusItemWithLength(27)
    let conn = _CGSDefaultConnection()

    static var darkModeEnabled = false

    private func configureApplication() {
        application = NSApplication.sharedApplication()
        // Specifying `.Accessory` both hides the Dock icon and allows
        // the update dialog to take focus
        application.setActivationPolicy(.Accessory)
    }

    private func configureObservers() {
        workspace = NSWorkspace.sharedWorkspace()
        workspace.notificationCenter.addObserver(
            self,
            selector: "updateActiveSpaceNumber",
            name: NSWorkspaceActiveSpaceDidChangeNotification,
            object: workspace
        )
        NSDistributedNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "updateDarkModeStatus:",
            name: "AppleInterfaceThemeChangedNotification",
            object: nil
        )
    }

    private func configureMenuBarIcon() {
        updateDarkModeStatus()
        statusBarItem.button?.cell = StatusItemCell()
        statusBarItem.image = NSImage(named: "default")
        statusBarItem.menu = statusMenu
    }

    private func configureSparkle() {
        updater = SUUpdater.sharedUpdater()
        updater.delegate = self
        // Silently check for updates on launch
        updater.checkForUpdatesInBackground()
    }

    private func configureSpaceMonitor() {
        let fullPath = (spacesMonitorFile as NSString).stringByExpandingTildeInPath
        let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        let fildes = open(fullPath.cStringUsingEncoding(NSUTF8StringEncoding)!, O_EVTONLY)
        if fildes == -1 {
            NSLog("Failed to open file: \(spacesMonitorFile)")
            return
        }

        let source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, UInt(fildes), DISPATCH_VNODE_DELETE, queue)

        dispatch_source_set_event_handler(source) { () -> Void in
            let flags = dispatch_source_get_data(source)
            if (flags & DISPATCH_VNODE_DELETE != 0) {
                dispatch_source_cancel(source)
                self.updateActiveSpaceNumber()
                self.configureSpaceMonitor()
            }
        }

        dispatch_source_set_cancel_handler(source) { () -> Void in
            close(fildes)
        }

        dispatch_resume(source)
    }

    func updateDarkModeStatus(sender: AnyObject?=nil) {
        let dictionary = NSUserDefaults.standardUserDefaults().persistentDomainForName(NSGlobalDomain);
        if let interfaceStyle = dictionary?["AppleInterfaceStyle"] as? NSString {
            AppDelegate.darkModeEnabled = interfaceStyle.localizedCaseInsensitiveContainsString("dark")
        } else {
            AppDelegate.darkModeEnabled = false
        }
    }

    func applicationWillFinishLaunching(notification: NSNotification) {
        configureApplication()
        configureObservers()
        configureMenuBarIcon()
        configureSparkle()
        configureSpaceMonitor()
        updateActiveSpaceNumber()
    }

    func updateActiveSpaceNumber() {
        let info = CGSCopyManagedDisplaySpaces(conn)
        let displayInfo = info[0] as! NSDictionary
        let activeSpaceID = displayInfo["Current Space"]!["ManagedSpaceID"] as! Int
        let spaces = displayInfo["Spaces"] as! NSArray
        for (index, space) in spaces.enumerate() {
            let spaceID = space["ManagedSpaceID"] as! Int
            let spaceNumber = index + 1
            if spaceID == activeSpaceID {
                statusBarItem.button?.title = String(spaceNumber)
                return
            }
        }
    }

    func menuWillOpen(menu: NSMenu) {
        if let cell = statusBarItem.button?.cell as! StatusItemCell? {
            cell.isMenuVisible = true
        }
    }

    func menuDidClose(menu: NSMenu) {
        if let cell = statusBarItem.button?.cell as! StatusItemCell? {
            cell.isMenuVisible = false
        }
    }

    @IBAction func checkForUpdatesClicked(sender: NSMenuItem) {
        updater.checkForUpdates(sender)
    }

    @IBAction func quitClicked(sender: NSMenuItem) {
        NSApplication.sharedApplication().terminate(self)
    }
}
