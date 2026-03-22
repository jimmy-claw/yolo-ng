#pragma once

#include <QObject>

class YoloNgBoard;

/**
 * YoloNgPlugin — Logos module plugin for YOLO-NG text board
 *
 * This plugin provides:
 * - YoloNgBoard: the main board logic for the text board
 * - QML types via the YoloNg module
 *
 * Integrates with Logos platform when available.
 */
class YoloNgPlugin : public QObject
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "com.logos.yolo-ng.plugin/1.0" FILE "yolo_ng_plugin.json")

public:
    explicit YoloNgPlugin(QObject* parent = nullptr);
    ~YoloNgPlugin() override;

    // Initialize the plugin (call once after construction)
    void initialize();

    // Access the board instance
    YoloNgBoard* board() const { return m_board; }

#ifdef LOGOS_CORE_AVAILABLE
    // logos::ModulePlugin interface
    void onLoad();
    void onUnload();
    void* getBoard();
#endif

private:
    void initBoard();

    YoloNgBoard* m_board = nullptr;
    bool m_initialized = false;
};
