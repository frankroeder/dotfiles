//
//  now_playing.swift
//
//  Created by Frank Röder on 14.01.20.
//  Copyright © 2020 Frank Röder. All rights reserved.

import Foundation

class MediaInfo {

  // TODO: Replace with native API
  let currentTrackScript = """
        tell application "Music"
        if it is running then
          if player state is playing then
            set track_name to name of current track
            set artist_name to artist of current track
            if artist_name > 0
              set t to artist_name & " - " & track_name
              artist_name & " - " &    track_name
            else
              "~ " & track_name
            end if
          end if
        end if
        end tell
        """
  let maxLen = 32

  func runScript() -> String {
    var error: NSDictionary?
    if let scriptObject = NSAppleScript(source: currentTrackScript) {
      if let scriptOut = scriptObject.executeAndReturnError(&error).stringValue {
        return scriptOut
      } else if (error != nil) {
        print("error: ", error!)
      }
    }
    return ""
  }

  func parseArgs() -> Int {
    let arguments = CommandLine.arguments
    if arguments.count > 1{
      return Int(arguments[1])!
    }
    return 0
  }

  func formatTitle(titleStr: String, windowLen: Int) -> Substring {
    let strLen = titleStr.count
    let seconds = Calendar.current.component(.second, from: Date())
    let startidx = seconds  % (strLen - windowLen)
    let start = titleStr.index(titleStr.startIndex, offsetBy: startidx)
    let end = titleStr.index(titleStr.startIndex, offsetBy: startidx + windowLen + 1)
    let range = start..<end
    return titleStr[range]
  }

  func getTitleInfo() {
    let scriptOut = self.runScript()
    if self.parseArgs() >= 130 {
      if scriptOut.count > 64 {
        print(self.formatTitle(titleStr: scriptOut, windowLen: 60))
      } else {
        print(scriptOut)
      }
    } else {
      if scriptOut.count > maxLen {
        print(self.formatTitle(titleStr: scriptOut, windowLen: 28))
      } else {
        print(scriptOut)
      }
    }
  }
}

let mediainfo = MediaInfo()
mediainfo.getTitleInfo()
