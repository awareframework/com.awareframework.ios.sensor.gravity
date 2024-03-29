//
//  GravitySensor.swift
//  com.aware.ios.sensor.gravity
//
//  Created by Yuuki Nishiyama on 2018/11/01.
//

import UIKit
import CoreMotion
import com_awareframework_ios_sensor_core

extension Notification.Name{
    public static let actionAwareGravity      = Notification.Name(GravitySensor.ACTION_AWARE_GRAVITY)
    public static let actionAwareGravityStart = Notification.Name(GravitySensor.ACTION_AWARE_GRAVITY_START)
    public static let actionAwareGravityStop  = Notification.Name(GravitySensor.ACTION_AWARE_GRAVITY_STOP)
    public static let actionAwareGravitySetLabel = Notification.Name(GravitySensor.ACTION_AWARE_GRAVITY_SET_LABEL)
    public static let actionAwareGravitySync  = Notification.Name(GravitySensor.ACTION_AWARE_GRAVITY_SYNC)
    public static let actionAwareGravitySyncCompletion  = Notification.Name(GravitySensor.ACTION_AWARE_GRAVITY_SYNC_COMPLETION)
}

public protocol GravityObserver{
    func onDataChanged(data:GravityData)
}

public extension GravitySensor{
    static let TAG = "AWARE::Gravity"
    
    static let ACTION_AWARE_GRAVITY = "ACTION_AWARE_GRAVITY"
    
    static let ACTION_AWARE_GRAVITY_START = "com.awareframework.ios.sensor.gravity.SENSOR_START"
    static let ACTION_AWARE_GRAVITY_STOP = "com.awareframework.ios.sensor.gravity.SENSOR_STOP"
    
    static let ACTION_AWARE_GRAVITY_SET_LABEL = "com.awareframework.ios.sensor.gravity.ACTION_AWARE_GRAVITY_SET_LABEL"
    static let EXTRA_LABEL = "label"
    
    static let ACTION_AWARE_GRAVITY_SYNC = "com.awareframework.ios.sensor.gravity.SENSOR_SYNC"
    static let ACTION_AWARE_GRAVITY_SYNC_COMPLETION = "com.awareframework.ios.sensor.gravity.SENSOR_SYNC_COMPLETION"
    static let EXTRA_STATUS = "status"
    static let EXTRA_ERROR = "error"
}

public class GravitySensor: AwareSensor {
    public var CONFIG = Config()
    var motion = CMMotionManager()
    var LAST_DATA:CMDeviceMotion?
    var LAST_TS:Double   = Date().timeIntervalSince1970
    var LAST_SAVE:Double = Date().timeIntervalSince1970
    public var dataBuffer = Array<GravityData>()
    
    public class Config:SensorConfig{
        /**
         * For real-time observation of the sensor data collection.
         */
        public var sensorObserver: GravityObserver?
        
        /**
         * Gravity interval in hertz per second: e.g.
         *
         * 0 - fastest
         * 1 - sample per second
         * 5 - sample per second
         * 20 - sample per second
         */
        public var frequency: Int = 5
        
        /**
         * Period to save data in minutes. (optional)
         */
        public var period: Double = 1
        
        /**
         * Gravity threshold (float).  Do not record consecutive points if
         * change in value is less than the set value.
         */
        public var threshold: Double = 0.0
        
        public override init() {
            super.init()
            dbPath = "aware_gravity"
        }
        
        public override func set(config: Dictionary<String, Any>) {
            super.set(config: config)
            
            if let frequency = config["frequency"] as? Int {
                self.frequency = frequency
            }
            
            if let period = config["period"] as? Double {
                self.period = period
            }
            
            if let threshold = config["threshold"] as? Double {
                self.threshold = threshold
            }
        }
        
        public func apply(closure:(_ config: GravitySensor.Config) -> Void) -> Self{
            closure(self)
            return self
        }
    }
    
    public override convenience init(){
        self.init(GravitySensor.Config())
    }
    
    public init(_ config: GravitySensor.Config){
        super.init()
        self.CONFIG = config
        self.initializeDbEngine(config: config)
        if config.debug{ print(GravitySensor.TAG, "Gravity sensor is created.") }
    }
    
    public override func start() {
        if self.motion.isDeviceMotionAvailable && !self.motion.isDeviceMotionActive{
            self.motion.deviceMotionUpdateInterval = 1.0/Double(CONFIG.frequency)
            self.motion.startDeviceMotionUpdates(to: .main) { (deviceMotionData, error) in
                if let motionData = deviceMotionData {
                    let x = motionData.gravity.x
                    let y = motionData.gravity.y
                    let z = motionData.gravity.z
                    if let lastData = self.LAST_DATA {
                        if self.CONFIG.threshold > 0 &&
                            abs(x - lastData.gravity.x) < self.CONFIG.threshold &&
                            abs(y - lastData.gravity.y) < self.CONFIG.threshold &&
                            abs(z - lastData.gravity.z) < self.CONFIG.threshold {
                            return
                        }
                    }
                    
                    self.LAST_DATA = motionData
                    
                    let currentTime:Double = Date().timeIntervalSince1970
                    self.LAST_TS = currentTime
                    
                    let data = GravityData()
                    data.timestamp = Int64(currentTime*1000)
                    data.x = motionData.gravity.x
                    data.y = motionData.gravity.y
                    data.z = motionData.gravity.z
                    data.eventTimestamp = Int64(motionData.timestamp*1000)
                    data.label = self.CONFIG.label
                    
                    if let observer = self.CONFIG.sensorObserver {
                        observer.onDataChanged(data: data)
                    }
                    
                    self.dataBuffer.append(data)
                    
                    // print(currentTime - self.LAST_SAVE + (self.CONFIG.period * 60))
                    if currentTime < self.LAST_SAVE + (self.CONFIG.period * 60) {
                        return
                    }
                    
                    let dataArray = Array(self.dataBuffer)
                    
                    let queue = DispatchQueue(label:"com.awareframework.ios.sensor.gravity.save.queue")
                    queue.async {
                        if let engine = self.dbEngine {
                            engine.save(dataArray) { error in
                                if error == nil {
                                    DispatchQueue.main.async {
                                        self.notificationCenter.post(name: .actionAwareGravity, object: self)
                                    }
                                }else{
                                    if self.CONFIG.debug {
                                        if let e = error {
                                            print(GravitySensor.TAG, e.localizedDescription)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    self.dataBuffer.removeAll()
                    self.LAST_SAVE = currentTime
                }
            }
            self.notificationCenter.post(name: .actionAwareGravityStart, object: self)
        }
    }
    
    public override func stop() {
        if motion.isDeviceMotionAvailable && motion.isDeviceMotionActive {
            motion.stopMagnetometerUpdates()
            self.notificationCenter.post(name: .actionAwareGravityStop, object: self)
        }
    }
    
    public override func sync(force: Bool = false) {
        if let engine = self.dbEngine {
            engine.startSync(GravityData.TABLE_NAME, GravityData.self, DbSyncConfig.init().apply{config in
                config.debug = self.CONFIG.debug
                config.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.gravity.sync.queue")
                config.completionHandler = { (status, error) in
                    var userInfo: Dictionary<String,Any> = ["status":status]
                    if let e = error {
                        userInfo["error"] = e
                    }
                    self.notificationCenter.post(name: .actionAwareGravitySyncCompletion,
                                                 object: self,
                                                 userInfo:userInfo)
                }
            })
            self.notificationCenter.post(name: .actionAwareGravitySync, object: self)
        }
    }
    
    public override func set(label:String){
        self.CONFIG.label = label
        self.notificationCenter.post(name:.actionAwareGravitySetLabel, object:nil, userInfo:[GravitySensor.EXTRA_LABEL:label])
    }
}
