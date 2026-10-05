import CoreBluetooth
import Flutter
import Foundation
import NetworkExtension
import UIKit
import UserNotifications

/// Channel `com.brukb.blan/ios`. iOS `startAdvertising` carries only a local
/// name and service UUIDs, so the 31-byte payload is the GATT read value.
/// Hotspot and Wi-Fi Direct reply the typed failure.
final class IosProximityPlugin: NSObject, CBPeripheralManagerDelegate, CBCentralManagerDelegate, CBPeripheralDelegate {
  static let channelName = "com.brukb.blan/ios"
  static let bleService = CBUUID(string: "0000fda9-0000-1000-8000-00805f9b34fb")
  static let gattService = CBUUID(string: "9f1c2b3a-4d5e-4f60-8a1b-2c3d4e5f6a7b")
  static let gattCharacteristic = CBUUID(string: "9f1c2b3a-4d5e-4f60-8a1b-2c3d4e5f6a7c")
  static let frameCap = 64 * 1024

  private static var shared: IosProximityPlugin?

  static func register(messenger: FlutterBinaryMessenger) {
    if shared != nil {
      return
    }
    let plugin = IosProximityPlugin(messenger: messenger)
    shared = plugin
  }

  private let channel: FlutterMethodChannel
  private let scanEvents: FlutterEventChannel
  private let inboundEvents: FlutterEventChannel
  private let frameEvents: FlutterEventChannel
  private var scanSink: FlutterEventSink?
  private var inboundSink: FlutterEventSink?
  private var frameSink: FlutterEventSink?

  private var peripheral: CBPeripheralManager?
  private var central: CBCentralManager?
  private var advertPayload: Data?
  private var advertNick: Data?
  private var pendingAdvert: FlutterResult?
  private var advertToken = 0
  private var listening = false
  private var gattChar: CBMutableCharacteristic?
  private var pendingListen: FlutterResult?
  private var listenToken = 0

  private var nextLinkId = 1
  private var serverBuffers: [String: Data] = [:]
  private var serverLinks: [String: Int] = [:]
  private var seen: [UUID: CBPeripheral] = [:]
  private var clients: [Int: CBPeripheral] = [:]
  private var clientChars: [Int: CBCharacteristic] = [:]
  private var outQueues: [Int: [Data]] = [:]
  private var writing: Set<Int> = []
  private var pendingConnect: (token: Int, linkId: Int, result: FlutterResult)?
  private var connectsByToken: [Int: Int] = [:]
  private var connectTokens: [UUID: Int] = [:]
  private var pendingPeripheral: CBPeripheral?
  private var connectToken = 0
  private var scanWanted = false
  private var pendingScan: FlutterResult?
  private var inflightAdvertToken = 0
  private var inflightListenToken = 0
  private var joinedSsid: String?

  private init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    scanEvents = FlutterEventChannel(name: "\(Self.channelName)/scans", binaryMessenger: messenger)
    inboundEvents = FlutterEventChannel(name: "\(Self.channelName)/inbound", binaryMessenger: messenger)
    frameEvents = FlutterEventChannel(name: "\(Self.channelName)/frames", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.onMethod(call, result: result)
    }
    scanEvents.setStreamHandler(_IosSink(
      onListen: { [weak self] sink in self?.scanSink = sink },
      onCancel: { [weak self] in self?.scanSink = nil }
    ))
    inboundEvents.setStreamHandler(_IosSink(
      onListen: { [weak self] sink in self?.inboundSink = sink },
      onCancel: { [weak self] in self?.inboundSink = nil }
    ))
    frameEvents.setStreamHandler(_IosSink(
      onListen: { [weak self] sink in self?.frameSink = sink },
      onCancel: { [weak self] in self?.frameSink = nil }
    ))
  }

  private func onMethod(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startAdvert":
      startAdvert(call: call, result: result)
    case "stopAdvert":
      peripheral?.stopAdvertising()
      advertPayload = nil
      advertToken += 1
      let pending = pendingAdvert
      pendingAdvert = nil
      pending?(nil)
      result(nil)
    case "startScan":
      startScan(result: result)
    case "stopScan":
      scanWanted = false
      central?.stopScan()
      let pending = pendingScan
      pendingScan = nil
      pending?(nil)
      result(nil)
    case "connectControl":
      connectControl(call: call, result: result)
    case "startListening":
      startListening(result: result)
    case "stopListening":
      stopListening()
      result(nil)
    case "sendFrame":
      sendFrame(call: call, result: result)
    case "closeLink":
      closeLink(call: call, result: result)
    case "startHotspot":
      result(["error": "hotspotFailed"])
    case "stopHotspot":
      result(nil)
    case "startWifiDirect":
      result(["error": "wifiDirectFailed"])
    case "stopWifiDirect":
      result(nil)
    case "join":
      join(call: call, result: result)
    case "leaveJoined":
      leaveJoined(result: result)
    case "presentInvite":
      presentInvite(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startAdvert(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    guard let payload = data(args?["payload"]), payload.count == 31 else {
      result(["error": "advertFailed"])
      return
    }
    advertPayload = payload
    advertNick = data(args?["scanResponse"]) ?? Data()
    ensurePeripheral()
    if let state = peripheral?.state, Self.radioOff(state) {
      result(["error": "advertFailed"])
      return
    }
    advertToken += 1
    let token = advertToken
    let previous = pendingAdvert
    pendingAdvert = result
    previous?(nil)
    beginAdvert()
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
      guard let self, self.advertToken == token else { return }
      let pending = self.pendingAdvert
      self.pendingAdvert = nil
      pending?(["error": "advertFailed"])
    }
  }

  /// Service UUID plus a local name. Manufacturer data is not an iOS advert key.
  private func beginAdvert() {
    guard pendingAdvert != nil, let peripheral, peripheral.state == .poweredOn else {
      return
    }
    var advert: [String: Any] = [
      CBAdvertisementDataServiceUUIDsKey: [Self.bleService],
    ]
    if let name = localName(from: advertNick ?? Data()) {
      advert[CBAdvertisementDataLocalNameKey] = name
    }
    inflightAdvertToken = advertToken
    peripheral.stopAdvertising()
    peripheral.startAdvertising(advert)
  }

  private func localName(from nick: Data) -> String? {
    let decoded = String(decoding: nick, as: UTF8.self)
    let name = String(decoded.unicodeScalars.prefix(20))
    return name.isEmpty ? nil : name
  }

  private func startScan(result: @escaping FlutterResult) {
    scanWanted = true
    ensureCentral()
    if central?.state == .poweredOn {
      central?.scanForPeripherals(
        withServices: nil,
        options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
      )
      let previous = pendingScan
      pendingScan = nil
      previous?(nil)
      result(nil)
      return
    }
    if let state = central?.state, Self.radioOff(state) {
      scanWanted = false
      let previous = pendingScan
      pendingScan = nil
      previous?(["error": "scanFailed"])
      result(["error": "scanFailed"])
      return
    }
    let previous = pendingScan
    pendingScan = result
    previous?(nil)
  }

  private static func radioOff(_ state: CBManagerState) -> Bool {
    state == .poweredOff || state == .unauthorized || state == .unsupported
  }

  private func startListening(result: @escaping FlutterResult) {
    ensurePeripheral()
    if let state = peripheral?.state, Self.radioOff(state) {
      result(["error": "listenFailed"])
      return
    }
    listening = true
    listenToken += 1
    let token = listenToken
    let previous = pendingListen
    pendingListen = result
    previous?(nil)
    beginListen()
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
      guard let self, self.listenToken == token else { return }
      let pending = self.pendingListen
      self.pendingListen = nil
      pending?(["error": "listenFailed"])
    }
  }

  private func beginListen() {
    guard listening, gattChar == nil, let peripheral, peripheral.state == .poweredOn else {
      return
    }
    let characteristic = CBMutableCharacteristic(
      type: Self.gattCharacteristic,
      properties: [.read, .write, .writeWithoutResponse],
      value: nil,
      permissions: [.readable, .writeable]
    )
    let service = CBMutableService(type: Self.gattService, primary: true)
    service.characteristics = [characteristic]
    gattChar = characteristic
    inflightListenToken = listenToken
    peripheral.add(service)
  }

  private func stopListening() {
    listening = false
    listenToken += 1
    let pending = pendingListen
    pendingListen = nil
    pending?(nil)
    gattChar = nil
    serverBuffers.removeAll()
    peripheral?.removeAllServices()
  }

  private func connectControl(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    guard let handle = args?["peerHandle"] as? String, let uuid = UUID(uuidString: handle) else {
      result(["error": "connectFailed"])
      return
    }
    ensureCentral()
    if let state = central?.state, Self.radioOff(state) {
      result(["error": "connectFailed"])
      return
    }
    let peripheral = seen[uuid] ?? central?.retrievePeripherals(withIdentifiers: [uuid]).first
    guard let peripheral, let central else {
      result(["error": "connectFailed"])
      return
    }
    let linkId = nextLinkId
    nextLinkId += 1
    clients[linkId] = peripheral
    peripheral.delegate = self
    connectToken += 1
    let token = connectToken
    connectsByToken[token] = linkId
    connectTokens[peripheral.identifier] = token
    pendingPeripheral = peripheral
    if let previous = pendingConnect, previous.token != token {
      failConnect(token: previous.token)
    }
    pendingConnect = (token, linkId, result)
    if central.state == .poweredOn {
      pendingPeripheral = nil
      central.connect(peripheral, options: nil)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
      self?.failConnect(token: token)
    }
  }

  private func failConnect(token: Int) {
    let linkId = connectsByToken.removeValue(forKey: token)
    if let linkId, let peripheral = clients.removeValue(forKey: linkId) {
      central?.cancelPeripheralConnection(peripheral)
      clientChars.removeValue(forKey: linkId)
      outQueues.removeValue(forKey: linkId)
      writing.remove(linkId)
    }
    guard let pending = pendingConnect, pending.token == token else { return }
    pendingConnect = nil
    pendingPeripheral = nil
    pending.result(["error": "connectFailed"])
  }

  private func intValue(_ value: Any?) -> Int? {
    if let number = value as? NSNumber {
      return number.intValue
    }
    return value as? Int
  }

  private func sendFrame(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    guard let linkId = intValue(args?["linkId"]),
          let frameJson = args?["frameJson"] as? String,
          let peripheral = clients[linkId],
          let characteristic = clientChars[linkId]
    else {
      result(["error": "sendFailed"])
      return
    }
    let body = Data(frameJson.utf8)
    if body.isEmpty || body.count > Self.frameCap {
      result(["error": "sendFailed"])
      return
    }
    var frame = Data()
    var length = UInt32(body.count).bigEndian
    withUnsafeBytes(of: &length) { frame.append(contentsOf: $0) }
    frame.append(body)
    let chunkSize = max(peripheral.maximumWriteValueLength(for: .withResponse), 20)
    var queue = outQueues[linkId] ?? []
    var offset = 0
    while offset < frame.count {
      let end = min(offset + chunkSize, frame.count)
      queue.append(frame.subdata(in: offset..<end))
      offset = end
    }
    outQueues[linkId] = queue
    pump(linkId, peripheral: peripheral, characteristic: characteristic)
    result(nil)
  }

  private func pump(_ linkId: Int, peripheral: CBPeripheral, characteristic: CBCharacteristic) {
    guard !writing.contains(linkId) else { return }
    guard var queue = outQueues[linkId], !queue.isEmpty else { return }
    let chunk = queue.removeFirst()
    outQueues[linkId] = queue
    writing.insert(linkId)
    peripheral.writeValue(chunk, for: characteristic, type: .withResponse)
  }

  private func closeLink(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    guard let linkId = intValue(args?["linkId"]) else {
      result(["error": "badArgs"])
      return
    }
    if let peripheral = clients.removeValue(forKey: linkId) {
      central?.cancelPeripheralConnection(peripheral)
    }
    clientChars.removeValue(forKey: linkId)
    outQueues.removeValue(forKey: linkId)
    writing.remove(linkId)
    result(nil)
  }

  private func join(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    guard let ssid = args?["ssid"] as? String, !ssid.isEmpty,
          let passphrase = args?["passphrase"] as? String,
          let security = args?["security"] as? String,
          security == "wpa2-psk" || security == "wpa3-sae"
    else {
      result(["error": "joinFailed"])
      return
    }
    let config = NEHotspotConfiguration(ssid: ssid, passphrase: passphrase, isWEP: false)
    config.joinOnce = true
    NEHotspotConfigurationManager.shared.apply(config) { error in
      if error != nil {
        self.reply(result, ["error": "joinFailed"])
        return
      }
      self.joinedSsid = ssid
      self.reply(result, nil)
    }
  }

  private func leaveJoined(result: @escaping FlutterResult) {
    if let ssid = joinedSsid {
      NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
      joinedSsid = nil
    }
    result(nil)
  }

  private func presentInvite(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
      guard granted, error == nil else {
        self.reply(result, FlutterError(code: "notifyFailed", message: "notification denied", details: nil))
        return
      }
      let content = UNMutableNotificationContent()
      content.title = "B-LAN"
      content.body = "Nearby invite"
      let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil
      )
      UNUserNotificationCenter.current().add(request) { addError in
        if addError != nil {
          self.reply(result, FlutterError(code: "notifyPostFailed", message: "notification was not posted", details: nil))
        } else {
          self.reply(result, nil)
        }
      }
    }
  }

  private func ensurePeripheral() {
    if peripheral == nil {
      peripheral = CBPeripheralManager(delegate: self, queue: .main)
    }
  }

  private func ensureCentral() {
    if central == nil {
      central = CBCentralManager(delegate: self, queue: .main)
    }
  }

  private func reply(_ result: @escaping FlutterResult, _ value: Any?) {
    if Thread.isMainThread {
      result(value)
    } else {
      DispatchQueue.main.async { result(value) }
    }
  }

  private func data(_ value: Any?) -> Data? {
    if let typed = value as? FlutterStandardTypedData {
      return typed.data
    }
    if let data = value as? Data {
      return data
    }
    return nil
  }

  private func emitInbound(_ key: String) -> Int {
    if let existing = serverLinks[key] {
      return existing
    }
    let linkId = nextLinkId
    nextLinkId += 1
    serverLinks[key] = linkId
    inboundSink?(["linkId": linkId, "transport": "gatt"])
    return linkId
  }

  private func drainServer(_ buffer: Data, linkId: Int) -> Data {
    var buffer = buffer
    while buffer.count >= 4 {
      let length = (Int(buffer[0]) << 24) | (Int(buffer[1]) << 16) | (Int(buffer[2]) << 8) | Int(buffer[3])
      if length <= 0 || length > Self.frameCap {
        return Data()
      }
      if buffer.count < 4 + length {
        return buffer
      }
      let body = buffer.subdata(in: 4..<(4 + length))
      buffer.removeSubrange(0..<(4 + length))
      if let json = String(data: body, encoding: .utf8) {
        frameSink?(["linkId": linkId, "frameJson": json])
      }
    }
    return buffer
  }

  private func clientLinkId(_ peripheral: CBPeripheral) -> Int? {
    clients.first { $0.value.identifier == peripheral.identifier }?.key
  }

  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    guard peripheral.state == .poweredOn else {
      if Self.radioOff(peripheral.state) {
        let advert = pendingAdvert
        pendingAdvert = nil
        advert?(["error": "advertFailed"])
        let listen = pendingListen
        pendingListen = nil
        listen?(["error": "listenFailed"])
      }
      return
    }
    beginAdvert()
    beginListen()
  }

  func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
    guard inflightAdvertToken == advertToken else { return }
    let pending = pendingAdvert
    pendingAdvert = nil
    if error != nil {
      pending?(["error": "advertFailed"])
    } else {
      pending?(nil)
    }
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
    guard inflightListenToken == listenToken else { return }
    let pending = pendingListen
    pendingListen = nil
    if error != nil {
      gattChar = nil
      pending?(["error": "listenFailed"])
    } else {
      pending?(nil)
    }
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
    guard request.characteristic.uuid == Self.gattCharacteristic, let payload = advertPayload else {
      peripheral.respond(to: request, withResult: .attributeNotFound)
      return
    }
    if request.offset > payload.count {
      peripheral.respond(to: request, withResult: .invalidOffset)
      return
    }
    request.value = payload.subdata(in: request.offset..<payload.count)
    peripheral.respond(to: request, withResult: .success)
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
    for request in requests {
      let key = request.central.identifier.uuidString
      let linkId = emitInbound(key)
      var buffer = serverBuffers[key] ?? Data()
      if let value = request.value {
        buffer.append(value)
      }
      serverBuffers[key] = drainServer(buffer, linkId: linkId)
      peripheral.respond(to: request, withResult: .success)
    }
  }

  func peripheralManager(
    _ peripheral: CBPeripheralManager,
    central: CBCentral,
    didSubscribeTo characteristic: CBCharacteristic
  ) {
    _ = emitInbound(central.identifier.uuidString)
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    guard central.state == .poweredOn else {
      if Self.radioOff(central.state) {
        scanWanted = false
        let pending = pendingScan
        pendingScan = nil
        pending?(["error": "scanFailed"])
        if let connect = pendingConnect {
          failConnect(token: connect.token)
        }
      }
      return
    }
    if scanWanted {
      central.scanForPeripherals(
        withServices: nil,
        options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
      )
      let pending = pendingScan
      pendingScan = nil
      pending?(nil)
    }
    if let waiting = pendingPeripheral, pendingConnect != nil {
      pendingPeripheral = nil
      central.connect(waiting, options: nil)
    }
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    seen[peripheral.identifier] = peripheral
    guard let manufacturer = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data else {
      return
    }
    guard manufacturer.count == 33, manufacturer[0] == 0xD9, manufacturer[1] == 0xFD else {
      return
    }
    let payload = manufacturer.subdata(in: 2..<33)
    let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data]
    let nick = serviceData?[Self.bleService] ?? Data()
    scanSink?([
      "peerHandle": peripheral.identifier.uuidString,
      "advert": FlutterStandardTypedData(bytes: payload),
      "scanResponse": FlutterStandardTypedData(bytes: nick),
    ])
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    guard let token = connectTokens[peripheral.identifier], connectsByToken[token] != nil else {
      return
    }
    peripheral.delegate = self
    peripheral.discoverServices([Self.gattService])
  }

  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    if let token = connectTokens[peripheral.identifier] {
      failConnect(token: token)
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == Self.gattService }) else {
      if let token = connectTokens[peripheral.identifier] {
        failConnect(token: token)
      }
      return
    }
    peripheral.discoverCharacteristics([Self.gattCharacteristic], for: service)
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    guard let token = connectTokens[peripheral.identifier], connectsByToken[token] != nil else {
      return
    }
    guard error == nil,
          let characteristic = service.characteristics?.first(where: { $0.uuid == Self.gattCharacteristic }),
          let linkId = clientLinkId(peripheral),
          let pending = pendingConnect,
          pending.token == token,
          pending.linkId == linkId
    else {
      failConnect(token: token)
      return
    }
    connectsByToken.removeValue(forKey: token)
    clientChars[linkId] = characteristic
    pendingConnect = nil
    pending.result(linkId)
  }

  func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
    guard let linkId = clientLinkId(peripheral), let stored = clientChars[linkId] else { return }
    writing.remove(linkId)
    if error != nil {
      outQueues[linkId] = []
      return
    }
    pump(linkId, peripheral: peripheral, characteristic: stored)
  }
}

private final class _IosSink: NSObject, FlutterStreamHandler {
  init(onListen: @escaping (@escaping FlutterEventSink) -> Void, onCancel: @escaping () -> Void) {
    self.onListenHandler = onListen
    self.onCancelHandler = onCancel
  }

  private let onListenHandler: (@escaping FlutterEventSink) -> Void
  private let onCancelHandler: () -> Void

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    onListenHandler(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    onCancelHandler()
    return nil
  }
}
