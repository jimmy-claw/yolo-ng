#include "yolo_ng_board.h"
#include <dlfcn.h>

#include <QCoreApplication>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <logos_api.h>
#include <logos_api_client.h>

YoloNgBoard::YoloNgBoard(QObject* parent)
    : QObject(parent)
{
    qDebug() << "YoloNgBoard: Created";

#ifdef LOGOS_CORE_AVAILABLE
    // Try to get KV interface from Logos core via dlsym (optional)
    {
        void* sym = nullptr;
        void* self = dlopen(nullptr, RTLD_NOW);
        if (self) { sym = dlsym(self, "logos_core_get_kv_interface"); dlclose(self); }
        if (sym) {
            auto fn = reinterpret_cast<void*(*)()>(sym);
            m_kv = fn();
        }
    }
    qDebug() << "YoloNgBoard: KV interface" << (m_kv ? "available" : "not available");
#endif

    loadPosts();

    // Create a welcome post if board is empty
    if (m_posts.isEmpty()) {
        Post welcome;
        welcome.id = generatePostId();
        welcome.author = QStringLiteral("system");
        welcome.content = QStringLiteral("Welcome to YOLO-NG! Create your first post.");
        welcome.timestamp = QDateTime::currentDateTime();
        m_posts.append(welcome);
        savePosts();
    }
}

YoloNgBoard::~YoloNgBoard()
{
    qDebug() << "YoloNgBoard: Destroyed";
}

void YoloNgBoard::initLogos(LogosAPI* api)
{
    if (!api) {
        qWarning() << "YoloNgBoard: initLogos called with null LogosAPI";
        return;
    }

#ifdef LOGOS_CORE_AVAILABLE
    {
        void* self = dlopen(nullptr, RTLD_NOW);
        if (self) {
            auto sym = dlsym(self, "logos_core_get_kv_interface");
            if (sym) { auto fn = reinterpret_cast<void*(*)()>(sym); m_kv = fn(); }
            dlclose(self);
        }
    }
    qDebug() << "YoloNgBoard: KV interface" << (m_kv ? "available" : "not available");
#endif

    m_zoneSequencer = api->getClient("liblogos_zone_sequencer_module");
    if (!m_zoneSequencer) {
        qWarning() << "YoloNgBoard: zone_sequencer_module client not available";
    } else {
        qInfo() << "YoloNgBoard: zone_sequencer_module client acquired";
    }

    qInfo() << "YoloNgBoard: Logos initialized";
}

QVariantList YoloNgBoard::posts() const
{
    QVariantList result;
    for (const auto& post : m_posts) {
        QVariantMap map;
        map[QStringLiteral("id")] = post.id;
        map[QStringLiteral("author")] = post.author;
        map[QStringLiteral("content")] = post.content;
        map[QStringLiteral("timestamp")] = post.timestamp.toString(Qt::ISODate);
        map[QStringLiteral("likes")] = post.likes;
        map[QStringLiteral("parentId")] = post.parentId;
        map[QStringLiteral("inscriptionId")] = post.inscriptionId;
        result.append(map);
    }
    return result;
}

void YoloNgBoard::refreshPosts()
{
    loadPosts();
    emit postsChanged();
}

QString YoloNgBoard::createPost(const QString& author, const QString& content, const QString& parentId)
{
    if (content.trimmed().isEmpty()) {
        emit errorOccurred(QStringLiteral("Post content cannot be empty"));
        return QString();
    }

    Post post;
    post.id = generatePostId();
    post.author = author.isEmpty() ? QStringLiteral("anonymous") : author;
    post.content = content.trimmed();
    post.timestamp = QDateTime::currentDateTime();
    post.parentId = parentId;

    m_posts.prepend(post);
    savePosts();

    inscribePost(post.id, post.content);

    qDebug() << "YoloNgBoard: Created post" << post.id;
    emit postCreated(post.id);
    emit postsChanged();

    return post.id;
}

void YoloNgBoard::deletePost(const QString& postId)
{
    for (int i = 0; i < m_posts.size(); ++i) {
        if (m_posts[i].id == postId) {
            m_posts.removeAt(i);
            savePosts();
            emit postDeleted(postId);
            emit postsChanged();
            qDebug() << "YoloNgBoard: Deleted post" << postId;
            return;
        }
    }
    emit errorOccurred(QStringLiteral("Post not found"));
}

void YoloNgBoard::likePost(const QString& postId)
{
    Post* post = findPost(postId);
    if (post) {
        post->likes++;
        savePosts();
        emit postsChanged();
        qDebug() << "YoloNgBoard: Liked post" << postId << "- now at" << post->likes;
    } else {
        emit errorOccurred(QStringLiteral("Post not found"));
    }
}

void YoloNgBoard::shutdown()
{
    qDebug() << "YoloNgBoard: Shutting down";
    savePosts();
}

QString YoloNgBoard::generatePostId()
{
    QString id = QStringLiteral("post_%1_%2")
        .arg(m_nextPostId++)
        .arg(QDateTime::currentMSecsSinceEpoch());
    return id;
}

Post* YoloNgBoard::findPost(const QString& id)
{
    for (auto& post : m_posts) {
        if (post.id == id) {
            return &post;
        }
    }
    return nullptr;
}

void YoloNgBoard::inscribePost(const QString& postId, const QString& content)
{
    if (!m_zoneSequencer) {
        qWarning() << "YoloNgBoard: zone sequencer client not available";
        return;
    }

    static const QString signingKey =
        QStringLiteral("0151f7d1d029b6c40390f45640006430978940f1af9267c9a831d17b75a7bf27");
    static const QString nodeUrl =
        QStringLiteral("http://192.168.0.209:8080");
    static const QString checkpointPath =
        QStringLiteral("/tmp/yolo-ng-demo.checkpoint");

    // Configure the zone sequencer (idempotent)
    m_zoneSequencer->invokeRemoteMethod(
        "liblogos_zone_sequencer_module", "set_node_url", nodeUrl);
    m_zoneSequencer->invokeRemoteMethod(
        "liblogos_zone_sequencer_module", "set_signing_key", signingKey);
    m_zoneSequencer->invokeRemoteMethod(
        "liblogos_zone_sequencer_module", "set_checkpoint_path", checkpointPath);

    // Publish the post content
    QVariant result = m_zoneSequencer->invokeRemoteMethod(
        "liblogos_zone_sequencer_module", "publish", content);

    QString inscriptionId = result.toString();
    if (inscriptionId.isEmpty() || inscriptionId.startsWith("Error")) {
        qWarning() << "YoloNgBoard: inscription failed for post" << postId << ":" << inscriptionId;
        return;
    }

    qInfo() << "YoloNgBoard: post" << postId << "inscribed as" << inscriptionId;

    Post* post = findPost(postId);
    if (post) {
        post->inscriptionId = inscriptionId;
        savePosts();
    }
}

bool YoloNgBoard::loadPosts()
{
#ifdef LOGOS_CORE_AVAILABLE
    if (!m_kv) {
        return false;
    }

    // KV functions via dlsym
    void* libself = dlopen(nullptr, RTLD_NOW);
    auto kv_get = libself ? (bool(*)(void*,const char*,char**))dlsym(libself, "logos_kv_get") : nullptr;
    auto kv_free = libself ? (void(*)(char*))dlsym(libself, "logos_kv_free") : nullptr;
    if (libself) dlclose(libself);

    char* data = nullptr;
    if (kv_get && kv_get(m_kv, "yolo_ng_posts", &data) && data) {
        QJsonParseError error;
        QJsonDocument doc = QJsonDocument::fromJson(QByteArray(data), &error);
        if (kv_free) kv_free(data);

        if (error.error == QJsonParseError::NoError && doc.isArray()) {
            m_posts.clear();
            for (const auto& item : doc.array()) {
                if (item.isObject()) {
                    QJsonObject obj = item.toObject();
                    Post post;
                    post.id = obj[QStringLiteral("id")].toString();
                    post.author = obj[QStringLiteral("author")].toString();
                    post.content = obj[QStringLiteral("content")].toString();
                    post.timestamp = QDateTime::fromString(
                        obj[QStringLiteral("timestamp")].toString(), Qt::ISODate);
                    post.likes = obj[QStringLiteral("likes")].toInt();
                    post.parentId = obj[QStringLiteral("parentId")].toString();
                    post.inscriptionId = obj[QStringLiteral("inscriptionId")].toString();
                    m_posts.append(post);
                }
            }
            qDebug() << "YoloNgBoard: Loaded" << m_posts.size() << "posts from storage";
            return true;
        }
    }
#endif
    return false;
}

bool YoloNgBoard::savePosts()
{
#ifdef LOGOS_CORE_AVAILABLE
    if (!m_kv) {
        return false;
    }

    void* libself2 = dlopen(nullptr, RTLD_NOW);
    auto kv_put = libself2 ? (bool(*)(void*,const char*,const char*))dlsym(libself2, "logos_kv_put") : nullptr;
    if (libself2) dlclose(libself2);

    QJsonArray array;
    for (const auto& post : m_posts) {
        QJsonObject obj;
        obj[QStringLiteral("id")] = post.id;
        obj[QStringLiteral("author")] = post.author;
        obj[QStringLiteral("content")] = post.content;
        obj[QStringLiteral("timestamp")] = post.timestamp.toString(Qt::ISODate);
        obj[QStringLiteral("likes")] = post.likes;
        obj[QStringLiteral("parentId")] = post.parentId;
        obj[QStringLiteral("inscriptionId")] = post.inscriptionId;
        array.append(obj);
    }

    QJsonDocument doc(array);
    if (kv_put) kv_put(m_kv, "yolo_ng_posts", doc.toJson(QJsonDocument::Compact).constData());
    qDebug() << "YoloNgBoard: Saved" << m_posts.size() << "posts to storage";
    return true;
#else
    return false;
#endif
}

#ifdef LOGOS_CORE_AVAILABLE

void YoloNgBoard::handleRequest(const QString& method, const QVariantMap& params, void* callback)
{
    qDebug() << "YoloNgBoard: Handling request:" << method;

    QVariantMap response;
    response[QStringLiteral("success")] = true;

    if (method == QStringLiteral("get_posts")) {
        response[QStringLiteral("posts")] = posts();
    } else if (method == QStringLiteral("create_post")) {
        QString author = params[QStringLiteral("author")].toString();
        QString content = params[QStringLiteral("content")].toString();
        QString parentId = params[QStringLiteral("parent_id")].toString();
        QString postId = createPost(author, content, parentId);
        response[QStringLiteral("post_id")] = postId;
    } else if (method == QStringLiteral("delete_post")) {
        QString postId = params[QStringLiteral("post_id")].toString();
        deletePost(postId);
    } else if (method == QStringLiteral("like_post")) {
        QString postId = params[QStringLiteral("post_id")].toString();
        likePost(postId);
    } else if (method == QStringLiteral("get_board_info")) {
        QVariantMap info;
        info[QStringLiteral("name")] = boardName();
        info[QStringLiteral("description")] = boardDescription();
        info[QStringLiteral("post_count")] = postCount();
        response[QStringLiteral("info")] = info;
    } else {
        response[QStringLiteral("success")] = false;
        response[QStringLiteral("error")] = QStringLiteral("Unknown method: ") + method;
    }

    if (callback) {
        void* libself3 = dlopen(nullptr, RTLD_NOW);
        auto req_complete = libself3 ? (void(*)(void*,const char*))dlsym(libself3, "logos_request_complete") : nullptr;
        if (libself3) dlclose(libself3);
        QJsonDocument doc(QJsonObject::fromVariantMap(response));
        if (req_complete) req_complete(callback, doc.toJson(QJsonDocument::Compact).constData());
    }
}

#endif // LOGOS_CORE_AVAILABLE
