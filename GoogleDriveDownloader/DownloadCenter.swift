//
//  DownloadCenter.swift
//  GoogleDriveDownloader
//
//  Created by Bá Anh Nguyễn on 1/4/18.
//  Copyright © 2018 Bá Anh Nguyễn. All rights reserved.
//

import Foundation
import GoogleAPIClientForREST
import GoogleSignIn

extension NSNotification.Name {
    struct DownloadCenter {
        public static let DownloadDidCancel = NSNotification.Name.init("DownloadCenter_DownloadDidCancel")
        public static let DownloadProgress = NSNotification.Name.init("DownloadCenter_DownloadProgress")
        public static let DownloadDidFinish = NSNotification.Name.init("DownloadCenter_DownloadDidFinish")
    }
}

enum DownloadCenterProvider {
    case googleDrive
    case dropbox
    case oneDrive
    
    case none
}

enum DownloadCenterKey: String {
    case fileId = "fileID"
    case progressValue = "progressValue"
    case downloadedFilePath = "downloadedFilePath"
}

typealias CloudItem = (id: String, name: String, size: Int64, provider: DownloadCenterProvider)

class DownloadCenter: NSObject {
    static let shared = DownloadCenter()
    
    private override init() {
        super.init()
        self.googleLoginIfNeeded()
    }
    
    fileprivate var googleService = GTLRDriveService()
    
    fileprivate var fileIdentifierArray = [String]()
    public fileprivate(set) var fileItemArray = [CloudItem]()
    fileprivate var downloadHandlerArray = [Any]()
    
    
    internal func isDownloading(fileId: String) -> Bool {
        return fileIdentifierArray.contains(fileId)
    }
    
    internal func stopDownloading(cloudItem: CloudItem) {
        let fileId = cloudItem.id
        if let index = fileIdentifierArray.index(of: fileId) {
            if cloudItem.provider == .googleDrive, let handler = downloadHandlerArray[index] as? GTMSessionFetcher {
                handler.stopFetching()
            }
            if cloudItem.provider == .dropbox {
                //...
            }
            
            // Post Notification & Clear
            NotificationCenter.default.post(name: NSNotification.Name.DownloadCenter.DownloadDidCancel, object: nil, userInfo: [DownloadCenterKey.fileId: fileId])
            fileIdentifierArray.remove(at: index)
            downloadHandlerArray.remove(at: index)
            fileItemArray.remove(at: index)
        }
    }
    
    internal func startDownload(cloudItem: CloudItem) {
        if !isDownloading(fileId: cloudItem.id) {
            if cloudItem.provider == .googleDrive {
                downloadFileFromGoogleDrive(cloudItem: cloudItem)
            }
            if cloudItem.provider == .dropbox {
                // ...
            }
            // ...
            
        }
    }
    
    
    
}

extension DownloadCenter: GIDSignInDelegate, GIDSignInUIDelegate {
    
    fileprivate func googleLoginIfNeeded() {
        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance().scopes = GOOGLE_SCOPES
        
        
        if GIDSignIn.sharedInstance().hasAuthInKeychain() {
            GIDSignIn.sharedInstance().signInSilently()
        } else {
            GIDSignIn.sharedInstance().signIn()
        }
    }
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!,
              withError error: Error!) {
        if let error = error {
            print("__ Authentication Error: \(error.localizedDescription)")
            self.googleService.authorizer = nil
        } else {
            print("__ Authentication Success")
            self.googleService.authorizer = user.authentication.fetcherAuthorizer()
        }
    }
    
    
    fileprivate func downloadFileFromGoogleDrive(cloudItem: CloudItem) {
        let fileId = cloudItem.id
        
        let temporaryFolder = URL.init(fileURLWithPath: NSTemporaryDirectory())
        let destinationFileURL = temporaryFolder.appendingPathComponent(fileId + ".download")
        
        let query = GTLRDriveQuery_FilesGet.queryForMedia(withFileId: fileId)
        
        let downloadRequest = googleService.request(for: query) as URLRequest
        let fetcher = googleService.fetcherService.fetcher(with: downloadRequest)
        fetcher.destinationFileURL = destinationFileURL
        NSLog("__ destinationFileURL: %@", destinationFileURL.path)
        
        
        fetcher.beginFetch { (data, error) in
            if let error = error {
                print("__ ERROR on fetching data: \(error.localizedDescription)")
            } else {
                NotificationCenter.default.post(name: NSNotification.Name.DownloadCenter.DownloadDidFinish, object: nil, userInfo: [DownloadCenterKey.fileId: fileId, DownloadCenterKey.downloadedFilePath: destinationFileURL.path])
            }
            self.stopDownloading(cloudItem: cloudItem)
        }
        
        fetcher.downloadProgressBlock = { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) in
            print((bytesWritten, totalBytesWritten, totalBytesExpectedToWrite))
            
            var fileSize = totalBytesExpectedToWrite
            
            if totalBytesExpectedToWrite < 0 { // URLRequest cannot estimate fileSize then take it from queried file info.
                fileSize = cloudItem.size
            }
            
            let progressValue = NSNumber(value: totalBytesWritten).floatValue / NSNumber(value: fileSize).floatValue
            print("__ progressValue = \(progressValue)")
            
            if progressValue < 1.0 {
                NotificationCenter.default.post(name: NSNotification.Name.DownloadCenter.DownloadProgress, object: nil, userInfo: [DownloadCenterKey.fileId: fileId, DownloadCenterKey.progressValue: progressValue])
            } else {
                NotificationCenter.default.post(name: NSNotification.Name.DownloadCenter.DownloadDidFinish, object: nil, userInfo: [DownloadCenterKey.fileId: fileId, DownloadCenterKey.downloadedFilePath: destinationFileURL.path])
                self.stopDownloading(cloudItem: cloudItem)
            }
            
            
        }
        
        self.fileIdentifierArray.append(fileId)
        self.downloadHandlerArray.append(fetcher)
        self.fileItemArray.append(cloudItem)
    }
}
