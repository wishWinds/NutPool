//
//  ViewController.swift
//  Test
//
//  Created by shupeng on 2019/11/6.
//  Copyright © 2019 shupeng. All rights reserved.
//

import UIKit
import NutPool

class ViewController: UIViewController, UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!
    var pool: NutPool!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let producer = TestProducer()
        self.pool = NutPool(producer: producer)
        self.tableView.register(TestCell.self, forCellReuseIdentifier: "TestCell")
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1000
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TestCell") as! TestCell
        
        cell.configWith(index: indexPath.row, pool: self.pool)
        
        return cell
    }
}

struct TestProduct: Product {
    var name: String
}

class TestProducer: Producer {
    func produceProduct(callback: @escaping NutPool.ProduceProductCallback) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            let product = TestProduct(name: "dummy")
            callback(product)
        }
    }
}

class TestCell: UITableViewCell {
    static var staticIndex = 0
    var originIndex = -1
    var originTask: Task?
    
    func configWith(index: Int, pool: NutPool) -> () {
        let index = TestCell.staticIndex;
        TestCell.staticIndex += 1;
        self.textLabel?.text = String(index)
        if originIndex != -1,
            let task = self.originTask {
            pool.cancelGetProductTask(task)
        }
        
        originTask = pool.createGetProductTask(with: String(index)) { (p) in
            if index != self.originIndex {
                
            }
            if self.textLabel?.text?.contains("dummy") ?? false {
                
            }
            if let testP = p as? TestProduct {
                self.textLabel?.text = self.textLabel?.text?.appending(testP.name)
            }
        }

        self.originIndex = index
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.textLabel?.text = ""
    }
}
