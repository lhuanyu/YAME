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

enum DevicePerformanceLevel: String {
    case unsupported
    case minimal
    case recommended
    case optimal
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
        if memoryGB < 3.5 || freeMemoryGB < 3.0 || !hasMetal {
            return .unsupported
        } else if memoryGB < 4.5 || freeMemoryGB < 3.5 {
            return supportsNeuralEngine ? .minimal : .unsupported
        } else if memoryGB < 6.0 {
            return supportsNeuralEngine ? .recommended : .minimal
        } else {
            return supportsNeuralEngine ? .optimal : .recommended
        }
    }
    
    private static func getFreeMemoryInGB() -> Double {
        var pagesize: vm_size_t = 0
        host_page_size(mach_host_self(), &pagesize)
        
        var vmStats = vm_statistics64()
        var count = UInt32(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
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
#endif
