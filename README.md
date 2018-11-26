# AWARE: Gravity

[![CI Status](https://img.shields.io/travis/awareframework/com.awareframework.ios.sensor.gravity.svg?style=flat)](https://travis-ci.org/awareframework/com.awareframework.ios.sensor.gravity)
[![Version](https://img.shields.io/cocoapods/v/com.awareframework.ios.sensor.gravity.svg?style=flat)](https://cocoapods.org/pods/com.awareframework.ios.sensor.gravity)
[![License](https://img.shields.io/cocoapods/l/com.awareframework.ios.sensor.gravity.svg?style=flat)](https://cocoapods.org/pods/com.awareframework.ios.sensor.gravity)
[![Platform](https://img.shields.io/cocoapods/p/com.awareframework.ios.sensor.gravity.svg?style=flat)](https://cocoapods.org/pods/com.awareframework.ios.sensor.gravity)

This sensor module allows us to access the current **gravity vector** data. The gravity acceleration vector expressed in the device's reference frame. Also, the total acceleration of the device is equal to gravity plus the acceleration the user imparts to the device ([userAcceleration](https://developer.apple.com/documentation/coremotion/cmdevicemotion/1616149-useracceleration)). The data is provided by CMDeviceMotion in Core Motion library. Please check the link below for details.

[ Apple | Getting Processed Device-Motion Data ](https://developer.apple.com/documentation/coremotion/getting_processed_device-motion_data)
[ Apple | CMDeviceMotion | gravity ](https://developer.apple.com/documentation/coremotion/cmdevicemotion/1616164-gravity)

## Requirements
iOS 10 or later

## Installation

com.awareframework.ios.sensor.gravity is available through [CocoaPods](https://cocoapods.org). 

1. To install it, simply add the following line to your Podfile:
```ruby
pod 'com.awareframework.ios.sensor.gravity'
```
2. Import com.awareframework.ios.sensor.gravity library into your source code.
```swift
import com_awareframework_ios_sensor_gravity
```
## Public functions

### GravitySensor

+ `init(config:GravitySensor.Config?)` : Initializes the gravity sensor with the optional configuration.
+ `start()`: Starts the gyroscope sensor with the optional configuration.
+ `stop()`: Stops the service.

### GravitySensor.Config

Class to hold the configuration of the sensor.

#### Fields
+ `sensorObserver: GravityObserver`: Callback for live data updates.
+ `frequency: Int`: Data samples to collect per second (Hz). (default = 5)
+ `period: Double`: Period to save data in minutes. (default = 1)
+ `threshold: Double`: If set, do not record consecutive points if change in value is less than the set value.
+ `enabled: Boolean` Sensor is enabled or not. (default = `false`)
+ `debug: Boolean` enable/disable logging to Xcode console. (default = `false`)
+ `label: String` Label for the data. (default = "")
+ `deviceId: String` Id of the device that will be associated with the events and the sensor. (default = "")
+ `dbEncryptionKey` Encryption key for the database. (default = `null`)
+ `dbType: Engine` Which db engine to use for saving data. (default = `Engine.DatabaseType.NONE`)
+ `dbPath: String` Path of the database. (default = "aware_gyroscope")
+ `dbHost: String` Host for syncing the database. (default = `null`)

## Broadcasts

### Fired Broadcasts

+ `GravitySensor.ACTION_AWARE_GYROSCOPE` fired when gyroscope saved data to db after the period ends.

### Received Broadcasts

+ `GravitySensor.ACTION_AWARE_GRAVITY_START`: received broadcast to start the sensor.
+ `GravitySensor.ACTION_AWARE_GRAVITY_STOP`: received broadcast to stop the sensor.
+ `GravitySensor.ACTION_AWARE_GRAVITY_SYNC`: received broadcast to send sync attempt to the host.
+ `GravitySensor.ACTION_AWARE_GRAVITY_SET_LABEL`: received broadcast to set the data label. Label is expected in the `GravitySensor.EXTRA_LABEL` field of the intent extras.

## Data Representations

### Gravity Data

Contains the raw sensor data.

| Field     | Type   | Description                                                     |
| --------- | ------ | --------------------------------------------------------------- |
| x         | Double  | value of X axis                                                 |
| y         | Double  | value of Y axis                                                 |
| z         | Double  | value of Z axis                                                 |
| label     | String | Customizable label. Useful for data calibration or traceability |
| deviceId  | String | AWARE device UUID                                               |
| label     | String | Customizable label. Useful for data calibration or traceability |
| timestamp | Int64   | unixtime milliseconds since 1970                                |
| timezone  | Int    | Raw timezone offset of the device                          |
| os        | String | Operating system of the device (ex. ios)                    |


## Example usage
```swift
var gravitySensor = GravitySensor.init(GravitySensor.Config().apply{config in
    config.debug = true
    config.dbType = .REALM
    config.sensorObserver = Observer()
    config.interval = 1
})
gravitySensor.start()
```

```swift
class Observer:GravityObserver{
    func onDataChanged(data: GravityData) {
        // Your code here..
    }
}
```

## Author

Yuuki Nishiyama, tetujin@ht.sfc.keio.ac.jp

## License

Copyright (c) 2018 AWARE Mobile Context Instrumentation Middleware/Framework (http://www.awareframework.com)

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0 Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
