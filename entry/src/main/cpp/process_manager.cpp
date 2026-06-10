#include "process_manager.h"
#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <cstring>
#include <cerrno>
#include <cstdlib>
#include <hilog/log.h>

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0xFF00
#define LOG_TAG "ProcessManager"

static const size_t MAX_LOG_LINES_PER_PROCESS = 5000;

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
    int stdoutPipe[2];
    int stderrPipe[2];

    if (pipe(stdoutPipe) != 0) {
        OH_LOG_ERROR(LOG_APP, "stdout pipe() failed: %{public}s", strerror(errno));
        return -1;
    }

    if (pipe(stderrPipe) != 0) {
        OH_LOG_ERROR(LOG_APP, "stderr pipe() failed: %{public}s", strerror(errno));
        close(stdoutPipe[0]);
        close(stdoutPipe[1]);
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
        close(stdoutPipe[0]);
        close(stderrPipe[0]);

        dup2(stdoutPipe[1], STDOUT_FILENO);
        dup2(stderrPipe[1], STDERR_FILENO);

        close(stdoutPipe[1]);
        close(stderrPipe[1]);

        std::vector<char*> argv;
        argv.push_back(const_cast<char*>(command.c_str()));
        for (const auto& a : args) {
            argv.push_back(const_cast<char*>(a.c_str()));
        }
        argv.push_back(nullptr);

        execvp(command.c_str(), argv.data());

        fprintf(stderr, "execvp failed: %s\n", strerror(errno));
        _exit(127);
    }

    close(stdoutPipe[1]);
    close(stderrPipe[1]);

    int capturedPid = static_cast<int>(pid);

    {
        std::lock_guard<std::mutex> lock(mutex_);
        ProcessInfo info;
        info.pid = capturedPid;
        info.running = true;
        info.exitCode = -1;
        info.command = command;
        processes_[capturedPid] = info;
        logCallbacks_[capturedPid] = logCallback;
        logLines_[capturedPid] = std::vector<std::string>();
    }

    readerThreads_[capturedPid] = std::thread(
        &ProcessManager::readerThread, this, capturedPid, stdoutPipe[0], stderrPipe[0], logCallback);
    readerThreads_[capturedPid].detach();

    waitThreads_[capturedPid] = std::thread(&ProcessManager::waitThread, this, capturedPid);
    waitThreads_[capturedPid].detach();

    appendLog(capturedPid, "[native] process started");
    OH_LOG_INFO(LOG_APP, "Started process pid=%{public}d cmd=%{public}s", capturedPid, command.c_str());
    return capturedPid;
}

int ProcessManager::startProcessEx(const std::string& command,
                                    const std::vector<std::string>& args,
                                    const std::string& cwd,
                                    const std::map<std::string, std::string>& env,
                                    std::function<void(const std::string& line)> logCallback) {
    int stdoutPipe[2];
    int stderrPipe[2];

    if (pipe(stdoutPipe) != 0) {
        OH_LOG_ERROR(LOG_APP, "stdout pipe() failed: %{public}s", strerror(errno));
        return -1;
    }

    if (pipe(stderrPipe) != 0) {
        OH_LOG_ERROR(LOG_APP, "stderr pipe() failed: %{public}s", strerror(errno));
        close(stdoutPipe[0]); close(stdoutPipe[1]);
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
        // Child process
        close(stdoutPipe[0]);
        close(stderrPipe[0]);

        dup2(stdoutPipe[1], STDOUT_FILENO);
        dup2(stderrPipe[1], STDERR_FILENO);

        close(stdoutPipe[1]);
        close(stderrPipe[1]);

        // Change working directory if specified
        if (!cwd.empty()) {
            if (chdir(cwd.c_str()) != 0) {
                fprintf(stderr, "chdir(%s) failed: %s\n", cwd.c_str(), strerror(errno));
                _exit(126);
            }
        }

        // Set environment variables if specified
        for (const auto& pair : env) {
            setenv(pair.first.c_str(), pair.second.c_str(), 1);
        }

        std::vector<char*> argv;
        argv.push_back(const_cast<char*>(command.c_str()));
        for (const auto& a : args) {
            argv.push_back(const_cast<char*>(a.c_str()));
        }
        argv.push_back(nullptr);

        execvp(command.c_str(), argv.data());

        fprintf(stderr, "execvp failed: %s\n", strerror(errno));
        _exit(127);
    }

    // Parent process
    close(stdoutPipe[1]);
    close(stderrPipe[1]);

    int capturedPid = static_cast<int>(pid);

    {
        std::lock_guard<std::mutex> lock(mutex_);
        ProcessInfo info;
        info.pid = capturedPid;
        info.running = true;
        info.exitCode = -1;
        info.command = command;
        info.cwd = cwd;
        processes_[capturedPid] = info;
        logCallbacks_[capturedPid] = logCallback;
        logLines_[capturedPid] = std::vector<std::string>();
    }

    readerThreads_[capturedPid] = std::thread(
        &ProcessManager::readerThread, this, capturedPid, stdoutPipe[0], stderrPipe[0], logCallback);
    readerThreads_[capturedPid].detach();

    waitThreads_[capturedPid] = std::thread(&ProcessManager::waitThread, this, capturedPid);
    waitThreads_[capturedPid].detach();

    appendLog(capturedPid, "[native] process started (cwd=" + (cwd.empty() ? "(inherited)" : cwd) + ")");
    OH_LOG_INFO(LOG_APP, "Started process pid=%{public}d cmd=%{public}s cwd=%{public}s",
                capturedPid, command.c_str(), cwd.c_str());
    return capturedPid;
}

bool ProcessManager::stopProcess(int pid) {
    {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = processes_.find(pid);
        if (it == processes_.end() || !it->second.running) return false;
    }

    appendLog(pid, "[native] sending SIGTERM");
    kill(static_cast<pid_t>(pid), SIGTERM);

    for (int i = 0; i < 30; i++) {
        if (!isRunning(pid)) {
            appendLog(pid, "[native] process stopped");
            return true;
        }
        usleep(100000);
    }

    appendLog(pid, "[native] sending SIGKILL");
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

std::vector<std::string> ProcessManager::drainLogs(int pid) {
    std::lock_guard<std::mutex> lock(mutex_);
    std::vector<std::string> out;
    auto it = logLines_.find(pid);
    if (it == logLines_.end()) return out;
    out.swap(it->second);
    return out;
}

bool ProcessManager::chmodFile(const std::string& path, int mode) {
    int ret = chmod(path.c_str(), static_cast<mode_t>(mode));
    if (ret != 0) {
        OH_LOG_ERROR(LOG_APP, "chmod(%{public}s, %o) failed: %{public}s", path.c_str(), mode, strerror(errno));
        return false;
    }
    return true;
}

void ProcessManager::appendLog(int pid, const std::string& line) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto& vec = logLines_[pid];
    vec.push_back(line);
    // Trim old entries to prevent unbounded memory growth
    if (vec.size() > MAX_LOG_LINES_PER_PROCESS) {
        vec.erase(vec.begin(), vec.begin() + (vec.size() - MAX_LOG_LINES_PER_PROCESS));
    }
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
            std::lock_guard<std::mutex> lock(mutex_);
            auto it = processes_.find(pid);
            if (it != processes_.end() && !it->second.running) break;
            continue;
        }

        auto readFd = [&](int fd) -> bool {
            if (fd < 0 || !FD_ISSET(fd, &readFds)) return true;
            ssize_t n = read(fd, buffer, sizeof(buffer) - 1);
            if (n <= 0) return false;

            buffer[n] = '\\0';

            for (ssize_t i = 0; i < n; i++) {
                if (buffer[i] == '\\n') {
                    if (!lineBuffer.empty()) {
                        appendLog(pid, lineBuffer);
                        // Do not call JS directly from native reader threads.
                        // logCallback is reserved for future native-side hooks.
                        if (logCallback) {
                            logCallback(lineBuffer);
                        }
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

    if (!lineBuffer.empty()) {
        appendLog(pid, lineBuffer);
        if (logCallback) logCallback(lineBuffer);
    }

    close(stdoutFd);
    close(stderrFd);
    appendLog(pid, "[native] log reader stopped");
}

void ProcessManager::waitThread(int pid) {
    int status = 0;
    waitpid(static_cast<pid_t>(pid), &status, 0);

    int exitCode = -1;
    {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = processes_.find(pid);
        if (it != processes_.end()) {
            it->second.running = false;
            if (WIFEXITED(status)) {
                it->second.exitCode = WEXITSTATUS(status);
            } else if (WIFSIGNALED(status)) {
                it->second.exitCode = 128 + WTERMSIG(status);
            }
            exitCode = it->second.exitCode;
        }
    }

    appendLog(pid, "[native] process exited code=" + std::to_string(exitCode));
    OH_LOG_INFO(LOG_APP, "Process pid=%{public}d exited code=%{public}d", pid, exitCode);

    // Clean up stale thread entries after a short delay (reader thread needs time to finish)
    std::this_thread::sleep_for(std::chrono::milliseconds(500));
    {
        std::lock_guard<std::mutex> lock(mutex_);
        readerThreads_.erase(pid);
        waitThreads_.erase(pid);
        logCallbacks_.erase(pid);
        // Keep processes_ and logLines_ so ArkTS can still drain logs after exit
    }
}
