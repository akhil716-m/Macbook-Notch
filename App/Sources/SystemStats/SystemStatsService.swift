import Darwin
import Foundation
import IOKit.ps
import NotchCore

/// CPU, memory, network, disk and battery readings, sampled once a second
/// (disk every ten), and only while the System tool is on screen.
@MainActor
final class SystemStatsService: ObservableObject {
    @Published private(set) var cpu: Double?
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var memory: MemoryUsage?
    @Published private(set) var network: NetworkRate = .zero
    @Published private(set) var disk: DiskUsage?
    /// Nil on Macs without a battery.
    @Published private(set) var battery: BatteryStatus?

    static let historyLength = 40
    private static let interval: TimeInterval = 1

    private var viewers = 0
    private var timer: Timer?
    private var previousTicks: [CPUTicks]?
    private var previousNetwork: [String: InterfaceCounters]?
    private var previousTime: TimeInterval?
    private var samplesSinceDisk = 0

    func beginViewing() {
        viewers += 1
        guard viewers == 1 else { return }
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        timer?.tolerance = 0.2
    }

    func endViewing() {
        viewers = max(0, viewers - 1)
        guard viewers == 0 else { return }
        timer?.invalidate()
        timer = nil
        previousTicks = nil
        previousNetwork = nil
        previousTime = nil
    }

    private func sample() {
        let now = ProcessInfo.processInfo.systemUptime

        if let ticks = SystemSampler.cpuTicks() {
            if let previousTicks, let usage = CPULoad.usage(previous: previousTicks, current: ticks) {
                cpu = usage
                cpuHistory.append(usage)
                if cpuHistory.count > Self.historyLength {
                    cpuHistory.removeFirst(cpuHistory.count - Self.historyLength)
                }
            }
            previousTicks = ticks
        }

        memory = SystemSampler.memory()
        battery = SystemSampler.battery()
        if disk == nil || samplesSinceDisk >= 10 {
            disk = SystemSampler.disk()
            samplesSinceDisk = 0
        }
        samplesSinceDisk += 1

        let counters = SystemSampler.networkCounters()
        if let previousNetwork, let previousTime {
            network = NetworkRate.between(previousNetwork, counters, seconds: now - previousTime)
        }
        previousNetwork = counters
        previousTime = now
    }
}

/// Thin wrappers over the kernel calls Activity Monitor uses.
enum SystemSampler {
    /// Space on the startup disk. "Available" counts purgeable space macOS
    /// would free on demand, as Finder does.
    static func disk() -> DiskUsage? {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let available = values.volumeAvailableCapacityForImportantUsage,
              let total = values.volumeTotalCapacity
        else { return nil }
        return DiskUsage(available: available, total: Int64(total))
    }

    static func battery() -> BatteryStatus? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue()
        else { return nil }
        for source in (list as NSArray) as [AnyObject] {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let battery = BatteryStatus(powerSource: description)
            else { continue }
            return battery
        }
        return nil
    }

    static func cpuTicks() -> [CPUTicks]? {
        var processorCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &processorCount, &info, &infoCount)
        guard result == KERN_SUCCESS, let info else { return nil }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: info)),
                vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)
            )
        }
        let states = Int(CPU_STATE_MAX)
        return (0..<Int(processorCount)).map { cpu in
            let base = cpu * states
            func ticks(_ state: Int32) -> UInt64 {
                UInt64(UInt32(bitPattern: info[base + Int(state)]))
            }
            return CPUTicks(
                user: ticks(CPU_STATE_USER),
                system: ticks(CPU_STATE_SYSTEM),
                idle: ticks(CPU_STATE_IDLE),
                nice: ticks(CPU_STATE_NICE)
            )
        }
    }

    static func memory() -> MemoryUsage? {
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else { return nil }
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let capacity = Int(count)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) { raw in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, raw, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return MemoryUsage.fromPages(
            appPages: UInt64(stats.internal_page_count),
            purgeable: UInt64(stats.purgeable_count),
            wired: UInt64(stats.wire_count),
            compressed: UInt64(stats.compressor_page_count),
            pageSize: UInt64(pageSize),
            total: ProcessInfo.processInfo.physicalMemory
        )
    }

    static func networkCounters() -> [String: InterfaceCounters] {
        var result: [String: InterfaceCounters] = [:]
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0 else { return result }
        defer { freeifaddrs(head) }
        var cursor = head
        while let entry = cursor?.pointee {
            cursor = entry.ifa_next
            guard let address = entry.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_LINK),
                  let data = entry.ifa_data
            else { continue }
            let name = String(cString: entry.ifa_name)
            guard NetworkRate.isCounted(interface: name) else { continue }
            let stats = data.assumingMemoryBound(to: if_data.self).pointee
            result[name] = InterfaceCounters(received: stats.ifi_ibytes, sent: stats.ifi_obytes)
        }
        return result
    }
}
