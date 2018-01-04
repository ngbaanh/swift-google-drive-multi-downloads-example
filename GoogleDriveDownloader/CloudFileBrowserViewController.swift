//
//  CloudFileBrowserViewController.swift
//  GoogleDriveDownloader
//
//  Created by Bá Anh Nguyễn on 1/4/18.
//  Copyright © 2018 Bá Anh Nguyễn. All rights reserved.
//

import UIKit
import Material
import GoogleSignIn
import GoogleAPIClientForREST

let GOOGLE_SCOPES: [String] = [kGTLRAuthScopeDrive, kGTLRAuthScopeDriveFile]

class CloudFileBrowserViewController: UIViewController {

    var tableView: UITableView!
    var logoutButton: UIBarButtonItem!
    
    fileprivate var service = GTLRDriveService()
    
    var currentFolderId: String = "" // root
    
    var fileItems = [CloudItem]()
    var folderItems = [CloudItem]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView = UITableView(frame: view.bounds, style: .grouped)
        view.layout(tableView).edges()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        logoutButton = UIBarButtonItem.init(title: "Logout", style: .done, target: self, action: #selector(logout))
        
        if currentFolderId == "" {
            navigationItem.leftBarButtonItem = UIBarButtonItem.init(title: "Downloads", style: .done, target: self, action: #selector(gotoDownloads))
        }
        
        loginIfNeeded()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        tableView.reloadData()
    }
    
    func gotoDownloads() {
        let vc = DownloadedFileViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func loginIfNeeded() {
        navigationItem.rightBarButtonItem = UIBarButtonItem.init(title: "loading...", style: .plain, target: self, action: nil)
        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance().scopes = GOOGLE_SCOPES
        
        if GIDSignIn.sharedInstance().hasAuthInKeychain() {
            GIDSignIn.sharedInstance().signInSilently()
        } else {
            GIDSignIn.sharedInstance().signIn()
        }
    }
    
    func logout() {
        if GIDSignIn.sharedInstance().hasAuthInKeychain() {
            GIDSignIn.sharedInstance().signOut()
            navigationController?.popToRootViewController(animated: true)
        }
    }
    
    func fetchDataFromDrive() {
        print("fetchDataFromDrive")
        
        folderItems.removeAll()
        fileItems.removeAll()
        
        let query = GTLRDriveQuery_FilesList.query()
        query.pageSize = 100
        service.shouldFetchNextPages = true
        
        if currentFolderId == "" { // Root
            query.q = "trashed=false"
        } else {
            query.q = "'\(currentFolderId)' in parents and trashed=false"
        }
        query.fields = "files(id, mimeType, name, parents, createdTime, size)"
        
        
        self.service.executeQuery(query) { (ticket, dataObject, error) in
            if let error = error {
                print("__ executeQuery Error: \(error.localizedDescription)")
                return
            }
            
            let result = dataObject as! GTLRDrive_FileList
            
            if let files = result.files, !files.isEmpty {
                for file in files {
                    let item = CloudItem(id: file.identifier ?? "-",
                                         name: file.name ?? "NoName",
                                         size: file.size?.int64Value ?? 0,
                                         provider: DownloadCenterProvider.googleDrive)
                    if "application/vnd.google-apps.folder" == file.mimeType {
                        self.folderItems.append(item)
                    } else {
                        self.fileItems.append(item)
                    }
                }
            }
            
            self.tableView.reloadData()
        }
        
    }
    
    func gotoFolder(for item: CloudItem) {
        let nextVC = CloudFileBrowserViewController()
        nextVC.title = item.name
        nextVC.currentFolderId = item.id
        navigationController?.pushViewController(nextVC, animated: true)
    }
    
}

extension CloudFileBrowserViewController: GIDSignInDelegate, GIDSignInUIDelegate {
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!,
              withError error: Error!) {
        if let error = error {
            print("__ Authentication Error: \(error.localizedDescription)")
            self.service.authorizer = nil
            
            navigationItem.rightBarButtonItem = nil
            
        } else {
            print("__ Authentication Success")
            self.service.authorizer = user.authentication.fetcherAuthorizer()
            self.fetchDataFromDrive()
            
            navigationItem.rightBarButtonItem = logoutButton
            
        }
    }
}

extension CloudFileBrowserViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? folderItems.count : fileItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if 0 == indexPath.section {
            let item = folderItems[indexPath.row]
            let cell = UITableViewCell.init(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = item.name
            cell.imageView?.image = #imageLiteral(resourceName: "folder")
            return cell
        } else {
            let item = fileItems[indexPath.row]
            let cell = CloudFileTableCell.init(cloudItem: item, style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = item.name
            cell.imageView?.image = #imageLiteral(resourceName: "file")
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if 0 == indexPath.section {
            gotoFolder(for: folderItems[indexPath.row])
        } else {
            
        }
    }
    
}
