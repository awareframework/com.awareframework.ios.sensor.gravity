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
    
    func testSensorFrequency(){
        
        #if targetEnvironment(simulator)
        print("This test requires a real Gravity.")
        
        #else
        /////////// 10 FPS //////
        let sensor = GravitySensor.init(GravitySensor.Config().apply{ config in
            config.debug = true
            config.dbType = .REALM
            config.frequency = 10
            config.period = 1.0/60.0
            config.dbPath = "sensor_frequency"
        })
        
        if let engine = sensor.dbEngine {
            engine.removeAll(GravityData.self)
        }
        
        let expect = expectation(description: "Frequency Test (10FPS)")
        let observer = NotificationCenter.default.addObserver(forName: Notification.Name.actionAwareGravity,
                                                              object: sensor,
                                                              queue: .main) { (notification) in
            sensor.stop() // stop sensor
            if let engine = sensor.dbEngine {
                engine.fetch(GravityData.self, nil){ (resultsObject, error) in
                    if let results = resultsObject as? Results<Object> {
                        print("ideal count = ",sensor.CONFIG.frequency)
                        print("real count  = ",results.count)
                        if results.count > 0 {
                            if results.count >= sensor.CONFIG.frequency-1 && results.count <= (sensor.CONFIG.frequency+1) {
                                expect.fulfill()
                            }else{
                                XCTFail()
                            }
                        }
                    }
                }
            }
        }
        
        sensor.start() // start sensor
        
        wait(for: [expect], timeout: (sensor.CONFIG.period * 60) + 5)
        NotificationCenter.default.removeObserver(observer)
        
        #endif
    }

    func testObserver(){
        #if targetEnvironment(simulator)
        print("This test requires a real Gravity.")

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

        print("Controller tests (start and stop) require a real Gravity.")

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
    
    func testSyncModule(){
        #if targetEnvironment(simulator)
        
        print("This test requires a real Gravity.")
        
        #else
        // success //
        let sensor = GravitySensor.init(GravitySensor.Config().apply{ config in
            config.debug = true
            config.dbType = .REALM
            config.dbHost = "node.awareframework.com:1001"
            config.dbPath = "sync_db"
        })
        if let engine = sensor.dbEngine as? RealmEngine {
            engine.removeAll(GravityData.self)
            for _ in 0..<100 {
                engine.save(GravityData())
            }
        }
        let successExpectation = XCTestExpectation(description: "success sync")
        let observer = NotificationCenter.default.addObserver(forName: Notification.Name.actionAwareGravitySyncCompletion,
                                                              object: sensor, queue: .main) { (notification) in
                                                                if let userInfo = notification.userInfo{
                                                                    if let status = userInfo["status"] as? Bool {
                                                                        if status == true {
                                                                            successExpectation.fulfill()
                                                                        }
                                                                    }
                                                                }
        }
        sensor.sync(force: true)
        wait(for: [successExpectation], timeout: 20)
        NotificationCenter.default.removeObserver(observer)
        
        ////////////////////////////////////
        
        // failure //
        let sensor2 = GravitySensor.init(GravitySensor.Config().apply{ config in
            config.debug = true
            config.dbType = .REALM
            config.dbHost = "node.awareframework.com.com" // wrong url
            config.dbPath = "sync_db"
        })
        let failureExpectation = XCTestExpectation(description: "failure sync")
        let failureObserver = NotificationCenter.default.addObserver(forName: Notification.Name.actionAwareGravitySyncCompletion,
                                                                     object: sensor2, queue: .main) { (notification) in
                                                                        if let userInfo = notification.userInfo{
                                                                            if let status = userInfo["status"] as? Bool {
                                                                                if status == false {
                                                                                    failureExpectation.fulfill()
                                                                                }
                                                                            }
                                                                        }
        }
        if let engine = sensor2.dbEngine as? RealmEngine {
            engine.removeAll(GravityData.self)
            for _ in 0..<100 {
                engine.save(GravityData())
            }
        }
        sensor2.sync(force: true)
        wait(for: [failureExpectation], timeout: 20)
        NotificationCenter.default.removeObserver(failureObserver)
        
        #endif
    }
    
    //////////// storage ///////////
    var realmToken:NotificationToken? = nil
    
    func testSensorModule(){
        
        #if targetEnvironment(simulator)

        print("This test requires a real Gravity.")

        #else
        
        let sensor = GravitySensor.init(GravitySensor.Config().apply{ config in
            config.debug = true
            config.dbType = .REALM
            config.dbPath = "sensor_module"
            config.period = 1.0/60.0
        })
        let expect = expectation(description: "sensor module")
        if let realmEngine = sensor.dbEngine as? RealmEngine {
            // remove old data
            realmEngine.removeAll(GravityData.self)
            // get a RealmEngine Instance
            if let realm = realmEngine.getRealmInstance() {
                // set Realm DB observer
                realmToken = realm.observe { (notification, realm) in
                    switch notification {
                    case .didChange:
                        // check database size
                        let results = realm.objects(GravityData.self)
                        print(results.count)
                        XCTAssertGreaterThanOrEqual(results.count, 1)
                        realm.invalidate()
                        expect.fulfill()
                        self.realmToken = nil
                        break;
                    case .refreshRequired:
                        break;
                    }
                }
            }
        }
        
        let storageExpect = expectation(description: "sensor storage notification")
        var token: NSObjectProtocol?
        token = NotificationCenter.default.addObserver(forName: Notification.Name.actionAwareGravity,
                                                       object: sensor,
                                                       queue: .main) { (notification) in
                                                        storageExpect.fulfill()
                                                        NotificationCenter.default.removeObserver(token!)
        }
        
        sensor.start() // start sensor
        
        wait(for: [expect,storageExpect], timeout: 65)
        sensor.stop()
        
        #endif
    }
}
