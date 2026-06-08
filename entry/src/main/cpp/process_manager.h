#pragma once
#include <string>
#include <vector>
#include <functional>
#include <mutex>
#include <thread>
#include <atomic>
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

    // Start a process. Returns pid (>0) on success, -1 on failure.
    // logCallback is called with each line of stdout/stderr output.
    int startProcess(const std::string& command,
                     const std::vector<std::string>& args,
                     std::function<void(const std::string& line)> logCallback);

    // Stop a process by pid (SIGTERM, then SIGKILL after 3s).
    bool stopProcess(int pid);

    // Check if a process is still running.
    bool isRunning(int pid);

    // Get exit code (-1 if still running).
    int getExitCode(int pid);

    // Kill all managed processes.
    void stopAll();

    // Get all managed pids.
    std::vector<int> getManagedPids();

private:
    ProcessManager() = default;
    ~ProcessManager();
    ProcessManager(const ProcessManager&) = delete;
    ProcessManager& operator=(const ProcessManager&) = delete;

    void readerThread(int pid, int stdoutFd, int stderrFd,
                      std::function<void(const std::string& line)> logCallback);
    void waitThread(int pid);

    std::mutex mutex_;
    std::map<int, ProcessInfo> processes_;
    std::map<int, std::thread> readerThreads_;
    std::map<int, std::thread> waitThreads_;
    std::map<int, std::function<void(const std::string&)>> logCallbacks_;
};
