#include "yolo_ng_plugin.h"
#include "yolo_ng_board.h"

#include <QCoreApplication>
#include <QDebug>
#include <QQmlEngine>
#include <QtQml>

YoloNgPlugin::YoloNgPlugin(QObject* parent)
    : QObject(parent)
{
    qDebug() << "YoloNgPlugin: Constructed";
}

YoloNgPlugin::~YoloNgPlugin()
{
    if (m_board) {
        delete m_board;
        m_board = nullptr;
    }
    qDebug() << "YoloNgPlugin: Destroyed";
}

void YoloNgPlugin::initialize()
{
    if (m_initialized) {
        qWarning() << "YoloNgPlugin: Already initialized";
        return;
    }

    // Register QML types
    qmlRegisterType<YoloNgBoard>("YoloNg", 1, 0, "Board");

    // Initialize board
    initBoard();
    m_initialized = true;

    qDebug() << "YoloNgPlugin: Initialized";
}

void YoloNgPlugin::initBoard()
{
    if (m_board) {
        qWarning() << "YoloNgPlugin: Board already initialized";
        return;
    }

    m_board = new YoloNgBoard();
    qDebug() << "YoloNgPlugin: Board initialized";
}

#ifdef LOGOS_CORE_AVAILABLE

extern "C" {
    typedef struct {
        void (*on_load)(void*);
        void (*on_unload)(void*);
        void* (*get_board)(void*);
    } LogosModuleVTable;

    __attribute__((visibility("default")))
    void logos_core_register_module(const char* name, void* module, LogosModuleVTable* vtable);
    
    __attribute__((visibility("default")))
    void logos_core_unregister_module(const char* name);
}

namespace {

void on_load_cb(void* self) {
    qDebug() << "YoloNgPlugin: onLoad callback";
    auto* plugin = static_cast<YoloNgPlugin*>(self);
    plugin->initialize();
}

void on_unload_cb(void* self) {
    qDebug() << "YoloNgPlugin: onUnload callback";
    auto* plugin = static_cast<YoloNgPlugin*>(self);
    if (plugin->board()) {
        plugin->board()->deleteLater();
    }
}

void* get_board_cb(void* self) {
    auto* plugin = static_cast<YoloNgPlugin*>(self);
    return plugin->board();
}

} // anonymous namespace

void YoloNgPlugin::onLoad()
{
    qDebug() << "YoloNgPlugin: Loading module";

    if (!m_initialized) {
        initialize();
    }

    static LogosModuleVTable vtable = {
        .on_load = on_load_cb,
        .on_unload = on_unload_cb,
        .get_board = get_board_cb,
    };

    logos_core_register_module("yolo_ng", this, &vtable);
    qDebug() << "YoloNgPlugin: Registered with LogosCore";
}

void YoloNgPlugin::onUnload()
{
    qDebug() << "YoloNgPlugin: Unloading module";
    logos_core_unregister_module("yolo_ng");

    if (m_board) {
        m_board->deleteLater();
        m_board = nullptr;
    }
}

void* YoloNgPlugin::getBoard()
{
    return m_board;
}

#endif // LOGOS_CORE_AVAILABLE

// Qt plugin exports
#ifdef YOLO_NG_WRAPPER
// Entry point for logos-module-builder
QObject* logos_module_factory(QQmlEngine* engine, QJSEngine* scriptEngine)
{
    Q_UNUSED(scriptEngine);
    Q_UNUSED(engine);
    auto* plugin = new YoloNgPlugin();
    plugin->initialize();
    return plugin;
}
#endif
