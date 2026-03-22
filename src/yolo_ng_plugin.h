#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>

#include "yolo_ng_board.h"

#include <interface.h>
#include <logos_api.h>

/**
 * YoloNgPlugin — Headless logoscore plugin wrapper for YoloNgBoard.
 *
 * This plugin is loaded by logos_host as a shared library. It must NOT use
 * Qt Quick, QML engine, or any GUI classes — only Qt Core/Qml/RemoteObjects.
 */
class YoloNgPlugin : public QObject, public PluginInterface {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID PluginInterface_iid FILE "metadata.json")
    Q_INTERFACES(PluginInterface)

public:
    explicit YoloNgPlugin(QObject *parent = nullptr);

    // ── PluginInterface ─────────────────────────────────────────────────────
    [[nodiscard]] QString name() const override { return QStringLiteral("yolo_ng"); }
    Q_INVOKABLE QString version() const override { return QStringLiteral("0.1.0"); }
    Q_INVOKABLE void initLogos(LogosAPI *api);

    // ── Board access ────────────────────────────────────────────────────────
    Q_INVOKABLE QString createPost(const QString &author, const QString &content,
                                   const QString &parentId = QString());
    Q_INVOKABLE void deletePost(const QString &postId);
    Q_INVOKABLE void likePost(const QString &postId);
    Q_INVOKABLE void refreshPosts();

signals:
    void eventResponse(const QString &eventName, const QVariantList &args);

private:
    YoloNgBoard *m_board = nullptr;
    LogosAPI *m_logosAPI = nullptr;
};
