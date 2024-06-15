//
//  ContentView.swift
//  MQTTClient
//
//  Created by UniqueStrategy on 5/12/24.
//

import SwiftUI
import CocoaMQTT // CocoaMQTT 라이브러리를 사용합니다.
import SystemConfiguration
import UserNotifications

enum MQTTConnectionStatus {
    case disconnected
    case connecting
    case connected
    case didConnectAck
    case didPublishMessage
    case didPublishAck
    case didReceiveMessage
    case didSubscribeTopics
    case didUnsubscribeTopics
    case mqttDidPing
    case mqttDidReceivePong
    case mqttDidDisconnect
}

class MQTTClient: ObservableObject {
    @Published var connectionStatus: MQTTConnectionStatus = .disconnected

    // MQTT 클라이언트의 연결 및 구독 관련 메서드 등을 정의합니다.
}

func checkInternetConnection() -> Bool{
    var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
            zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
            zeroAddress.sin_family = sa_family_t(AF_INET)
            
            let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                    SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
                }
            }
            
            var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
            if SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) == false {
                return false
            }
            
            /* Only Working for WIFI
             let isReachable = flags == .reachable
             let needsConnection = flags == .connectionRequired
             
             return isReachable && !needsConnection
             */
            
            // Working for Cellular and WIFI
            let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
            let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
            let result = (isReachable && !needsConnection)
            
            return result
}


class IoTManager: CocoaMQTTDelegate{
    
    @ObservedObject var mqttClient : MQTTClient = MQTTClient()
    
    init() {
        connectToIoTDevice()
    }
   
    var refreshAction: (() -> Void)? // 클로저 프로퍼티 추가
    var activeAction:(() -> Void)?
    
    var mqtt: CocoaMQTT!
    
    
    func connectToIoTDevice() {
        let clientID = "your-client-id"
        let serverURL = "192.168.25.24"
        let serverPort: UInt16 = 1883 // or the port specified by your IoT device

        mqtt = CocoaMQTT(clientID: clientID, host: serverURL, port: serverPort)
        mqtt.keepAlive = 60
        mqtt.autoReconnect = true
       // _ = mqtt.connect()
        mqtt.delegate = self
        print(mqtt.connect())
    }

    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck){
        self.mqttClient.connectionStatus = .didConnectAck
        print("mqtt didConnectAck")
        let topic = "l2rnoti"
        mqtt.subscribe(topic)
    }
    
    ///
    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16){
        self.mqttClient.connectionStatus = .didPublishMessage
        print("mqtt didPublishMessage")
    }
    
    ///
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16){
        self.mqttClient.connectionStatus = .didPublishAck
        print("mqtt didPublishAck")
    }
    
    ///
    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16 ){
        self.mqttClient.connectionStatus = .didReceiveMessage
        DispatchQueue.main.async {
            if self.isImageData(data: Data(message.payload)){
                print("mqtt didReceiveMessage image")
                guard let image = NSImage(data: Data(bytes: message.payload, count: message.payload.count)) else {
                            return
                        }
                        
                // 이미지를 알림에 포함하여 표시
                self.showNotification(with: image)
            }else{
                if message.string == "capture"{
                    self.refreshAction?()
                    print("active... 1 ")
                    self.activeAction?()
                    print("active... 2")
                }else{
                    self.sendNotification( message:message.string ?? "리니지2레볼루션")
                    self.executeAfterDelay(seconds: 2.0) {
                        // 문자열 메시지를 수신했을 때의 처리
                        
                    }
                }
                print("mqtt didReceiveMessage text")
                
            }
        }
    }
    
    // n초 후에 실행할 함수
    func executeAfterDelay(seconds: Double, completion: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            completion()
        }
    }
    ///
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]){
        self.mqttClient.connectionStatus = .didSubscribeTopics
        print("mqtt didSubscribeTopics")
    }
    
    ///
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]){
        self.mqttClient.connectionStatus = .didUnsubscribeTopics
        print("mqtt didUnsubscribeTopics")
    }
    
    ///
    func mqttDidPing(_ mqtt: CocoaMQTT){
        self.mqttClient.connectionStatus = .mqttDidPing
        print("mqtt mqttDidPing")
    }
    
    ///
    func mqttDidReceivePong(_ mqtt: CocoaMQTT){
        self.mqttClient.connectionStatus = .mqttDidReceivePong
        print("mqtt mqttDidReceivePong")
    }
    
    ///
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?){
        self.mqttClient.connectionStatus = .mqttDidDisconnect
        print("mqtt mqttDidDisconnect")
        print(err)
    }
    
}

extension IoTManager {
    func isImageData(data: Data) -> Bool {
        // 전송된 데이터가 이미지인지 텍스트인지 확인
        if let image = NSImage(data:data) {
            // 이미지인 경우
           return true
        } else{
            return false
        }
                            
    }
    
    func subscribeToTopic(topic: String) {
        mqtt.subscribe(topic)
    }

    func publishData(topic: String, message: String) {
        mqtt.publish(topic, withString: message, qos: .qos1)
    }
    
    func showNotification(with image: NSImage) {
        let content = UNMutableNotificationContent()
        content.title = "리니지2레볼루션"
        content.body = getCurrentDateTimeString()
        content.sound = UNNotificationSound.defaultCritical
        
        
        if let data = image.tiffRepresentation {
            if let attachment = UNNotificationAttachment.creates(imageFileIdentifier: "image.jpg", data: data, options: nil) {
                content.attachments = [attachment]
            }
        }
        
        let request = UNNotificationRequest(identifier: "imageNotification", content: content, trigger: nil)
        //UNUserNotificationCenter.current().add(request)
        
        UNUserNotificationCenter.current().add(request) { (error) in
            if let error = error {
                print("알림 추가 중 에러 발생: \(error.localizedDescription)")
            } else {
                print("알림이 성공적으로 추가되었습니다.")
            }
        }
        
    }
    func sendNotification(message:String){
        // 알림 설정 확인
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.getNotificationSettings { settings in
            if settings.authorizationStatus == .authorized {
                print("settings.authorizationStatus == .authorized.")
                // 알림 설정이 켜져 있는 경우에만 알림을 표시
                /*****
                let notification = NSUserNotification()
                notification.title = "알림"
                notification.informativeText = message
                NSUserNotificationCenter.default.deliver(notification)
                ***********/
                
                let content = UNMutableNotificationContent()
                content.title = getCurrentDateTimeString()
                content.body = message
                content.sound = UNNotificationSound.default
                
                
                // 알림이 발생할 시간 설정
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let identifier = "notification_\(Date().timeIntervalSince1970)" // 고유한 identifier 생성
                
                
                /*
                // 알림에 표시할 이미지 추가
                if let imageURL = Bundle.main.url(forResource: "l2r_icon", withExtension: "png") {
                    do {
                        print(imageURL.absoluteURL)
                        let attachment = try UNNotificationAttachment(identifier: identifier, url: imageURL, options: nil)
                        content.attachments = [attachment]
                    } catch {
                        print("알림 이미지 추가 중 에러 발생: \(error.localizedDescription)")
                    }
                }
                 */
                // 알림 요청 생성
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                
                // 알림 요청 등록
                UNUserNotificationCenter.current().add(request) { (error) in
                    if let error = error {
                        print("알림 요청 등록 중 에러 발생: \(error.localizedDescription)")
                    } else {
                        print("알림이 성공적으로 등록되었습니다.")
                    }
                }
                
                
                if settings.soundSetting == .enabled {
                    // 알림 사운드 허용됨
                    //NSSound(named: NSSound.Name("Glass"))?.play()
                } else {
                    // 알림 사운드 비허용됨
                    // 사운드 재생하지 않음
                }
                //NSSound(named: NSSound.Name("Glass"))?.play()
            } else {
                print("settings.authorizationStatus != .authorized.")
                // 알림 설정이 꺼져 있는 경우에는 사용자에게 메시지 표시
                /*
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "알림 허용 필요"
                    alert.informativeText = "알림을 받으려면 설정에서 알림을 허용해주세요."
                    alert.addButton(withTitle: "확인")
                    alert.runModal()
                }
                 */
            }
        }
    }
}
extension UNNotificationAttachment {
    static func creates(imageFileIdentifier: String, data: Data, options: [NSObject : AnyObject]?) -> UNNotificationAttachment? {
        let fileManager = FileManager.default
        let temporaryFolderName = ProcessInfo.processInfo.globallyUniqueString
        let temporaryFolderURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(temporaryFolderName, isDirectory: true)

        do {
            try fileManager.createDirectory(at: temporaryFolderURL, withIntermediateDirectories: true, attributes: nil)
            let fileURL = temporaryFolderURL.appendingPathComponent(imageFileIdentifier)
            try data.write(to: fileURL)
            let imageAttachment = try UNNotificationAttachment(identifier: imageFileIdentifier, url: fileURL, options: options)
            return imageAttachment
        } catch {
            print("이미지 첨부 파일 생성 중 에러 발생: \(error.localizedDescription)")
        }
        return nil
    }
}
func getCurrentDateTimeString() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return dateFormatter.string(from: Date())
}

struct ContentView: View {
    @State private var selectedImage: Image?
    var iotManager = IoTManager()
    @ObservedObject var mqttStatus : MQTTClient
    
    @State private var imageURL = URL(string: "http://211.208.112.39:8081/l2r/Screen")!
    @State private var refreshKey = UUID() // 상태 변수 추가
    @State private var imageSize: CGSize = .zero // 이미지 크기 상태 변수
    @State private var isLoading = false // 이미지 로딩 상태 변수
    
    // 이미지 뷰의 초기 크기
    private let initialImageViewSize: CGSize = CGSize(width: 1001, height: 574)
    
    func refreshImage() {
        // 이미지 URL을 변경하여 새로고침
        refreshKey = UUID() // refreshKey 업데이트
        isLoading = true // 로딩 시작
        imageURL = URL(string: "http://211.208.112.39:8081/l2r/Screen?\(refreshKey)")!
        loadImageSize() // 이미지 새로 로드 시 크기도 다시 로드
    }

    private func loadImageSize() {
        guard let url = URL(string: "http://211.208.112.39:8081/l2r/Screen?\(refreshKey)") else { return }
        
        // 비동기적으로 이미지를 로드하고 크기를 가져옴
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil,
                  let nsImage = NSImage(data: data) else { return }
            
            DispatchQueue.main.async {
                self.imageSize = nsImage.size
                print(self.imageSize.width)
                print(self.imageSize.height)
                isLoading = false // 로딩 완료
            }
        }.resume()
    }

    func active(){
        NSApp.activate(ignoringOtherApps: true)
    }
    private func setImageSize(for image: Image) {
        // 이미지를 로드한 후 크기를 설정하는 로직이 필요 없으므로 비워 둠
    }
    
    init(iotManager: IoTManager = IoTManager()) {
        self.iotManager = iotManager
        self.mqttStatus = iotManager.mqttClient
    }
    
    var connectionStatusText: String {
        switch mqttStatus.connectionStatus {
            case .disconnected:
                return "disconnected"
            case .connecting:
                return "connecting"
            case .connected:
                return "connected"
            case .didConnectAck:
                //print("connectionStatus didConnectAck")
                return "didConnectAck"
            case .didPublishMessage:
                return "didPublishMessage"
            case .didPublishAck:
                return "didPublishAck"
            case .didReceiveMessage:
                return  "didReceiveMessage"
            case .didSubscribeTopics:
                return "didSubscribeTopics"
            case .didUnsubscribeTopics:
                return "didUnsubscribeTopics"
            case .mqttDidPing:
                return "mqttDidPing"
            case .mqttDidReceivePong:
                return "mqttDidReceivePong"
            case .mqttDidDisconnect:
                return "mqttDidDisconnect"
            }
        }
    var body: some View {
        VStack {
            Text("MQTT 상태: \(connectionStatusText)")
                .padding()
            
            if let image = selectedImage {
                image
                    .resizable()
                    .scaledToFit()
            } else {
                Text("이미지가 없습니다.")
            }

            
            Button(action: {
                let topic = "l2rnoti"
                iotManager.subscribeToTopic(topic: topic)
                print(iotManager.mqttClient.connectionStatus)
            }) {
                Text("Button")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            HStack{
                Spacer()
                ZStack {
                    if imageSize != .zero {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle()) // 로딩바 스타일 설정
                                    .frame(width: 50, height: 50) // 로딩바의 크기 고정
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit) // 이미지 성공적으로 로드되었을 때 표시할 뷰
                            case .failure:
                                Image(systemName: "exclamationmark.triangle") // 로드 실패 시 표시할 뷰
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: initialImageViewSize.width, height: initialImageViewSize.height)
                        //.frame(width: geometry.size.width, height: geometry.size.height) // 프레임 크기 조절
                        .overlay(
                            Color.clear // 이미지 뷰와 같은 크기의 빈 뷰 추가하여 버튼 위치 조정
                                .frame(width: initialImageViewSize.width, height: initialImageViewSize.height)
                        )
                    } else {
                        Color.clear // 이미지가 로드되지 않은 경우에도 빈 뷰를 사용하여 크기를 고정
                            .frame(width: initialImageViewSize.width, height: initialImageViewSize.height)
                    }
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle()) // 로딩바 스타일 설정
                            .frame(width: 50, height: 50) // 로딩바의 크기 고정
                        //.scaleEffect(1) // 로딩바 크기 조절
                    }
                }
                Spacer()
            }
                 
            // 새로 고침 버튼
            Button(action: {
                refreshImage()
            }) {
                Text("새로고침")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
            }.disabled(isLoading) // 이미지 로딩 중에는 버튼을 비활성화
            
            
        }.onAppear {
            loadImageSize()
            //let topic = "l2rnoti"
            //iotManager.subscribeToTopic(topic: topic)
            print(iotManager.mqttClient.connectionStatus)
            //let topic = "l2rnoti"
            //iotManager.subscribeToTopic(topic: topic)
            
            self.iotManager.refreshAction = {
                refreshImage()
            }
            self.iotManager.activeAction = {
                active()
            }
        }.onReceive(NotificationCenter.default.publisher(for: Notification.Name("ImageReceived"))) { notification in
            if let image = notification.object as? Image {
                selectedImage = image
            }
        }
        
    }
    func performAfterDelay(seconds: TimeInterval, completionHandler: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            completionHandler()
        }
    }
    
    
    
}


#Preview {
    ContentView()
}
