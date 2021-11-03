//
//  BookOperation.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 8/30/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation
import IDZSwiftCommonCrypto
import ZipArchive

/**
 Process files located at a specific `URL`, renames it with the hash and moves it to the specified destination folder.
 The new file maintains the extension of the original `URL`
 */

public class ImportOperation: Operation {
  public let files: [URL]
  public let dataManager: DataManager
  public var processedFiles = [URL]()

  private let lockQueue = DispatchQueue(label: "com.swiftlee.asyncoperation", attributes: .concurrent)

  public override var isAsynchronous: Bool {
    return true
  }

  private var _isExecuting: Bool = false
  public override private(set) var isExecuting: Bool {
    get {
      return lockQueue.sync { () -> Bool in
        return _isExecuting
      }
    }
    set {
      willChangeValue(forKey: "isExecuting")
      lockQueue.sync(flags: [.barrier]) {
        _isExecuting = newValue
      }
      didChangeValue(forKey: "isExecuting")
    }
  }

  private var _isFinished: Bool = false
  public override private(set) var isFinished: Bool {
    get {
      return lockQueue.sync { () -> Bool in
        return _isFinished
      }
    }
    set {
      willChangeValue(forKey: "isFinished")
      lockQueue.sync(flags: [.barrier]) {
        _isFinished = newValue
      }
      didChangeValue(forKey: "isFinished")
    }
  }

  init(files: [URL], dataManager: DataManager) {
    self.files = files
    self.dataManager = dataManager
  }

  public override func start() {
    isFinished = false
    isExecuting = true
    main()
  }

  func finish() {
    isExecuting = false
    isFinished = true
  }

  func getInfo() -> [String: String] {
    var dictionary = [String: Int]()
    for file in self.files {
      dictionary[file.pathExtension] = (dictionary[file.pathExtension] ?? 0) + 1
    }
    var finalInfo = [String: String]()
    for (key, value) in dictionary {
      finalInfo[key] = "\(value)"
    }

    return finalInfo
  }

  func handleZip(file: URL, remainingFiles: [URL]) {
    // Unzip to temporary directory
    let documentsURL = DataManager.getDocumentsFolderURL()

    let tempDirectoryURL = try! FileManager.default.url(
      for: .itemReplacementDirectory,
         in: .userDomainMask,
         appropriateFor: documentsURL,
         create: true
    )

    SSZipArchive.unzipFile(atPath: file.path, toDestination: tempDirectoryURL.path, progressHandler: nil) { _, success, error in
      try? FileManager.default.removeItem(at: file)

      guard success else {
        self.processFile(from: remainingFiles)
        return
      }

      let enumerator = FileManager.default.enumerator(
        at: tempDirectoryURL,
        includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey],
        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: { (url, error) -> Bool in
          print("directoryEnumerator error at \(url): ", error)
          return true
        })!

      var files = [URL]()
      for case let fileURL as URL in enumerator {
        files.append(fileURL)
      }

      self.processFile(from: remainingFiles + files)
    }
  }

  func getNextAvailableURL(for url: URL) -> URL {
    guard FileManager.default.fileExists(atPath: url.path)  else {
      return url
    }

    let destinationBaseURL = DataManager.getProcessedFolderURL()
    let filename = url.deletingPathExtension().lastPathComponent
    let fileExt = url.pathExtension

    // set initial state for new file name
    var newFileName = ""
    var counter = 0
    var mutableURL = destinationBaseURL.appendingPathComponent(url.lastPathComponent)

    while FileManager.default.fileExists(atPath: mutableURL.path) {
      counter += 1
      newFileName = "\(filename)-\(counter)"

      if !fileExt.isEmpty {
        newFileName += ".\(fileExt)"
      }

      mutableURL = destinationBaseURL.appendingPathComponent(newFileName)
    }

    return mutableURL
  }

  private func hasExistingBook(_ fileURL: URL) -> Bool {
    guard let existingBook = self.dataManager.findBooks(containing: fileURL)?.first,
       let existingFileURL = existingBook.fileURL,
       !FileManager.default.fileExists(atPath: existingFileURL.path) else { return false }

    do {
      // create parent folder if it doesn't exist
      let parentFolder = existingFileURL.deletingLastPathComponent()

      if !FileManager.default.fileExists(atPath: parentFolder.path) {
        try FileManager.default.createDirectory(at: parentFolder, withIntermediateDirectories: true, attributes: nil)
      }

      try FileManager.default.moveItem(at: fileURL, to: existingFileURL)
      try (existingFileURL as NSURL).setResourceValue(URLFileProtection.none, forKey: .fileProtectionKey)
    } catch {
      fatalError("Fail to move file from \(fileURL) to \(existingFileURL)")
    }

    return true
  }

  public override func main() {
    self.processFile(from: self.files)
  }

  func processFile(from files: [URL]) {
    var mutableFiles = files
    guard !mutableFiles.isEmpty else {
      return self.finish()
    }

    let currentFile = mutableFiles.removeFirst()

    guard !self.hasExistingBook(currentFile) else {
      return processFile(from: mutableFiles)
    }

    NotificationCenter.default.post(name: .processingFile, object: nil, userInfo: ["filename": currentFile.lastPathComponent])

    guard currentFile.pathExtension != "zip" else {
      self.handleZip(file: currentFile, remainingFiles: mutableFiles)
      return
    }

    let destinationURL = self.getNextAvailableURL(for: currentFile)

    do {
      try FileManager.default.moveItem(at: currentFile, to: destinationURL)
      destinationURL.disableFileProtection()
    } catch {
      fatalError("Fail to move file from \(currentFile) to \(destinationURL)")
    }

    self.processedFiles.append(destinationURL)
    self.processFile(from: mutableFiles)
  }
}