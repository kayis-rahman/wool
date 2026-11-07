import Foundation

/**
 * Mock EventSource for Server-Sent Events
 */
class EventSource {
    private var url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    func onOpen(_ callback: (() -> Void)?) {
        // Mock implementation
    }
    
    func onMessage(_ callback: ((String?) -> Void)?) {
        // Mock implementation
    }
    
    func onError(_ callback: ((Error?) -> Void)?) {
        // Mock implementation
    }
    
    func close() {
        // Mock implementation
    }
}