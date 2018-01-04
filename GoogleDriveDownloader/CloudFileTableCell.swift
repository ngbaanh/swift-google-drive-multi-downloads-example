//
//  CloudFileTableCell.swift
//  GoogleDriveDownloader
//
//  Created by Bá Anh Nguyễn on 1/4/18.
//  Copyright © 2018 Bá Anh Nguyễn. All rights reserved.
//

import Foundation
import UIKit
import GoogleAPIClientForREST

class CloudFileTableCell: UITableViewCell {
    var progressView: UIProgressView?
    var actionButton: UIButton!
    var item: CloudItem!
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    
    convenience init(cloudItem: CloudItem, style: UITableViewCellStyle, reuseIdentifier: String?) {
        self.init(style: style, reuseIdentifier: reuseIdentifier)
        
        item = cloudItem
        
        actionButton = UIButton.init(type: .roundedRect)
        actionButton.frame = CGRect.init(x: 0, y: 0, width: 32, height: 32)
        actionButton.setTitle("⬇️", for: .normal)
        actionButton.addTarget(self, action: #selector(actionButtonHandler), for: .touchUpInside)
        self.accessoryView = actionButton
        
        progressView = UIProgressView.init(progressViewStyle: .default)
        progressView?.isHidden = true
        self.layout(progressView!).top().left().right()
        prepareProgressView()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.DownloadCenter.DownloadDidCancel, object: nil, queue: nil) { (note) in
            if let fileId = note.userInfo?[DownloadCenterKey.fileId] as? String, fileId == self.item.id {
                self.finalizeDownload()
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.DownloadCenter.DownloadProgress, object: nil, queue: nil) { (note) in
            if let fileId = note.userInfo?[DownloadCenterKey.fileId] as? String, fileId == self.item.id {
                if let progressValue = note.userInfo?[DownloadCenterKey.progressValue] as? Float {
                    self.prepareProgressView(progressValue)
                }
                
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.DownloadCenter.DownloadDidFinish, object: nil, queue: nil) { (note) in
            if let fileId = note.userInfo?[DownloadCenterKey.fileId] as? String, fileId == self.item.id {
                if let downloadedFilePath = note.userInfo?[DownloadCenterKey.downloadedFilePath] as? String {
                    let downloadedFileUrl = URL.init(fileURLWithPath: downloadedFilePath)
                    if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                        let fileUrl = documentDirectory.appendingPathComponent(self.item.name)
                        try? FileManager.default.moveItem(at: downloadedFileUrl, to: fileUrl)
                    }
                }
                self.finalizeDownload()
            }
        }
        
    }
    
    fileprivate func finalizeDownload() { // On Finish / Cancel
        self.progressView?.isHidden = true
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.DownloadCenter.DownloadDidCancel, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.DownloadCenter.DownloadDidFinish, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.DownloadCenter.DownloadProgress, object: nil)
        actionButton.setTitle("⬇️", for: .normal)
    }
    
    fileprivate func prepareProgressView(_ progress: Float = 0) {
        if DownloadCenter.shared.isDownloading(fileId: item.id) {
            DispatchQueue.main.async {
                self.progressView?.isHidden = false
                self.progressView?.progress = progress
                self.actionButton.setTitle("⏹", for: .normal)
            }
            
        }
    }
    
    @objc fileprivate func actionButtonHandler() {
        if !DownloadCenter.shared.isDownloading(fileId: item.id) {
            let canDownload = true // if downloaded or not enough space, set this to FALSE
            if canDownload {
                DownloadCenter.shared.startDownload(cloudItem: item)
            }
        } else {
            DownloadCenter.shared.stopDownloading(cloudItem: item)
        }
    }
}

