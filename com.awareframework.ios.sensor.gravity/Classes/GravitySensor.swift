//
//  GravitySensor.swift
//  com.aware.ios.sensor.gravity
//
//  Created by Yuuki Nishiyama on 2018/11/01.
//

import UIKit
import CoreMotion
import SwiftyJSON
import com_awareframework_ios_sensor_core

extension Notification.Name{
    public static let actionAwareGravity      = Notification.Name(GravitySensor.ACTION_AWARE_GRAVITY)
    public static let actionAwareGravityStart = Notification.Name(GravitySensor.ACTION_AWARE_GRAVITY_START)
    public static let actionAwareGravityStop  = Notification.Name(GravitySensor.ACTION_AWARE_GRAVITY_STOP)
    public static let actionAwareGravitySetLabel = Notification.Name(GravitySensor.ACTION_AWARE_GRAVITY_SET_LABEL)
    public static let actionAwareGravitySync  = Notification.Name(GravitySensor.ACTION_AWARE_GRAVITY_SYNC)
}

public protocol GravityObserver{
    func onChanged(data:GravityData)
}

public extension GravitySensor{
    public static let TAG = "AWARE::Gravity"
    
    public static let ACTION_AWARE_GRAVITY = "ACTION_AWARE_GRAVITY"
    
    public static let ACTION_AWARE_GRAVITY_START = "com.awareframework.android.sensor.gravity.SENSOR_START"
    public static let ACTION_AWARE_GRAVITY_STOP = "com.awareframework.android.sensor.gravity.SENSOR_STOP"
    
    public static let ACTION_AWARE_GRAVITY_SET_LABEL = "com.awareframework.android.sensor.gravity.ACTION_AWARE_GRAVITY_SET_LABEL"
    public static let EXTRA_LABEL = "label"
    
    public static let ACTION_AWARE_GRAVITY_SYNC = "com.awareframework.android.sensor.gravity.SENSOR_SYNC"
}

public class GravitySensor: AwareSensor {
    var CONFIG = Config()
    var motion = CMMotionManager()
    var LAST_DATA:CMDeviceMotion?
    var LAST_TS:Double   = 0.0
    var LAST_SAVE:Double = 0.0
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
        public var interval: Int = 5
        
        /**
         * Period to save data in minutes. (optional)
         */
        public var period: Double = 1
        
        /**
         * Gravity threshold (float).  Do not record consecutive points if
         * change in value is less than the set value.
         */
        public var threshold: Double = 0.0
        
        public override init(){}
        public init(_ init:JSON){
            
        }
        
        public func apply(closure:(_ config: GravitySensor.Config) -> Void) -> Self{
            closure(self)
            return self
        }
    }
    
    override convenience init(){
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
            self.motion.deviceMotionUpdateInterval = 1.0/Double(CONFIG.interval)
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
                    
                    if let observer = self.CONFIG.sensorObserver {
                        observer.onChanged(data: data)
                    }
                    
                    self.dataBuffer.append(data)
                    
                    if currentTime > self.LAST_SAVE + (self.CONFIG.period * 60) {
                        return
                    }
                    
                    let dataArray = Array(self.dataBuffer)
                    self.dbEngine?.save(dataArray, GravityData.TABLE_NAME)
                    self.notificationCenter.post(name: .actionAwareGravity, object: nil)
                    
                    self.dataBuffer.removeAll()
                    self.LAST_SAVE = currentTime
                }
            }
            self.notificationCenter.post(name: .actionAwareGravityStart, object: nil)
        }
    }
    
    public override func stop() {
        if motion.isMagnetometerAvailable && motion.isMagnetometerActive {
            motion.stopMagnetometerUpdates()
            self.notificationCenter.post(name: .actionAwareGravityStop, object: nil)
        }
    }
    
    public override func sync(force: Bool = false) {
        if let engine = self.dbEngine {
            engine.startSync(GravityData.TABLE_NAME, DbSyncConfig.init().apply{config in
                config.debug = self.CONFIG.debug
            })
            self.notificationCenter.post(name: .actionAwareGravitySync, object: nil)
        }
    }
}
