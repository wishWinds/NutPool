//
//  NutPool.swift
//  NutPool
//
//  Created by shupeng on 2019/11/6.
//  Copyright © 2019 shupeng. All rights reserved.
//

import Foundation


public protocol Product {

}

public protocol Consumer {

}

public protocol Producer {
    func produceProduct(callback: @escaping NutPool.ProduceProductCallback) -> ()
}

public class Task {
    var name: String

    public init(_ name: String) {
        self.name = "com.nutPool.taskName." + name
    }
}

public class NutPool {
    var producer: Producer
    var maxProductCount: Int

    // 生产者
    var produceQueue: DispatchQueue = DispatchQueue(label: "com.nutPool.produceQueue") // 管理生产的Queue（派发生产任务)
    var produceSemaphore: DispatchSemaphore! // 可生产的信号

    // 消费者
    var consumeQueue: DispatchQueue = DispatchQueue(label: "com.nutPool.consumeQueue") // 管理消费任务的Queue, 并没有使用。考虑任务的执行最终要放到主队列。且任务执行和取消需要同步，所以都放在主线程中执行。因此任务的添加、取消、执行都放到主线程中
    var consumeOperationQuque: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        return queue
    }() // 存放消费任务的Operation Queue， 串行执行
    var consumeSemaphore = DispatchSemaphore(value: 0) // 可消费的信号

    // 商品
    var productList = [Product]()
    var productLock = NSLock()
    // 消费队列
    var pendingList = [[String: BlockOperation]]()
    var consumeOperaionLock = NSLock() // 由于任务的执行都在主线程中（串行）。因此不需要一个锁来锁定任务的执行和任务的其他操作。

    public typealias GetProductCallback = (Product) -> ()
    public typealias ProduceProductCallback = (Product) -> ()

    public init(producer: Producer, maxProductCount: Int = 10) {
        self.producer = producer
        self.maxProductCount = maxProductCount
        self.produceSemaphore = DispatchSemaphore(value: maxProductCount)

        self.start()
    }

    public func createGetProductTask(with key: String, callback: @escaping GetProductCallback) -> (Task) {

        let task = Task(key)
        DispatchQueue.syncMain {
            let operation = self.createConsumeOperation(callback)
            self.pendingList.append([task.name: operation])
            self.consumeOperationQuque.addOperation(operation)
        }
        return task
    }

    public func cancelGetProductTask(_ task: Task) {
        // 任务的状态：正在被添加->已添加(等待商品)->正在派发商品->商品派发完毕完毕
        DispatchQueue.syncMain {
            self.pendingList.forEach { (item) in
                if item.keys.first == task.name {
                    item.values.first?.cancel()
                }
            }

            self.pendingList.removeAll { (item) -> Bool in
                return item.keys.first == task.name
            }
        }
    }

    func start() -> () {
        self.produceQueue.async {
            while true {
                self.produceSemaphore.wait()
                // 考虑到生产者有可能没有进行并发生产。这里进行一下兼容
                DispatchQueue.global().async {
                    self.producer.produceProduct(callback: { (p) in
                        self.productLock.lock()
                        self.productList.append(p)
                        self.consumeSemaphore.signal()
                        self.productLock.unlock()
                    })
                }
            }
        }
    }

    func createConsumeOperation(_ callback: @escaping GetProductCallback) -> BlockOperation {
        let operation = BlockOperation()
        operation.addExecutionBlock {
            self.consumeSemaphore.wait()

            DispatchQueue.syncMain {
                if operation.isCancelled && operation.isFinished == false {
                    self.consumeSemaphore.signal()
                } else {
                    self.productLock.lock()
                    let product = self.productList.removeFirst()
                    self.productLock.unlock()
                    callback(product)
                    self.produceSemaphore.signal()
                }
            }
        }
        return operation
    }
}

extension DispatchQueue {
    class func syncMain(execute block: () -> Void) -> () {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.sync {
                block()
            }
        }
    }
}
