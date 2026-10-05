import Cocoa
import CoreBluetooth
import CoreWLAN
import FlutterMacOS
import Foundation

/// Window `presentWindow` orders front. Cleared on close so a later call
/// returns `windowMissing` instead of touching a freed window.
enum MacosWindowHolder {
  static weak var window: NSWindow?
}

/// Channel `com.brukb.blan/macos`. Manufacturer payload is company id
/// `0xFDA9` little-endian (`D9 FD`) plus the 31-byte advert. Hotspot and
/// Wi-Fi Direct reply the typed failure: macOS has no local-only AP API.
final class MacosProximityPlugin: NSObject, CBPeripheralManagerDelegate, CBCentralManagerDelegate, CBPeripheralDelegate {
  static let channelName = "com.brukb.blan/macos"
  static let bleService = CBUUID(string: "0000fda9-0000-1000-8000-00805f9b34fb")
  static let gattService = CBUUID(string: "9f1c2b3a-4d5e-4f60-8a1b-2c3d4e5f6a7b")
  static let gattCharacteristic = CBUUID(string: "9f1c2b3a-4d5e-4f60-8a1b-2c3d4e5f6a7c")
  static let frameCap = 64 * 1024

  private static var shared: MacosProximityPlugin?

  static func register(messenger: FlutterBinaryMessenger) {
    if shared != nil {
      return
    }
    let plugin = MacosProximityPlugin(messenger: messenger)
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

  private init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    scanEvents = FlutterEventChannel(name: "\(Self.channelName)/scans", binaryMessenger: messenger)
    inboundEvents = FlutterEventChannel(name: "\(Self.channelName)/inbound", binaryMessenger: messenger)
    frameEvents = FlutterEventChannel(name: "\(Self.channelName)/frames", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.onMethod(call, result: result)
    }
    scanEvents.setStreamHandler(_Sink(
      onListen: { [weak self] sink in self?.scanSink = sink },
      onCancel: { [weak self] in self?.scanSink = nil }
    ))
    inboundEvents.setStreamHandler(_Sink(
      onListen: { [weak self] sink in self?.inboundSink = sink },
      onCancel: { [weak self] in self?.inboundSink = nil }
    ))
    frameEvents.setStreamHandler(_Sink(
      onListen: { [weak self] sink in self?.frameSink = sink },
      onCancel: { [weak self] in self?.frameSink = nil }
    ))
  }

  private func onMethod(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "currentWifi":
      currentWifi(result: result)
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
      CWWiFiClient.shared().interface()?.disassociate()
      result(nil)
    case "presentWindow":
      presentWindow(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func currentWifi(result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      guard let iface = CWWiFiClient.shared().interface() else {
        self.reply(result, nil)
        return
      }
      var ssid = iface.ssid()
      if ssid == nil || ssid?.isEmpty == true, let device = iface.interfaceName {
        ssid = self.ssidFromNetworksetup(device: device)
      }
      guard let ssid, !ssid.isEmpty else {
        self.reply(result, nil)
        return
      }
      let security: String
      switch iface.security() {
      case .wpa2Personal:
        security = "wpa2-psk"
      case .wpa3Personal:
        security = "wpa3-sae"
      default:
        security = "other"
      }
      self.reply(result, ["ssid": ssid, "security": security])
    }
  }

  /// `networksetup -getairportnetwork`. Output is not logged.
  private func ssidFromNetworksetup(device: String) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
    process.arguments = ["-getairportnetwork", device]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do {
      try process.run()
      process.waitUntilExit()
    } catch {
      return nil
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let text = String(data: data, encoding: .utf8) else {
      return nil
    }
    let prefix = "Current Wi-Fi Network: "
    for line in text.split(separator: "\n") {
      if line.hasPrefix(prefix) {
        let name = String(line.dropFirst(prefix.count))
        return name.isEmpty ? nil : name
      }
    }
    return nil
  }

  private func startAdvert(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    guard let payload = data(args?["payload"]), payload.count == 31 else {
      result(["error": "advertFailed"])
      return
    }
    advertPayload = payload
    advertNick = data(args?["scanResponse"]) ?? Data()
    advertToken += 1
    let token = advertToken
    pendingAdvert = result
    ensurePeripheral()
    beginAdvert()
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
      guard let self, self.advertToken == token else { return }
      let pending = self.pendingAdvert
      self.pendingAdvert = nil
      pending?(["error": "advertFailed"])
    }
  }

  private func beginAdvert() {
    guard pendingAdvert != nil, let peripheral, peripheral.state == .poweredOn, let payload = advertPayload else {
      return
    }
    var manufacturer = Data([0xD9, 0xFD])
    manufacturer.append(payload)
    let nick = advertNick ?? Data()
    peripheral.stopAdvertising()
    peripheral.startAdvertising([
      CBAdvertisementDataManufacturerDataKey: manufacturer,
      CBAdvertisementDataServiceDataKey: [Self.bleService: nick],
    ])
  }

  private func startScan(result: @escaping FlutterResult) {
    scanWanted = true
    ensureCentral()
    if central?.state == .poweredOn {
      central?.scanForPeripherals(
        withServices: nil,
        options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
      )
      result(nil)
      return
    }
    if let state = central?.state, Self.radioOff(state) {
      scanWanted = false
      result(["error": "scanFailed"])
      return
    }
    pendingScan = result
  }

  private static func radioOff(_ state: CBManagerState) -> Bool {
    state == .poweredOff || state == .unauthorized || state == .unsupported
  }

  private func startListening(result: @escaping FlutterResult) {
    listening = true
    listenToken += 1
    let token = listenToken
    pendingListen = result
    ensurePeripheral()
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
      properties: [.write, .writeWithoutResponse],
      value: nil,
      permissions: [.writeable]
    )
    let service = CBMutableService(type: Self.gattService, primary: true)
    service.characteristics = [characteristic]
    gattChar = characteristic
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
    if let linkId {
      clients.removeValue(forKey: linkId)
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
    guard let ssid = args?["ssid"] as? String, let passphrase = args?["passphrase"] as? String else {
      result(["error": "joinFailed"])
      return
    }
    DispatchQueue.global(qos: .userInitiated).async {
      guard let iface = CWWiFiClient.shared().interface() else {
        self.reply(result, ["error": "joinFailed"])
        return
      }
      do {
        let networks = try iface.scanForNetworks(withSSID: Data(ssid.utf8))
        guard let network = networks.first else {
          self.reply(result, ["error": "joinFailed"])
          return
        }
        try iface.associate(to: network, password: passphrase)
        self.reply(result, nil)
      } catch {
        self.reply(result, ["error": "joinFailed"])
      }
    }
  }

  private func presentWindow(result: @escaping FlutterResult) {
    guard let window = MacosWindowHolder.window else {
      result(FlutterError(code: "windowMissing", message: "no window", details: nil))
      return
    }
    window.deminiaturize(nil)
    window.makeKeyAndOrderFront(nil)
    if #available(macOS 14.0, *) {
      NSApp.activate()
    } else {
      NSApp.activate(ignoringOtherApps: true)
    }
    result(nil)
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
      if peripheral.state == .poweredOff || peripheral.state == .unauthorized || peripheral.state == .unsupported {
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
    let pending = pendingAdvert
    pendingAdvert = nil
    if error != nil {
      pending?(["error": "advertFailed"])
    } else {
      pending?(nil)
    }
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
    let pending = pendingListen
    pendingListen = nil
    if error != nil {
      gattChar = nil
      pending?(["error": "listenFailed"])
    } else {
      pending?(nil)
    }
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
    // 33 = 2-byte id + 31-byte payload (extended set); 18 = id + the first 16
    // payload bytes (legacy set, the rest is zero padding).
    guard (manufacturer.count == 33 || manufacturer.count == 18),
          manufacturer[0] == 0xD9, manufacturer[1] == 0xFD else {
      return
    }
    var payload = manufacturer.subdata(in: 2..<manufacturer.count)
    if payload.count < 31 {
      payload.append(Data(repeating: 0, count: 31 - payload.count))
    }
    let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data]
    let nick = serviceData?[Self.bleService] ?? Data()
    scanSink?([
      "peerHandle": peripheral.identifier.uuidString,
      "advert": FlutterStandardTypedData(bytes: payload),
      "scanResponse": FlutterStandardTypedData(bytes: nick),
    ])
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
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

private final class _Sink: NSObject, FlutterStreamHandler {
  init(onListen: @escaping (FlutterEventSink) -> Void, onCancel: @escaping () -> Void) {
    self.onListenHandler = onListen
    self.onCancelHandler = onCancel
  }

  private let onListenHandler: (FlutterEventSink) -> Void
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
