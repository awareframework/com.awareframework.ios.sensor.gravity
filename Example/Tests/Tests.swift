import XCTest
import RealmSwift
import com_awareframework_ios_sensor_gravity
import com_awareframework_ios_sensor_core

class Tests: XCTestCase {
    

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        Realm.Configuration.defaultConfiguration.inMemoryIdentifier = self.name
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSensingFrequency(){
        
        #if targetEnvironment(simulator)
        print("This test requires a real device.")
        
        #else
        /////////// 10 FPS //////
        let sensor = GravitySensor.init(GravitySensor.Config().apply{ config in
            config.debug = true
            config.dbType = .REALM
            config.frequency = 10
        })
        sensor.start() // start sensor
        print(1.0/Double(sensor.CONFIG.frequency))
        let expect = expectation(description: "Sensing test (30FPS)")
        let observer = NotificationCenter.default.addObserver(forName: Notification.Name.actionAwareGravity,
                                                              object: nil,
                                                              queue: .main) { (notification) in
            sensor.stop() // stop sensor
            if let engine = sensor.dbEngine {
                if let results =  engine.fetch(GravityData.TABLE_NAME, GravityData.self, nil) as? Results<Object>{
                    print(results.count)
                    if (results.count > 1) {
                        let idealCount = 60*sensor.CONFIG.frequency
                        print("ideal count = ",idealCount)
                        if results.count >= (idealCount-100) && results.count <= (idealCount+100) {
                            for object in results{
                                if let o = object as? AwareObject{
                                    engine.remove(o, GravityData.TABLE_NAME)
                                }
                            }
                            expect.fulfill()
                        }else{
                            XCTFail()
                        }

                    }
                }
            }
        }
        wait(for: [expect], timeout: (sensor.CONFIG.period * 60) + 5)
        NotificationCenter.default.removeObserver(observer)
        
        #endif
    }
    
    func testSync(){
        //        let sensor = GravitySensor.init(GravitySensor.Config().apply{ config in
        //            config.debug = true
        //            config.dbType = .REALM
        //            config.dbHost = "node.awareframework.com/dgc"
        //        })
        //        sensor.start();
        //        sensor.enable();
        //        sensor.sync(force: true)

        //        let syncManager = DbSyncManager.Builder()
        //            .setBatteryOnly(false)
        //            .setWifiOnly(false)
        //            .setSyncInterval(1)
        //            .build()
        //
        //        syncManager.start()
    }

    func testObserver(){
        #if targetEnvironment(simulator)
        print("This test requires a real device.")

        #else

        class Observer:GravityObserver{
            // https://www.mokacoding.com/blog/testing-delegates-in-swift-with-xctest/
            // http://nsblogger.hatenablog.com/entry/2015/02/09/xctestexpectation_api_violation
            weak var asyncExpectation: XCTestExpectation?
            func onDataChanged(data: GravityData) {
                if let syncExp = self.asyncExpectation {
                    syncExp.fulfill()
                    asyncExpectation = nil
                }
            }
        }

        let expectObserver = expectation(description: "observer")
        let observer = Observer()
        observer.asyncExpectation = expectObserver
        let sensor = GravitySensor.init(GravitySensor.Config().apply{ config in
            config.sensorObserver = observer
        })
        sensor.start()

        waitForExpectations(timeout: 30) { (error) in
            if let e = error {
                print(e)
                XCTFail()
            }
        }
        sensor.stop()

        #endif

    }

    func testControllers(){

        let sensor = GravitySensor.init(GravitySensor.Config().apply{ config in
            config.debug = true
            // config.dbType = .REALM
        })

        /// test set label action ///
        let expectSetLabel = expectation(description: "set label")
        let newLabel = "hello"
        let labelObserver = NotificationCenter.default.addObserver(forName: .actionAwareGravitySetLabel, object: nil, queue: .main) { (notification) in
            let dict = notification.userInfo;
            if let d = dict as? Dictionary<String,String>{
                XCTAssertEqual(d[GravitySensor.EXTRA_LABEL], newLabel)
            }else{
                XCTFail()
            }
            expectSetLabel.fulfill()
        }
        sensor.set(label:newLabel)
        wait(for: [expectSetLabel], timeout: 5)
        NotificationCenter.default.removeObserver(labelObserver)

        /// test sync action ////
        let expectSync = expectation(description: "sync")
        let syncObserver = NotificationCenter.default.addObserver(forName: Notification.Name.actionAwareGravitySync , object: nil, queue: .main) { (notification) in
            expectSync.fulfill()
            print("sync")
        }
        sensor.sync()
        wait(for: [expectSync], timeout: 5)
        NotificationCenter.default.removeObserver(syncObserver)


        #if targetEnvironment(simulator)

        print("Controller tests (start and stop) require a real device.")

        #else

        //// test start action ////
        let expectStart = expectation(description: "start")
        let observer = NotificationCenter.default.addObserver(forName: .actionAwareGravityStart,
                                                              object: nil,
                                                              queue: .main) { (notification) in
                                                                expectStart.fulfill()
                                                                print("start")
        }
        sensor.start()
        wait(for: [expectStart], timeout: 5)
        NotificationCenter.default.removeObserver(observer)


        /// test stop action ////
        let expectStop = expectation(description: "stop")
        let stopObserver = NotificationCenter.default.addObserver(forName: .actionAwareGravityStop, object: nil, queue: .main) { (notification) in
            expectStop.fulfill()
            print("stop")
        }
        sensor.stop()
        wait(for: [expectStop], timeout: 5)
        NotificationCenter.default.removeObserver(stopObserver)

        #endif
    }

    func testGravityData(){
        let accData = GravityData()
        let dict = accData.toDictionary()
        XCTAssertEqual(dict["x"] as! Double, 0)
        XCTAssertEqual(dict["y"] as! Double, 0)
        XCTAssertEqual(dict["z"] as! Double, 0)
        XCTAssertEqual(dict["eventTimestamp"] as! Int64, 0)
    }

    func testConfig(){

        let frequency = 1;
        let threshold = 0.5;
        let period    = 1.0;
        let config :Dictionary<String,Any> = ["frequency":frequency, "threshold":threshold, "period":period]

        var sensor = GravitySensor.init(GravitySensor.Config(config));
        XCTAssertEqual(frequency, sensor.CONFIG.frequency)
        XCTAssertEqual(threshold, sensor.CONFIG.threshold)
        XCTAssertEqual(period, sensor.CONFIG.period)

        sensor = GravitySensor.init(GravitySensor.Config().apply{config in
            config.frequency = frequency
            config.threshold = threshold
            config.period = period
        });
        XCTAssertEqual(frequency, sensor.CONFIG.frequency)
        XCTAssertEqual(threshold, sensor.CONFIG.threshold)
        XCTAssertEqual(period, sensor.CONFIG.period)

        sensor = GravitySensor.init()
        sensor.CONFIG.set(config: config)
        XCTAssertEqual(frequency, sensor.CONFIG.frequency)
        XCTAssertEqual(threshold, sensor.CONFIG.threshold)
        XCTAssertEqual(period, sensor.CONFIG.period)

    }
    
}
