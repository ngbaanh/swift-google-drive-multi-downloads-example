//
//  DownloadedFileViewController.swift
//  GoogleDriveDownloader
//
//  Created by Bá Anh Nguyễn on 1/4/18.
//  Copyright © 2018 Bá Anh Nguyễn. All rights reserved.
//

import UIKit
import Material
import GoogleSignIn
import GoogleAPIClientForREST
import QuickLook

class DownloadedFileViewController: UIViewController {

    var tableView: UITableView!
    
    var downloadedFileURLs = [URL]()
    var downloadedFileItems = [CloudItem]()
    
    var downloadingFileItems = [CloudItem]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Downloads"
        
        tableView = UITableView(frame: view.bounds, style: .grouped)
        view.layout(tableView).edges()
        
        tableView.delegate = self
        tableView.dataSource = self
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateTable()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.DownloadCenter.DownloadDidCancel, object: nil, queue: nil) { (note) in
            self.updateTable()
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.DownloadCenter.DownloadDidFinish, object: nil, queue: nil) { (note) in
            self.updateTable()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.DownloadCenter.DownloadDidCancel, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.DownloadCenter.DownloadDidFinish, object: nil)
    }
    
    func updateTable() {
        downloadedFileItems.removeAll()
        downloadedFileURLs.removeAll()
        downloadingFileItems.removeAll()
        
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
            let fileList = try? FileManager.default.contentsOfDirectory(at: documentDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        {
            downloadedFileURLs = fileList
            fileList.forEach({ (url) in
                let name = url.lastPathComponent
                let id = ""
                let provider = DownloadCenterProvider.none
                let size = try? FileManager.default.attributesOfItem(atPath: url.path)[FileAttributeKey.size] as! Int64
                downloadedFileItems.append((id, name, size ?? 0, provider))
            })
        }
        
        downloadingFileItems = DownloadCenter.shared.fileItemArray
        
        tableView.reloadData()
    }
    
    
}

extension DownloadedFileViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? downloadingFileItems.count : downloadedFileItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = 0 == indexPath.section ? downloadingFileItems[indexPath.row] : downloadedFileItems[indexPath.row]
        let cell = CloudFileTableCell.init(cloudItem: item, style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = item.name
        cell.imageView?.image = #imageLiteral(resourceName: "file")
        if 0 == indexPath.section {
            
        } else {
            cell.accessoryView = nil
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if 0 == indexPath.section {
            
        } else {
            let url = downloadedFileURLs[indexPath.row] as NSURL
            if QLPreviewController.canPreview(url) {
                let quickLookController = QLPreviewController()
                quickLookController.delegate = self
                quickLookController.dataSource = self
                quickLookController.currentPreviewItemIndex = indexPath.row
                self.present(quickLookController, animated: true, completion: nil)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return 0 == indexPath.section ? false : true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let url = downloadedFileURLs[indexPath.row]
            try? FileManager.default.removeItem(at: url)
            updateTable()
        }
    }
    
}

extension DownloadedFileViewController: QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    
    @available(iOS 4.0, *)
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return downloadedFileURLs.count
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return downloadedFileURLs[index] as NSURL
    }
}
