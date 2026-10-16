//
//  QCLogger.h
//  QCBandSDK
//
//  Created by steve on 2023/11/23.
//
//  SDK log sink.
//  QCSDKManager.debug: console debug logs (default YES).
//  QCSDKManager.fileLoggingEnabled: diagnostic file (default NO, protocol bytes, debug only).
//  The two switches are independent. maxLogFileSizeMB default 10, clamped to 1–100.
//
//  SDK 统一日志出口。
//  QCSDKManager.debug：控制台调试日志（默认 YES）。
//  QCSDKManager.fileLoggingEnabled：诊断文件落盘（默认 NO，含协议字节，仅排障使用）。
//  两个开关互不影响。maxLogFileSizeMB 默认 10，范围 1～100。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, QCLogLevel) {
    QCLogLevelOff = 0,      ///< Off / 关闭全部 SDK 调试日志
    QCLogLevelError = 1,    ///< Errors only / 仅错误
    QCLogLevelInfo = 2,     ///< Key info / 关键信息
    QCLogLevelDebug = 3,    ///< Normal debug (default) / 常规调试（默认）
};

#define QCLogError(fmt, ...)   QCLogAtLevel(QCLogLevelError, fmt, ##__VA_ARGS__)
#define QCLogInfo(fmt, ...)    QCLogAtLevel(QCLogLevelInfo, fmt, ##__VA_ARGS__)
#define QCLogDebug(fmt, ...)   QCLogAtLevel(QCLogLevelDebug, fmt, ##__VA_ARGS__)

/// Compatible alias of QCLogDebug / 兼容旧宏：等同 QCLogDebug
#define QCLog(fmt, ...) QCLogDebug(fmt, ##__VA_ARGS__)

// Parameter cannot be named `level`: it would rewrite ObjC `level:` selectors.
// 注意：宏形参不能叫 level，否则会替换掉 ObjC 选择子里的 level:，
// 展开成 logMessage:QCLogLevelDebug: 导致编译失败。
#define QCLogAtLevel(lvl, fmt, ...) \
do { \
    if ([QCLogger shouldLogLevel:(lvl)] || [QCLogger isFileLoggingEnabled]) { \
        NSString *_qc_log_msg_ = [NSString stringWithFormat:(fmt), ##__VA_ARGS__]; \
        [QCLogger logMessage:_qc_log_msg_ level:(lvl)]; \
    } \
} while (0)

@interface QCLogger : NSObject

/// YES → Debug, NO → Off. Does not enable protocol-level Verbose.
/// YES → Debug 级别，NO → Off。不会打开协议级 Verbose。
+ (void)setLoggingEnabled:(BOOL)enabled;
+ (BOOL)isLoggingEnabled;

+ (BOOL)shouldLogLevel:(QCLogLevel)level;

+ (void)logMessage:(NSString *)message;
+ (void)logMessage:(NSString *)message level:(QCLogLevel)level;

/// Diagnostic file capture. Default NO. Writes categorized traces (including protocol bytes)
/// to `logFilePath`. Independent of `debug` console output.
/// 诊断文件落盘，默认 NO。按类型写入 `logFilePath`（含协议字节），与控制台 `debug` 开关独立。
+ (void)setFileLoggingEnabled:(BOOL)enabled;
+ (BOOL)isFileLoggingEnabled;

/// Max diagnostic log file size in MB. Default 10, clamped to 1–100.
/// 诊断日志单文件上限（MB）。默认 10，范围 1～100。
+ (void)setMaxLogFileSizeMB:(NSUInteger)sizeMB;
+ (NSUInteger)maxLogFileSizeMB;

/// Clear the diagnostic file. Path and the file-logging switch are unchanged.
/// 清除诊断日志文件。路径与文件开关保持不变。
+ (void)clearLogFile;
+ (NSString *)logFilePath;
/// Flush queued writes to disk. Call before sharing `logFilePath`.
/// 将已入队记录刷到磁盘。分享 `logFilePath` 前调用。
+ (void)flush;

@end

NS_ASSUME_NONNULL_END
