import Foundation
import CommonCrypto

/// AES-128 in ECB mode with PKCS7 padding — exactly what the Oura ring's auth
/// handshake expects: encrypt the 15-byte nonce with your ring's 16-byte key and
/// send back the resulting 16-byte block.
///
/// (CryptoKit deliberately doesn't expose ECB because it's unsafe for general use;
/// here the "message" is a single one-shot challenge nonce, so ECB is fine and is
/// what the device protocol requires.)
enum AESECB {
    static func encrypt(_ data: Data, key: Data) -> Data? {
        guard key.count == kCCKeySizeAES128 else { return nil }
        let bufferSize = data.count + kCCBlockSizeAES128
        var output = Data(count: bufferSize)
        var numBytesEncrypted = 0

        let status = output.withUnsafeMutableBytes { outBytes in
            data.withUnsafeBytes { dataBytes in
                key.withUnsafeBytes { keyBytes in
                    CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionECBMode | kCCOptionPKCS7Padding),
                        keyBytes.baseAddress, key.count,
                        nil, // ECB uses no IV
                        dataBytes.baseAddress, data.count,
                        outBytes.baseAddress, bufferSize,
                        &numBytesEncrypted
                    )
                }
            }
        }

        guard Int(status) == kCCSuccess else { return nil }
        output.removeSubrange(numBytesEncrypted..<output.count)
        return output
    }
}

extension Data {
    /// Parse a hex string ("a1b2…") into bytes; nil if malformed.
    init?(hexString: String) {
        let cleaned = hexString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "0x", with: "")
        guard cleaned.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self = Data(bytes)
    }

    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
