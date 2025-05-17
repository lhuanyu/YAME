//
//  DeviceCapability.swift
//  YAME
//
//  Created by LuoHuanyu on 2025/5/15.
//

#if os(iOS)
    import UIKit
    import Metal
    import CoreML

    enum DevicePerformanceLevel: String, RawRepresentable {
        case unsupported
        case minimal
        case recommended
        case optimal

        var isSupported: Bool {
            switch self {
            case .unsupported:
                return false
            case .minimal, .recommended, .optimal:
                return true
            }
        }
    }

    struct DeviceCapability {

        static func getPerformanceLevel() -> DevicePerformanceLevel {
            let physicalMemory = ProcessInfo.processInfo.physicalMemory
            let memoryGB = Double(physicalMemory) / (1024.0 * 1024.0 * 1024.0)

            // Check Metal (GPU) support
            let hasMetal = MTLCreateSystemDefaultDevice() != nil

            // Check for Core ML / Neural Engine capability
            let supportsNeuralEngine: Bool = {
                if #available(iOS 14.0, *) {
                    let config = MLModelConfiguration()
                    return config.computeUnits != .cpuOnly
                }
                return false
            }()

            // Check Free Memory (approximate)
            let freeMemoryGB = getFreeMemoryInGB()

            // --- Grading Logic ---
            
            // If no Metal support, return unsupported
            if !hasMetal {
                return .unsupported
            }
            // If no Neural Engine support, return unsupported
            if !supportsNeuralEngine {
                return .unsupported
            }
                        
            if memoryGB < 5.0 {
                return .unsupported
            } else if memoryGB < 6.0 {
                return .minimal
            } else if memoryGB < 8.0 {
                return .recommended
            } else {
                return .optimal
            }
        }

        private static func getFreeMemoryInGB() -> Double {
            var pagesize: vm_size_t = 0
            host_page_size(mach_host_self(), &pagesize)

            var vmStats = vm_statistics64()
            var count = UInt32(
                MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
            let result = withUnsafeMutablePointer(to: &vmStats) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
                }
            }

            guard result == KERN_SUCCESS else {
                return 0.0
            }

            let freeMemory = UInt64(vmStats.free_count + vmStats.inactive_count) * UInt64(pagesize)
            return Double(freeMemory) / (1024.0 * 1024.0 * 1024.0)
        }
    }

    // Struct for device capability details
    struct DeviceCapabilityDetails {
        let performanceLevel: DevicePerformanceLevel
        let memoryGB: Double
        let freeMemoryGB: Double
        let hasMetal: Bool
        let supportsNeuralEngine: Bool
    }

    extension DeviceCapability {
        /// Test device capability and return all details
        static func testAndFetchDetails() -> DeviceCapabilityDetails {
            let physicalMemory = ProcessInfo.processInfo.physicalMemory
            let memoryGB = Double(physicalMemory) / (1024.0 * 1024.0 * 1024.0)
            let freeMemoryGB = getFreeMemoryInGB()
            let hasMetal = MTLCreateSystemDefaultDevice() != nil
            let supportsNeuralEngine: Bool
            if #available(iOS 14.0, *) {
                let config = MLModelConfiguration()
                supportsNeuralEngine = config.computeUnits != .cpuOnly
            } else {
                supportsNeuralEngine = false
            }
            let performanceLevel = getPerformanceLevel()
            return DeviceCapabilityDetails(
                performanceLevel: performanceLevel,
                memoryGB: memoryGB,
                freeMemoryGB: freeMemoryGB,
                hasMetal: hasMetal,
                supportsNeuralEngine: supportsNeuralEngine
            )
        }
    }
#endif
