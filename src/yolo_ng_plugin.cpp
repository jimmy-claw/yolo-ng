#include "yolo_ng_plugin.h"
#include "yolo_ng_board.h"

#include <QDebug>

// ── Construction ─────────────────────────────────────────────────────────────

YoloNgPlugin::YoloNgPlugin(QObject *parent)
    : QObject(parent)
    , m_board(new YoloNgBoard(this))
{
    qDebug() << "YoloNgPlugin: Constructed";
}

// ── Logos Core lifecycle ─────────────────────────────────────────────────────

void YoloNgPlugin::initLogos(LogosAPI *api)
{
    m_logosAPI = api;
    logosAPI = api;  // PluginInterface base-class field — ModuleProxy reads this

    if (!m_logosAPI) {
        qWarning() << "YoloNgPlugin: initLogos called with null LogosAPI";
        qInfo() << "YoloNgPlugin: initialized (headless). version:" << version();
        return;
    }

    m_board->initLogos(api);

    qInfo() << "YoloNgPlugin: initLogos done. version:" << version();
}

// ── Forwarded board methods ──────────────────────────────────────────────────

QString YoloNgPlugin::createPost(const QString &author, const QString &content,
                                 const QString &parentId)
{
    return m_board->createPost(author, content, parentId);
}

void YoloNgPlugin::deletePost(const QString &postId)
{
    m_board->deletePost(postId);
}

void YoloNgPlugin::likePost(const QString &postId)
{
    m_board->likePost(postId);
}

void YoloNgPlugin::refreshPosts()
{
    m_board->refreshPosts();
}
