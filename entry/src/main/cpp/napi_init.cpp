#include <napi/native_api.h>
#include <hilog/log.h>
#include "process_manager.h"
#include <string>
#include <vector>
#include <mutex>

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0xFF00
#define LOG_TAG "NapiProcess"

// Global callback reference for log streaming
static napi_ref g_logCallbackRef = nullptr;
static napi_env g_env = nullptr;
static std::mutex g_callbackMutex;

// ── napi_process_start ──
static napi_value NapiProcessStart(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    // arg0: command string
    char cmdBuf[1024];
    size_t cmdLen = 0;
    napi_get_value_string_utf8(env, args[0], cmdBuf, sizeof(cmdBuf), &cmdLen);
    std::string command(cmdBuf, cmdLen);

    // arg1: args array
    uint32_t arrLen = 0;
    napi_get_array_length(env, args[1], &arrLen);
    std::vector<std::string> cmdArgs;
    for (uint32_t i = 0; i < arrLen; i++) {
        napi_value elem;
        napi_get_element(env, args[1], i, &elem);
        char argBuf[1024];
        size_t argLen = 0;
        napi_get_value_string_utf8(env, elem, argBuf, sizeof(argBuf), &argLen);
        cmdArgs.push_back(std::string(argBuf, argLen));
    }

    // Store env for callback usage
    {
        std::lock_guard<std::mutex> lock(g_callbackMutex);
        g_env = env;
    }

    // Log callback — will be invoked from reader thread
    auto logCallback = [](const std::string& line) {
        std::lock_guard<std::mutex> lock(g_callbackMutex);
        if (g_env == nullptr || g_logCallbackRef == nullptr) return;

        napi_env cbEnv = g_env;
        napi_value callback;
        napi_get_reference_value(cbEnv, g_logCallbackRef, &callback);

        napi_value argv[1];
        napi_create_string_utf8(cbEnv, line.c_str(), line.size(), &argv[0]);

        napi_value global;
        napi_get_global(cbEnv, &global);
        napi_call_function(cbEnv, global, callback, 1, argv, nullptr);
    };

    int pid = ProcessManager::instance().startProcess(command, cmdArgs, logCallback);

    napi_value result;
    napi_create_int32(env, pid, &result);
    return result;
}

// ── napi_process_stop ──
static napi_value NapiProcessStop(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t pid = 0;
    napi_get_value_int32(env, args[0], &pid);

    bool ok = ProcessManager::instance().stopProcess(pid);

    napi_value result;
    napi_get_boolean(env, ok, &result);
    return result;
}

// ── napi_process_is_running ──
static napi_value NapiProcessIsRunning(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t pid = 0;
    napi_get_value_int32(env, args[0], &pid);

    bool running = ProcessManager::instance().isRunning(pid);

    napi_value result;
    napi_get_boolean(env, running, &result);
    return result;
}

// ── napi_process_exit_code ──
static napi_value NapiProcessExitCode(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t pid = 0;
    napi_get_value_int32(env, args[0], &pid);

    int code = ProcessManager::instance().getExitCode(pid);

    napi_value result;
    napi_create_int32(env, code, &result);
    return result;
}

// ── napi_process_set_log_callback ──
static napi_value NapiProcessSetLogCallback(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    std::lock_guard<std::mutex> lock(g_callbackMutex);

    // Release old reference
    if (g_logCallbackRef != nullptr) {
        napi_delete_reference(env, g_logCallbackRef);
        g_logCallbackRef = nullptr;
    }

    // Store new callback reference
    napi_create_reference(env, args[0], 1, &g_logCallbackRef);

    return nullptr;
}

// ── napi_process_stop_all ──
static napi_value NapiProcessStopAll(napi_env env, napi_callback_info info) {
    ProcessManager::instance().stopAll();
    return nullptr;
}

// ── Module registration ──
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"processStart", nullptr, NapiProcessStart, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"processStop", nullptr, NapiProcessStop, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"processIsRunning", nullptr, NapiProcessIsRunning, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"processExitCode", nullptr, NapiProcessExitCode, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"processSetLogCallback", nullptr, NapiProcessSetLogCallback, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"processStopAll", nullptr, NapiProcessStopAll, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}

EXTERN_C_START
static napi_module g_module = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "opencode_native",
    .nm_priv = nullptr,
    .reserved = {0},
};

__attribute__((constructor)) void RegisterModule(void) {
    napi_module_register(&g_module);
}
EXTERN_C_END
