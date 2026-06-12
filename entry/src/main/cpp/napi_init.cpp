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

// Backward compatibility only. V2 uses processDrainLogs instead of calling JS
// callbacks from native worker threads.
static napi_ref g_logCallbackRef = nullptr;
static std::mutex g_callbackMutex;

static std::string GetStringArg(napi_env env, napi_value value) {
    napi_valuetype type;
    napi_status status = napi_typeof(env, value, &type);
    if (status != napi_ok || type != napi_string) {
        return "";
    }
    char buf[2048];
    memset(buf, 0, sizeof(buf));
    size_t len = 0;
    status = napi_get_value_string_utf8(env, value, buf, sizeof(buf), &len);
    if (status != napi_ok) {
        return "";
    }
    return std::string(buf, len);
}

static napi_value NapiProcessStart(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 2) {
        napi_value result;
        napi_create_int32(env, -1, &result);
        return result;
    }

    std::string command = GetStringArg(env, args[0]);

    uint32_t arrLen = 0;
    napi_get_array_length(env, args[1], &arrLen);
    std::vector<std::string> cmdArgs;
    for (uint32_t i = 0; i < arrLen; i++) {
        napi_value elem;
        napi_get_element(env, args[1], i, &elem);
        cmdArgs.push_back(GetStringArg(env, elem));
    }

    // Safe path: do not call JS callback from process reader thread.
    int pid = ProcessManager::instance().startProcess(command, cmdArgs, nullptr);

    napi_value result;
    napi_create_int32(env, pid, &result);
    return result;
}

static napi_value NapiProcessStartEx(napi_env env, napi_callback_info info) {
    // processStartEx(command, args, cwd, envObj) -> pid
    size_t argc = 4;
    napi_value args[4];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 2) {
        napi_value result;
        napi_create_int32(env, -1, &result);
        return result;
    }

    std::string command = GetStringArg(env, args[0]);

    uint32_t arrLen = 0;
    napi_get_array_length(env, args[1], &arrLen);
    std::vector<std::string> cmdArgs;
    for (uint32_t i = 0; i < arrLen; i++) {
        napi_value elem;
        napi_get_element(env, args[1], i, &elem);
        cmdArgs.push_back(GetStringArg(env, elem));
    }

    std::string cwd;
    if (argc >= 3) {
        cwd = GetStringArg(env, args[2]);
    }

    std::map<std::string, std::string> envMap;
    if (argc >= 4) {
        napi_valuetype type;
        napi_typeof(env, args[3], &type);
        if (type == napi_object) {
            napi_value names;
            napi_get_property_names(env, args[3], &names);
            uint32_t numKeys = 0;
            napi_get_array_length(env, names, &numKeys);
            for (uint32_t i = 0; i < numKeys; i++) {
                napi_value key;
                napi_get_element(env, names, i, &key);
                std::string keyStr = GetStringArg(env, key);
                napi_value val;
                napi_get_named_property(env, args[3], keyStr.c_str(), &val);
                std::string valStr = GetStringArg(env, val);
                envMap[keyStr] = valStr;
            }
        }
    }

    int pid = ProcessManager::instance().startProcessEx(command, cmdArgs, cwd, envMap, nullptr);

    napi_value result;
    napi_create_int32(env, pid, &result);
    return result;
}

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

static napi_value NapiProcessDrainLogs(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t pid = 0;
    napi_get_value_int32(env, args[0], &pid);

    std::vector<std::string> logs = ProcessManager::instance().drainLogs(pid);

    napi_value arr;
    napi_create_array_with_length(env, logs.size(), &arr);
    for (size_t i = 0; i < logs.size(); i++) {
        napi_value line;
        napi_create_string_utf8(env, logs[i].c_str(), logs[i].size(), &line);
        napi_set_element(env, arr, static_cast<uint32_t>(i), line);
    }

    return arr;
}

static napi_value NapiProcessSetLogCallback(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    std::lock_guard<std::mutex> lock(g_callbackMutex);

    if (g_logCallbackRef != nullptr) {
        napi_delete_reference(env, g_logCallbackRef);
        g_logCallbackRef = nullptr;
    }

    // Store only for API compatibility. V2 uses processDrainLogs.
    napi_create_reference(env, args[0], 1, &g_logCallbackRef);

    return nullptr;
}

static napi_value NapiProcessStopAll(napi_env env, napi_callback_info info) {
    ProcessManager::instance().stopAll();
    return nullptr;
}

static napi_value NapiProcessChmod(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 2) {
        napi_value result;
        napi_get_boolean(env, false, &result);
        return result;
    }

    std::string path = GetStringArg(env, args[0]);

    int32_t mode = 0;
    napi_get_value_int32(env, args[1], &mode);

    bool ok = ProcessManager::instance().chmodFile(path, mode);

    napi_value result;
    napi_get_boolean(env, ok, &result);
    return result;
}

static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"processStart", nullptr, NapiProcessStart, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"processStartEx", nullptr, NapiProcessStartEx, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"processStop", nullptr, NapiProcessStop, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"processIsRunning", nullptr, NapiProcessIsRunning, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"processExitCode", nullptr, NapiProcessExitCode, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"processDrainLogs", nullptr, NapiProcessDrainLogs, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"processSetLogCallback", nullptr, NapiProcessSetLogCallback, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"processStopAll", nullptr, NapiProcessStopAll, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"processChmod", nullptr, NapiProcessChmod, nullptr, nullptr, nullptr, napi_default, nullptr},
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
