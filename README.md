# GopherPath

A native macOS Gopher client written in Objective-C and AppKit.

## Build

Open `GopherPath.xcodeproj` in Xcode and run the **GUIGopher** scheme.

Enter a `gopher://` address in the toolbar (or a hostname such as `gopher.floodgap.com`) and press Return. The client parses Gopher menus, opens text documents, prompts for type 7 searches, saves binary and image items, opens Gopher `h` URL links in the default browser, and keeps back/forward navigation history. Use the star in the toolbar to add or remove a bookmark; bookmarks persist between launches and appear in the sidebar alongside the current session's history.

Menu items open with a single click. Long titles wrap onto additional lines, and hovered or keyboard-selected rows receive visible feedback.

While a request is running, the toolbar shows a spinner and a Stop control. Failed requests offer a retry action. The Navigate menu provides `⌘[` / `⌘]` for history, `⌘R` to reload, Escape to stop, and `⌘L` to focus the address bar.
