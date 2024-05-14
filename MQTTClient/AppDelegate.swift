//
//  AppDelegate.swift
//  MQTTClient
//
//  Created by UniqueStrategy on 5/14/24.
//

import Foundation
import UserNotifications
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // AppDelegate에서 UNUserNotificationCenterDelegate 설정
        UNUserNotificationCenter.current().delegate = self
        // 기타 초기화 코드
    }
    
    // 사용자가 알림을 클릭했을 때 호출됩니다.
        func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
            // 사용자가 알림을 클릭한 경우
            if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                print("알림 선택")
                // 알림에 첨부된 이미지가 있는지 확인합니다.
                if let attachment = response.notification.request.content.attachments.first {
                    // 이미지를 가져와서 ContentView에 있는 selectedImage에 할당합니다.
                    let imageUrl = attachment.url
                    print("알림 선택 imageUrl")
                    print(imageUrl)
                    do {
                        let imageData = try Data(contentsOf: imageUrl)
                        if let image = NSImage(data: imageData) {
                            NotificationCenter.default.post(name: Notification.Name("ImageReceived"), object: image)
                        }
                    } catch {
                        print("이미지 로드 중 오류 발생:", error)
                    }
                }
            }
            // 처리 완료
            //completionHandler()
        }
}
