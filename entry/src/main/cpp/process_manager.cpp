#include "process_manager.h"
#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <fcntl.h>
#include <cstring>
#include <cerrno>
#include <hilog/log.h>

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0xFF00
#define LOG_TAG "ProcessManager"

ProcessManager& ProcessManager::instance() {
    static ProcessManager mgr;
    return mgr;
}

ProcessManager::~ProcessManager() {
    stopAll();
}

int ProcessManager::startProcess(const std::string& command,
                                  const std::vector<std::string>& args,
                                  std::function<void(const std::string& line)> logCallback) {
    // Create pipes for stdout and stderr
    int stdoutPipe[2];
    int stderrPipe[2];

    if (pipe(stdoutPipe) != 0 || pipe(stderrPipe) != 0) {
        OH_LOG_ERROR(LOG_APP, "pipe() failed: %{public}s", strerror(errno));
        return -1;
    }

    pid_t pid = fork();

    if (pid < 0) {
        OH_LOG_ERROR(LOG_APP, "fork() failed: %{public}s", strerror(errno));
        close(stdoutPipe[0]); close(stdoutPipe[1]);
        close(stderrPipe[0]); close(stderrPipe[1]);
        return -1;
    }

    if (pid == 0) {
        // ── Child process ──
        close(stdoutPipe[0]);
        close(stderrPipe[0]);

        dup2(stdoutPipe[1], STDOUT_FILENO);
        dup2(stderrPipe[1], STDERR_FILENO);

        close(stdoutPipe[1]);
        close(stderrPipe[1]);

        // Build argv
        std::vector<char*> argv;
        argv.push_back(const_cast<char*>(command.c_str()));
        for (const auto& a : args) {
            argv.push_back(const_cast<char*>(a.c_str()));
        }
        argv.push_back(nullptr);

        execvp(command.c_str(), argv.data());

        // If execvp returns, it failed
        fprintf(stderr, "execvp failed: %s\n", strerror(errno));
        _exit(127);
    }

    // ── Parent process ──
    close(stdoutPipe[1]);
    close(stderrPipe[1]);

    {
        std::lock_guard<std::mutex> lock(mutex_);
        ProcessInfo info;
        info.pid = static_cast<int>(pid);
        info.running = true;
        info.exitCode = -1;
        info.command = command;
        processes_[static_cast<int>(pid)] = info;
        logCallbacks_[static_cast<int>(pid)] = logCallback;
    }

    // Start reader thread for stdout+stderr
    int capturedPid = static_cast<int>(pid);
    readerThreads_[capturedPid] = std::thread(
        &ProcessManager::readerThread, this, capturedPid, stdoutPipe[0], stderrPipe[0], logCallback);

    // Start wait thread to reap child
    waitThreads_[capturedPid] = std::thread(&ProcessManager::waitThread, this, capturedPid);

    OH_LOG_INFO(LOG_APP, "Started process pid=%{public}d cmd=%{public}s", capturedPid, command.c_str());
    return capturedPid;
}

bool ProcessManager::stopProcess(int pid) {
    {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = processes_.find(pid);
        if (it == processes_.end() || !it->second.running) return false;
    }

    // Send SIGTERM
    kill(static_cast<pid_t>(pid), SIGTERM);

    // Wait up to 3 seconds
    for (int i = 0; i < 30; i++) {
        if (!isRunning(pid)) return true;
        usleep(100000); // 100ms
    }

    // Force kill
    kill(static_cast<pid_t>(pid), SIGKILL);
    return true;
}

bool ProcessManager::isRunning(int pid) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = processes_.find(pid);
    if (it == processes_.end()) return false;
    return it->second.running;
}

int ProcessManager::getExitCode(int pid) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = processes_.find(pid);
    if (it == processes_.end()) return -1;
    return it->second.exitCode;
}

void ProcessManager::stopAll() {
    std::vector<int> pids = getManagedPids();
    for (int pid : pids) {
        stopProcess(pid);
    }
}

std::vector<int> ProcessManager::getManagedPids() {
    std::lock_guard<std::mutex> lock(mutex_);
    std::vector<int> pids;
    for (const auto& pair : processes_) {
        pids.push_back(pair.first);
    }
    return pids;
}

void ProcessManager::readerThread(int pid, int stdoutFd, int stderrFd,
                                   std::function<void(const std::string& line)> logCallback) {
    fd_set readFds;
    char buffer[4096];
    std::string lineBuffer;

    int maxFd = (stdoutFd > stderrFd) ? stdoutFd : stderrFd;

    while (true) {
        FD_ZERO(&readFds);
        if (stdoutFd >= 0) FD_SET(stdoutFd, &readFds);
        if (stderrFd >= 0) FD_SET(stderrFd, &readFds);

        struct timeval timeout;
        timeout.tv_sec = 1;
        timeout.tv_usec = 0;

        int ret = select(maxFd + 1, &readFds, nullptr, nullptr, &timeout);

        if (ret < 0) {
            if (errno == EINTR) continue;
            break;
        }

        if (ret == 0) {
            // Timeout — check if process is still running
            std::lock_guard<std::mutex> lock(mutex_);
            auto it = processes_.find(pid);
            if (it != processes_.end() && !it->second.running) break;
            continue;
        }

        auto readFd = [&](int fd) -> bool {
            if (fd < 0 || !FD_ISSET(fd, &readFds)) return true;
            ssize_t n = read(fd, buffer, sizeof(buffer) - 1);
            if (n <= 0) return false;
            buffer[n] = '\0';
            // Split into lines
            for (ssize_t i = 0; i < n; i++) {
                if (buffer[i] == '\n') {
                    if (logCallback && lineBuffer.size() > 0) {
                        logCallback(lineBuffer);
                    }
                    lineBuffer.clear();
                } else {
                    lineBuffer += buffer[i];
                }
            }
            return true;
        };

        bool ok1 = readFd(stdoutFd);
        bool ok2 = readFd(stderrFd);

        if (!ok1 && !ok2) break;
    }

    // Flush remaining
    if (!lineBuffer.empty() && logCallback) {
        logCallback(lineBuffer);
    }

    close(stdoutFd);
    close(stderrFd);
}

void ProcessManager::waitThread(int pid) {
    int status = 0;
    pid_t result = waitpid(static_cast<pid_t>(pid), &status, 0);

    std::lock_guard<std::mutex> lock(mutex_);
    auto it = processes_.find(pid);
    if (it != processes_.end()) {
        it->second.running = false;
        if (WIFEXITED(status)) {
            it->second.exitCode = WEXITSTATUS(status);
        } else if (WIFSIGNALED(status)) {
            it->second.exitCode = 128 + WTERMSIG(status);
        }
    }

    OH_LOG_INFO(LOG_APP, "Process pid=%{public}d exited code=%{public}d", pid,
                (it != processes_.end()) ? it->second.exitCode : -1);
}
