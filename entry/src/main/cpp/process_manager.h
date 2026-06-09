#pragma once
#include <string>
#include <vector>
#include <functional>
#include <mutex>
#include <thread>
#include <map>

struct ProcessInfo {
    int pid = -1;
    bool running = false;
    int exitCode = -1;
    std::string command;
};

class ProcessManager {
public:
    static ProcessManager& instance();

    int startProcess(const std::string& command,
                     const std::vector<std::string>& args,
                     std::function<void(const std::string& line)> logCallback = nullptr);

    bool stopProcess(int pid);
    bool isRunning(int pid);
    int getExitCode(int pid);
    void stopAll();
    std::vector<int> getManagedPids();

    // Thread-safe log queue. ArkTS should poll/drain logs instead of receiving
    // direct callbacks from native reader threads.
    std::vector<std::string> drainLogs(int pid);

private:
    ProcessManager() = default;
    ~ProcessManager();
    ProcessManager(const ProcessManager&) = delete;
    ProcessManager& operator=(const ProcessManager&) = delete;

    void readerThread(int pid, int stdoutFd, int stderrFd,
                      std::function<void(const std::string& line)> logCallback);
    void waitThread(int pid);
    void appendLog(int pid, const std::string& line);

    std::mutex mutex_;
    std::map<int, ProcessInfo> processes_;
    std::map<int, std::thread> readerThreads_;
    std::map<int, std::thread> waitThreads_;
    std::map<int, std::function<void(const std::string&)>> logCallbacks_;
    std::map<int, std::vector<std::string>> logLines_;
};
