import Flutter
import UIKit

//
//  LinklanEuiccPlugin.swift
//  LinklanEuicc
//
//  Created by Apple on 2026/8/17.
//

import Flutter
import UIKit
import CoreBluetooth
import LinklanEuicc

/// LinklanEuicc Flutter Plugin
public class LinklanEuiccPlugin: NSObject, FlutterPlugin {

    // MARK: - 属性

    private var channel: FlutterMethodChannel?
    private var bleDeviceMap: [String: BleDevice] = [:]
    private var euiccDeviceMap: [String: EuiccDevice] = [:]

    // 认证回调
    private var authContinuation: CheckedContinuation<String, Never>?

    // MARK: - 注册

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "linklan_euicc",
            binaryMessenger: registrar.messenger()
        )
        let instance = LinklanEuiccPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        instance.channel = channel
    }

    // MARK: - 初始化

    public override init() {
        super.init()
        setupListeners()
    }

    // MARK: - 设置监听器

    private func setupListeners() {
        // 设置用户认证监听器
        LinklanLPA.shared.userAuthenticationListener = self

        // 设置设备连接状态监听器
        LinklanLPA.shared.bleDeviceConnectionListener = self
    }

    // MARK: - FlutterPlugin

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        // ============ 基础方法 ============
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)

        case "init":
            let debug = (call.arguments as? [String: Any])?["debug"] as? Bool ?? false
            LinklanLPA.shared.initSDK(debug: debug)
            result(true)

        // ============ 扫描相关 ============
        case "startScan":
            startScan(result: result)

        case "stopScan":
            LinklanLPA.shared.stopScan()
            result(true)

        // ============ 设备连接 ============
        case "connectDevice":
            guard let args = call.arguments as? [String: Any],
                  let address = args["address"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing address", details: nil))
                return
            }
            connectDevice(address: address, result: result)

        case "disconnectDevice":
            guard let args = call.arguments as? [String: Any],
                  let address = args["address"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing address", details: nil))
                return
            }
            disconnectDevice(address: address)
            result(true)

        case "checkDeviceConnection":
            guard let args = call.arguments as? [String: Any],
                  let address = args["address"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing address", details: nil))
                return
            }
            let isConnected = checkDeviceConnection(address: address)
            result(isConnected)

        // ============ 设备信息 ============
        case "getDeviceInfo":
            guard let args = call.arguments as? [String: Any],
                  let address = args["address"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing address", details: nil))
                return
            }
            getDeviceInfo(address: address, result: result)

        case "resetDevice":
            guard let args = call.arguments as? [String: Any],
                  let address = args["address"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing address", details: nil))
                return
            }
            resetDevice(address: address, result: result)

        // ============ Profile 管理 ============
        case "getProfileInfoList":
            guard let args = call.arguments as? [String: Any],
                  let address = args["address"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing address", details: nil))
                return
            }
            getProfileInfoList(address: address, result: result)

        case "enableProfile":
            guard let args = call.arguments as? [String: Any],
                  let address = args["address"] as? String,
                  let iccid = args["iccid"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing address or iccid", details: nil))
                return
            }
            enableProfile(address: address, iccid: iccid, result: result)

        case "disableProfile":
            guard let args = call.arguments as? [String: Any],
                  let address = args["address"] as? String,
                  let iccid = args["iccid"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing address or iccid", details: nil))
                return
            }
            disableProfile(address: address, iccid: iccid, result: result)

        case "deleteProfile":
            guard let args = call.arguments as? [String: Any],
                  let address = args["address"] as? String,
                  let iccid = args["iccid"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing address or iccid", details: nil))
                return
            }
            deleteProfile(address: address, iccid: iccid, result: result)

        case "setProfileNickname":
            guard let args = call.arguments as? [String: Any],
                  let address = args["address"] as? String,
                  let iccid = args["iccid"] as? String,
                  let nickname = args["nickname"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing address or iccid", details: nil))
                return
            }
            setProfileNickname(address: address, iccid: iccid,  nickname: nickname, result: result)

        case "downloadProfile":
            guard let args = call.arguments as? [String: Any],
                  let address = args["address"] as? String,
                  let activeCode = args["activeCode"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing address or activeCode", details: nil))
                return
            }
            let confirmCode = args["confirmCode"] as? String
            downloadProfile(address: address, activeCode: activeCode, confirmCode: confirmCode, result: result)

        // ============ APN 管理 ============
        case "setAPN":
            guard let args = call.arguments as? [String: Any],
                  let address = args["address"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing address", details: nil))
                return
            }
            setAPN(
                address: address,
                apn: args["apn"] as? String,
                userName: args["userName"] as? String,
                userPass: args["userPass"] as? String,
                authType: args["authType"] as? String,
                dialNum: args["dialNum"] as? String,
                netType: args["netType"] as? String,
                pdpType: args["pdpType"] as? String
            )
            result(true)

        case "getAPN":
            guard let args = call.arguments as? [String: Any],
                  let address = args["address"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing address", details: nil))
                return
            }
            getAPN(address: address, result: result)

        // ============ APDU ============
        case "setApdu":
            guard let args = call.arguments as? [String: Any],
                  let address = args["address"] as? String,
                  let checkPatch = args["checkPatch"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing address or checkPatch", details: nil))
                return
            }
            setApdu(address: address, checkPatch: checkPatch, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - 扫描相关

    private func startScan(result: @escaping FlutterResult) {
        let callback = ScanCallback { [weak self] event, data in
            guard let self = self else { return }

            switch event {
            case .onDeviceFound:
                if let device = data as? BleDevice {
                    self.bleDeviceMap[device.address] = device
                    self.channel?.invokeMethod("onDeviceFound", arguments: self.deviceToMap(device))
                }
            case .onDeviceUpdated:
                if let device = data as? BleDevice {
                    self.channel?.invokeMethod("onDeviceUpdated", arguments: self.deviceToMap(device))
                }
            case .onScanStateChanged:
                if let isScanning = data as? Bool {
                    self.channel?.invokeMethod("onScanStateChanged", arguments: isScanning)
                }
            case .onScanFailed:
                if let dict = data as? [String: Any] {
                    self.channel?.invokeMethod("onScanFailed", arguments: dict)
                }
            }
        }

        LinklanLPA.shared.startScan(callback: callback)
        result(true)
    }

    // MARK: - 设备连接

    private func connectDevice(address: String, result: @escaping FlutterResult) {
        guard let device = bleDeviceMap[address] else {
            result(FlutterError(code: "CONNECT_ERROR", message: "Device not found", details: nil))
            return
        }

        Task {
            let euiccResult = await LinklanLPA.shared.connectDevice(device: device)

            
            if euiccResult.isSuccess, let deviceData = euiccResult.data, let addr = deviceData.address {
                self.euiccDeviceMap[addr] = deviceData
            }

            DispatchQueue.main.async {
                result(self.euiccResultToJson(euiccResult))
            }
        }
    }

    private func disconnectDevice(address: String) {
        let device = euiccDeviceMap[address]
        LinklanLPA.shared.disconnectDevice(device: device)
        euiccDeviceMap.removeValue(forKey: address)
    }

    private func checkDeviceConnection(address: String) -> Bool {
        let device = euiccDeviceMap[address]
        return LinklanLPA.shared.checkDeviceConnection(device: device)
    }

    // MARK: - 设备信息

    private func getDeviceInfo(address: String, result: @escaping FlutterResult) {
        guard let device = euiccDeviceMap[address] else {
            result(FlutterError(code: "DEVICE_ERROR", message: "Device not found", details: nil))
            return
        }

        Task {
            let euiccResult = await LinklanLPA.shared.getDeviceInfo(device: device)
            DispatchQueue.main.async {
                result(self.euiccResultToJson(euiccResult))
            }
        }
    }

    private func resetDevice(address: String, result: @escaping FlutterResult) {
        guard let device = euiccDeviceMap[address] else {
            result(FlutterError(code: "DEVICE_ERROR", message: "Device not found", details: nil))
            return
        }

        Task {
            await LinklanLPA.shared.resetDevice(device: device)
            DispatchQueue.main.async {
                result(true)
            }
        }
    }

    // MARK: - Profile 管理

    private func getProfileInfoList(address: String, result: @escaping FlutterResult) {
        guard let device = euiccDeviceMap[address] else {
            result(FlutterError(code: "PROFILE_ERROR", message: "Device not found", details: nil))
            return
        }

        Task {
            let euiccResult = await LinklanLPA.shared.getProfileInfoList(device: device)
            DispatchQueue.main.async {
                result(self.euiccResultToJson(euiccResult))
            }
        }
    }

    private func enableProfile(address: String, iccid: String, result: @escaping FlutterResult) {
        guard let device = euiccDeviceMap[address] else {
            result(FlutterError(code: "PROFILE_ERROR", message: "Device not found", details: nil))
            return
        }

        Task {
            let euiccResult = await LinklanLPA.shared.enableProfile(device: device, iccid: iccid)
            DispatchQueue.main.async {
                result(self.euiccResultToJson(euiccResult))
            }
        }
    }

    private func disableProfile(address: String, iccid: String, result: @escaping FlutterResult) {
        guard let device = euiccDeviceMap[address] else {
            result(FlutterError(code: "PROFILE_ERROR", message: "Device not found", details: nil))
            return
        }

        Task {
            let euiccResult = await LinklanLPA.shared.disableProfile(device: device, iccid: iccid)
            DispatchQueue.main.async {
                result(self.euiccResultToJson(euiccResult))
            }
        }
    }

    private func deleteProfile(address: String, iccid: String, result: @escaping FlutterResult) {
        guard let device = euiccDeviceMap[address] else {
            result(FlutterError(code: "PROFILE_ERROR", message: "Device not found", details: nil))
            return
        }

        Task {
            let euiccResult = await LinklanLPA.shared.deleteProfile(device: device, iccid: iccid)
            DispatchQueue.main.async {
                result(self.euiccResultToJson(euiccResult))
            }
        }
    }

    private func setProfileNickname(address: String, iccid: String, nickname: String, result: @escaping FlutterResult) {
        guard let device = euiccDeviceMap[address] else {
            result(FlutterError(code: "PROFILE_ERROR", message: "Device not found", details: nil))
            return
        }

        Task {
            let euiccResult = await LinklanLPA.shared.setProfileNickname(device: device, iccid: iccid,nickname:nickname)
            DispatchQueue.main.async {
                result(self.euiccResultToJson(euiccResult))
            }
        }
    }

    private func downloadProfile(address: String, activeCode: String, confirmCode: String?, result: @escaping FlutterResult) {
        guard let device = euiccDeviceMap[address] else {
            result(FlutterError(code: "DOWNLOAD_ERROR", message: "Device not found", details: nil))
            return
        }

        Task {
            let euiccResult = await LinklanLPA.shared.downloadProfile(
                device: device,
                activeCode: activeCode,
                confirmCode: confirmCode
            )
            DispatchQueue.main.async {
                result(self.euiccResultToJson(euiccResult))
            }
        }
    }

    // MARK: - APN 管理

    private func setAPN(
        address: String,
        apn: String?,
        userName: String?,
        userPass: String?,
        authType: String?,
        dialNum: String?,
        netType: String?,
        pdpType: String?
    ) {
        let device = euiccDeviceMap[address]
        LinklanLPA.shared.setAPN(
            device: device,
            apn: apn,
            userName: userName,
            userPass: userPass,
            authType: authType,
            dialNum: dialNum,
            netType: netType,
            pdpType: pdpType
        )
    }

    private func getAPN(address: String, result: @escaping FlutterResult) {
        guard let device = euiccDeviceMap[address] else {
            result(FlutterError(code: "APN_ERROR", message: "Device not found", details: nil))
            return
        }

        Task {
            let euiccResult = await LinklanLPA.shared.getAPN(device: device)
            DispatchQueue.main.async {
                result(self.euiccResultToJson(euiccResult))
            }
        }
    }

    // MARK: - APDU

    private func setApdu(address: String, checkPatch: String, result: @escaping FlutterResult) {
        guard let device = euiccDeviceMap[address] else {
            result(FlutterError(code: "APDU_ERROR", message: "Device not found", details: nil))
            return
        }

        Task {
            let euiccResult = await LinklanLPA.shared.setApdu(device: device, checkPatch: checkPatch)
            DispatchQueue.main.async {
                result(self.euiccResultToJson(euiccResult))
            }
        }
    }

    // MARK: - JSON 转换

    private func deviceToMap(_ device: BleDevice) -> [String: Any] {
        return [
            "address": device.address,
            "name": device.name,
            "rssi": device.rssi,
            "model": device.model,
            "serviceUuids": device.serviceUuids ?? []
        ]
    }

    private func euiccResultToJson<T>(_ result: EuiccResult<T>) -> String {
        var dict: [String: Any] = [
            "code": result.code ?? -1
        ]

        if let msg = result.msg {
            dict["msg"] = msg
        }
        if let title = result.title {
            dict["title"] = title
        }
        if let info = result.info {
            dict["info"] = info
        }

        if let data = result.data {
            if let device = data as? EuiccDevice {
                dict["data"] = euiccDeviceToJson(device)
            } else if let profiles = data as? [ProfileInfo] {
                let ps = profiles.map { profileToMap($0) }
                guard let jsonData = try? JSONSerialization.data(withJSONObject: ps,options: []),
                                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                                return "{}"
                     }
                dict["data"] = jsonString
            } else if let string = data as? String {
                dict["data"] = string
            } else {
                dict["data"] = "\(data)"
            }
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }

    private func euiccDeviceToMap(_ device: EuiccDevice) -> [String: Any?] {
        var dict: [String: Any?] = [:]
        dict["address"] = device.address ?? ""
        dict["eid"] = device.eid ?? ""
        dict["imei"] = device.imei
        dict["sn"] = device.sn
        dict["model"] = device.model
        dict["deviceName"] = device.deviceName
        dict["name"] = device.name
        dict["vendor"] = device.vendor
        dict["freeVolatileMemory"] = device.freeVolatileMemory ?? 0
        dict["freeNonVolatileMemory"] = device.freeNonVolatileMemory ?? 0
        return dict
    }

    private func euiccDeviceToJson(_ device: EuiccDevice) -> String {
        var dict: [String: Any?] = [:]
        dict["address"] = device.address ?? ""
        dict["eid"] = device.eid ?? ""
        dict["imei"] = device.imei
        dict["sn"] = device.sn
        dict["model"] = device.model
        dict["deviceName"] = device.deviceName
        dict["name"] = device.name
        dict["vendor"] = device.vendor
        dict["freeVolatileMemory"] = device.freeVolatileMemory ?? 0
        dict["freeNonVolatileMemory"] = device.freeNonVolatileMemory ?? 0
         guard let jsonData = try? JSONSerialization.data(withJSONObject: dict),
                      let jsonString = String(data: jsonData, encoding: .utf8) else {
                    return "{}"
         }
        return jsonString
    }

    private func profileToMap(_ profile: ProfileInfo) -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["iccid"] = profile.iccid ?? ""
        dict["profileName"] = profile.profileName ?? ""
        dict["state"] = profile.state ?? 0
        dict["profileClass"] = profile.profileClass ?? 0
        dict["mnc"] = profile.mnc ?? ""
        dict["mcc"] = profile.mcc ?? ""
        dict["imsi"] = profile.imsi ?? ""
        dict["nickname"] = profile.nickname ?? ""
        dict["serviceProviderName"] = profile.serviceProviderName ?? ""
        return dict
    }

    private func profileToJson(_ profile: ProfileInfo) -> String {
        var dict: [String: Any] = [:]
        dict["iccid"] = profile.iccid ?? ""
        dict["profileName"] = profile.profileName ?? ""
        dict["state"] = profile.state ?? 0
        dict["profileClass"] = profile.profileClass ?? 0
        dict["mnc"] = profile.mnc ?? ""
        dict["mcc"] = profile.mcc ?? ""
        dict["imsi"] = profile.imsi ?? ""
        dict["nickname"] = profile.nickname ?? ""
        dict["serviceProviderName"] = profile.serviceProviderName ?? ""
           guard let jsonData = try? JSONSerialization.data(withJSONObject: dict),
                              let jsonString = String(data: jsonData, encoding: .utf8) else {
                            return "{}"
                 }
                return jsonString
    }
}

// MARK: - BleScanCallback

extension LinklanEuiccPlugin: BleScanCallback {
    public func onDeviceFound(device: BleDevice) {
        bleDeviceMap[device.address] = device
        channel?.invokeMethod("onDeviceFound", arguments: deviceToMap(device))
    }

    public func onDeviceUpdated(device: BleDevice) {
        bleDeviceMap[device.address] = device
        channel?.invokeMethod("onDeviceUpdated", arguments: deviceToMap(device))
    }

    public func onScanStateChanged(isScanning: Bool) {
        channel?.invokeMethod("onScanStateChanged", arguments: isScanning)
    }

    public func onScanFailed(errorCode: Int, errorMsg: String) {
        channel?.invokeMethod("onScanFailed", arguments: [
            "errorCode": errorCode,
            "errorMsg": errorMsg
        ])
    }
}

// MARK: - BleUserAuthenticationListener

extension LinklanEuiccPlugin: BleUserAuthenticationListener {
    public func onPromptUserAuthentication(address: String?) -> String {
        var result = ""

        var authData: [String: Any] = [:]
        if let address = address {
            authData["address"] = address
        }


        let group = DispatchGroup()
        group.enter()
        channel?.invokeMethod("onUserAuthentication", arguments: authData) { response in
              if let password = response as? String {
                  result = password
              }
              group.leave()
        }

        group.wait()

        return result
    }
}

// MARK: - BleDeviceConnectionListener

extension LinklanEuiccPlugin: BleDeviceConnectionListener {
    public func onStatusChange(address: String?, status: String) {
        var data: [String: Any] = [:]
        data["address"] = address ?? ""
        data["status"] = status

        print("disconnected")
        print(address)
        // 如果是断开连接或错误，从设备映射中移除
        if status == "disconnected" || status == "error" {
//            if let addr = address {
//                euiccDeviceMap.removeValue(forKey: addr)
//            }
        }

        channel?.invokeMethod("onEuiccDeviceStatusChange", arguments: data)
    }
}

// MARK: - 扫描回调辅助类

private enum ScanEvent {
    case onDeviceFound
    case onDeviceUpdated
    case onScanStateChanged
    case onScanFailed
}

private class ScanCallback: NSObject, BleScanCallback {
    private let handler: (ScanEvent, Any?) -> Void

    init(handler: @escaping (ScanEvent, Any?) -> Void) {
        self.handler = handler
        super.init()
    }

    func onDeviceFound(device: BleDevice) {
        handler(.onDeviceFound, device)
    }

    func onDeviceUpdated(device: BleDevice) {
        handler(.onDeviceUpdated, device)
    }

    func onScanStateChanged(isScanning: Bool) {
        handler(.onScanStateChanged, isScanning)
    }

    func onScanFailed(errorCode: Int, errorMsg: String) {
        handler(.onScanFailed, ["errorCode": errorCode, "errorMsg": errorMsg])
    }
}
