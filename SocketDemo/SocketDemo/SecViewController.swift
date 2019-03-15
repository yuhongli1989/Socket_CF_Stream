//
//  SecViewController.swift
//  SocketDemo
//
//  Created by yunfu on 2018/11/7.
//  Copyright © 2018 yunfu. All rights reserved.
//

import UIKit

class SecViewController: UIViewController,StreamDelegate {
    
    
    lazy var autoInputStreamPtr:AutoreleasingUnsafeMutablePointer<InputStream?> = {
        let ptr = UnsafeMutablePointer<InputStream>.allocate(capacity: 1)
        return AutoreleasingUnsafeMutablePointer<InputStream?>.init(ptr)
    }()
    
    lazy var autoOutStreamPtr:AutoreleasingUnsafeMutablePointer<OutputStream?> = {
        let ptr = UnsafeMutablePointer<OutputStream>.allocate(capacity: 1)
        return AutoreleasingUnsafeMutablePointer<OutputStream?>.init(ptr)
    }()

    let queue = DispatchQueue(label: "socket")
    
    lazy var readStreamPtr:UnsafeMutablePointer<Unmanaged<CFReadStream>?> = {
        
        return UnsafeMutablePointer<Unmanaged<CFReadStream>?>.allocate(capacity: 1)
    }()
    
    lazy var writeStreamPtr:UnsafeMutablePointer<Unmanaged<CFWriteStream>?> = {
        return UnsafeMutablePointer<Unmanaged<CFWriteStream>?>.allocate(capacity: 1)
    }()
    var context : CFStreamClientContext!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Unmanaged.passRetained(self).toOpaque()
        
    }
    

    @IBAction func click(_ sender: Any) {
        
        connect()
        
//        free(p)
        
    }
    
    
    func connect()  {
        //自定义队列
        queue.async {
            
            self.connectStar()
            //默认关闭 开启RunLoop
            RunLoop.current.run()
            
        }
    }
    
    func connectStar()  {
        //回调用到的指针
        let selfPtr = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<SecViewController>.size, alignment: MemoryLayout<SecViewController>.alignment)
        //回调指针存储self 在self中回调
        selfPtr.storeBytes(of: self, as: SecViewController.self)
        
        // 上下文
        context = CFStreamClientContext(version: 0, info: selfPtr, retain: nil, release: nil, copyDescription: nil)
        
        let host = "127.0.0.1" as CFString
        // 基于 host 端口 创建 readStream 和 writeStream
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, host, 8888, readStreamPtr, writeStreamPtr)

        //监听类型
        let flags = CFStreamEventType.hasBytesAvailable.rawValue | CFStreamEventType.endEncountered.rawValue | CFStreamEventType.errorOccurred.rawValue
        
        let p = withUnsafePointer(to: context!) { (ptr)  in
            
            return UnsafeMutablePointer<CFStreamClientContext>(mutating: ptr)
        }
        
        guard let readStream = readStreamPtr.pointee?.takeRetainedValue() else {
            print("readStream===失败")
            return
        }
        //添加回调
        if CFReadStreamSetClient(readStream, flags, { (rStream, eventType, ptr) in
            //ReadStream 回调 ptr为保存self的回调指针
            if let kkkk = ptr?.load(as: SecViewController.self){
                kkkk.streamBack(rStream, eventType)
            }
        }, p) {
            //ReadStream 存在 加入运行循环中
            CFReadStreamScheduleWithRunLoop(readStream, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes)
            
        }else{
            
            print("CFReadStreamSetClient===失败")
            return
        }
        //打开ReadStream
        if CFReadStreamOpen(readStream) == false {
            
            print("不能读")
            
            let error = CFReadStreamCopyError(readStream)
            if error != nil{
                CFErrorGetCode(error)
            }
            
            return
        }
        
    }

    func streamBack(_ stream:CFReadStream?,_ event:CFStreamEventType)  {
        guard let readStream = stream else {
            return
        }
        switch event {
        case CFStreamEventType.hasBytesAvailable:
            while (CFReadStreamHasBytesAvailable(readStream)){
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
                
                let bufferCount = CFReadStreamRead(readStream, buffer, MemoryLayout.size(ofValue: buffer)*1024)
                
                let data = Data(bytes: UnsafeRawPointer(buffer), count: bufferCount)
                
                let str = String(data: data, encoding: .utf8)
                print("str===\(String(describing: str))")
                
                free(buffer)
            }
            
            break
        case CFStreamEventType.errorOccurred:
            print("error")
            break
        case CFStreamEventType.endEncountered:
            CFReadStreamUnscheduleFromRunLoop(readStream, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes)
            CFRunLoopStop(CFRunLoopGetCurrent())
            
            break
        default:
            break
        }
        
    }
    
    @IBAction func click2(_ sender: Any) {
        
        queue.async {
            self.socket2()
            RunLoop.current.run()
        }
        
    }
    
    func socket2()  {
        Stream.getStreamsToHost(withName: "127.0.0.1", port: 8888, inputStream: autoInputStreamPtr, outputStream: autoOutStreamPtr)
        
        guard let inputStream = autoInputStreamPtr.pointee,let outPutStream = autoOutStreamPtr.pointee else {
            return
        }
        
        inputStream.delegate = self
        inputStream.schedule(in: RunLoop.current, forMode: .common)
        inputStream.open()
        
        
        outPutStream.delegate = self
        outPutStream.schedule(in: RunLoop.current, forMode: .common)
        outPutStream.open()
    }
    
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event){
        
        
        switch eventCode {
        case Stream.Event.hasBytesAvailable:
            if let readStream = aStream as? InputStream{
                
                let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
                
                let numByteRead = readStream.read(ptr, maxLength: MemoryLayout.size(ofValue: ptr)*1024)
                
                if numByteRead > 0{
                    let data = Data(bytes: UnsafeRawPointer(ptr), count: numByteRead)
                    
                    let str = String(data: data, encoding: .utf8)
                    
                    print("str====\(str)")
                }
                
                free(ptr)
                
            }else if let writeStream = aStream as? OutputStream{
                print("写入")
                
                
            }
            
            
            break
        default:
            break
        }
    }
    
    
    @IBAction func click3(_ sender: Any) {
        
        guard let outPutStream = autoOutStreamPtr.pointee else {
            return
        }
        let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
        let string = "哈哈"
        let data = string.data(using: .utf8)
        data?.copyBytes(to: ptr, count: data!.count)

        outPutStream.write(ptr, maxLength: data!.count)
    }
    
}
