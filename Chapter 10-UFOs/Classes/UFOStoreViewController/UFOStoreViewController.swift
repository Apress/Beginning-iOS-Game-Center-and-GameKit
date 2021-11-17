//
//  UFOStoreViewController.swift
//  UFOs
//
//  Created by Kyle Richter on 8/19/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

import UIKit
import StoreKit

class UFOStoreViewController: UIViewController {
    var productsRequest: SKProductsRequest?
    var productArray: [SKProduct]?
    
    @IBOutlet var storeTable: UITableView!
    
    // MARK: - View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        SKPaymentQueue.default().add(self)
        
        guard SKPaymentQueue.canMakePayments() else {
            let alert = UIAlertController.init(title: "", message: "Unable to make purchases with this device.", preferredStyle: .alert)
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        let productIdentifiers: Set<String> = [
            "com.dragonforged.ufo.newShip1",
            "com.dragonforged.ufo.subscription",
            "com.dragonforged.ufo.newShip2"
        ]
        let productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productsRequest.delegate = self
        productsRequest.start()
        self.productsRequest = productsRequest
    }
    
    @IBAction func dismiss() {
        dismiss(animated: true, completion: nil)
    }
}

extension UFOStoreViewController: SKPaymentTransactionObserver {
    func recordTransactionData(_ transaction: SKPaymentTransaction?) {
        if let app = Bundle.main.appStoreReceiptURL {
            if (try? Data(contentsOf: app)) == nil {
                return
            }
        }
        
        var transactions = UserDefaults.standard.object(forKey: "transactions") as? [Any] as? [AnyHashable]
        
        //    [transactionArray addObject: transaction.transactionReceipt];
        if let app = Bundle.main.appStoreReceiptURL, let data = try? Data(contentsOf: app) {
            transactions?.append(data)
        }
        
        UserDefaults.standard.set(transactions, forKey: "transactions")
    }
    
    func unlockContent(_ productId: String?) {
        switch productId {
        case "com.dragonforged.ufo.newShip1":
            UserDefaults.standard.set(true, forKey: "shipPlusAvailable")
        case "com.dragonforged.ufo.subscription":
            UserDefaults.standard.set(true, forKey: "subscriptionAvailable")
        case .some(let unknown):
            print("Unrecognized productId:", unknown)
        case .none:
            break
        }
    }
    
    func finish(_ transaction: SKPaymentTransaction, withSuccess success: Bool) {
        SKPaymentQueue.default().finishTransaction(transaction)
        if success {
            print("Transaction was successful:", transaction)
        } else {
            print("Transaction was unsuccessful:", transaction)
        }
    }
    
    func transactionDidComplete(_ transaction: SKPaymentTransaction) {
        recordTransactionData(transaction)
        unlockContent(transaction.payment.productIdentifier)
        finish(transaction, withSuccess: true)
    }
    
    func transactionDidRestore(_ transaction: SKPaymentTransaction) {
        recordTransactionData(transaction.original)
        unlockContent(transaction.original?.payment.productIdentifier)
        finish(transaction, withSuccess: true)
    }
    
    func transactionDidFail(_ transaction: SKPaymentTransaction) {
        if let error = transaction.error as? SKError, error.code == SKError.Code.paymentCancelled {
            SKPaymentQueue.default().finishTransaction(transaction)
        } else {
            finish(transaction, withSuccess: false)
        }
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchasing:
                print("Purchasing:", transaction)
            case .purchased:
                transactionDidComplete(transaction)
            case .failed:
                transactionDidFail(transaction)
            case .restored:
                transactionDidRestore(transaction)
            case .deferred:
                print("Deferred:", transaction)
            @unknown default:
                print("Unhandled case:", transaction)
            }
        }
    }
}

extension UFOStoreViewController: SKProductsRequestDelegate {
    // MARK: - Store Delegate
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        for product in response.products {
            print("Product title:", product.localizedTitle)
            print("Product description:", product.localizedDescription)
            print("Product price:", product.price)
            print("Product id:", product.productIdentifier)
            print("\n\n")
        }
        
        for invalidProduct in response.invalidProductIdentifiers {
            print("Invalid product identifier: \(invalidProduct)")
        }
        
        productArray = response.products
        storeTable.reloadData()
        productsRequest = nil
    }
}

extension UFOStoreViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let product = productArray?[indexPath.row] else {
            return
        }
        
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
}

extension UFOStoreViewController: UITableViewDataSource {
    static var currencyFormatter: NumberFormatter = {
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        return currencyFormatter
    }()
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return productArray?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell
            
        if let dequeuedCell = tableView.dequeueReusableCell(withIdentifier: "Cell") {
            cell = dequeuedCell
        } else {
            let subtitleCell = UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
            subtitleCell.selectionStyle = .none
            cell = subtitleCell
        }
        
        let cellText: String
        let cellDetailText: String
        
        if let product = productArray?[indexPath.row] {
            Self.currencyFormatter.locale = product.priceLocale
            let priceText = Self.currencyFormatter.string(from: product.price)
            let titleComponents = [product.localizedTitle, priceText]
            cellText = titleComponents.compactMap{ $0 }.joined(separator: " - ")
            cellDetailText = product.localizedDescription
        } else {
            cellText = "Unknown Product"
            cellDetailText = ""
        }
        
        cell.textLabel?.text = cellText
        cell.detailTextLabel?.text = cellDetailText
        
        return cell
    }
}
