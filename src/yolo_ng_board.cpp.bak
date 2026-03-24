#include "yolo_ng_board.h"
#include <dlfcn.h>

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDebug>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QMap>
#include <QStandardPaths>
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

    // Load saved board lists
    loadMyBoards();
    loadFollowing();

    // Restore last active board name+secret from KV
    if (m_kv) {
        QString savedName = kvGet("yolo_ng_board_name");
        QString savedSecret = kvGet("yolo_ng_board_secret");
        if (!savedName.isEmpty() && !savedSecret.isEmpty()) {
            qInfo() << "YoloNgBoard: restoring saved board" << savedName;
            m_boardSecrets[savedName] = savedSecret;
            setBoard(savedName, savedSecret);
        }
    }
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
    m_logosAPI = api;
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

// ── KV helpers ──────────────────────────────────────────────────────────────

QString YoloNgBoard::kvGet(const char* key)
{
#ifdef LOGOS_CORE_AVAILABLE
    if (!m_kv) return {};
    void* libself = dlopen(nullptr, RTLD_NOW);
    auto kv_get = libself ? (bool(*)(void*,const char*,char**))dlsym(libself, "logos_kv_get") : nullptr;
    auto kv_free = libself ? (void(*)(char*))dlsym(libself, "logos_kv_free") : nullptr;
    if (libself) dlclose(libself);

    char* data = nullptr;
    if (kv_get && kv_get(m_kv, key, &data) && data) {
        QString result = QString::fromUtf8(data);
        if (kv_free) kv_free(data);
        return result;
    }
#else
    Q_UNUSED(key);
#endif
    return {};
}

void YoloNgBoard::kvPut(const char* key, const QString& value)
{
#ifdef LOGOS_CORE_AVAILABLE
    if (!m_kv) return;
    void* libself = dlopen(nullptr, RTLD_NOW);
    auto kv_put = libself ? (bool(*)(void*,const char*,const char*))dlsym(libself, "logos_kv_put") : nullptr;
    if (libself) dlclose(libself);
    if (kv_put) kv_put(m_kv, key, value.toUtf8().constData());
#else
    Q_UNUSED(key); Q_UNUSED(value);
#endif
}

// ── Board management ────────────────────────────────────────────────────────

void YoloNgBoard::setBoard(const QString& name, const QString& secret)
{
    QByteArray input = (name + ":" + secret).toUtf8();
    QByteArray hash = QCryptographicHash::hash(input, QCryptographicHash::Sha256);
    m_signingKeyHex = hash.toHex();
    m_boardName = name;

    QString dataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/yolo-ng/";
    QDir().mkpath(dataDir);
    QByteArray nameHash = QCryptographicHash::hash(name.toUtf8(), QCryptographicHash::Sha256);
    m_checkpointPath = dataDir + nameHash.toHex().left(16) + ".checkpoint";

    qInfo() << "YoloNgBoard: board set to" << name << "checkpoint:" << m_checkpointPath;
    m_readOnly = false;
    m_channelId.clear();

    // Cache secret in memory
    m_boardSecrets[name] = secret;

    // Persist last-active board
    kvPut("yolo_ng_board_name", name);
    kvPut("yolo_ng_board_secret", secret);

    // Add to myBoards if not already present
    bool found = false;
    for (const auto& b : m_myBoards) {
        if (b.toMap()[QStringLiteral("name")].toString() == name) {
            found = true;
            break;
        }
    }
    if (!found) {
        QVariantMap entry;
        entry[QStringLiteral("name")] = name;
        entry[QStringLiteral("channelId")] = m_signingKeyHex.left(16) + "...";
        m_myBoards.append(entry);
        saveMyBoards();
    }

    emit boardNameChanged();
    emit isReadOnlyChanged();
    emit boardsListChanged();
}

void YoloNgBoard::followBoard(const QString& channelId) {
    m_channelId = channelId;
    m_readOnly = true;
    m_boardName = channelId.left(8) + "..." + channelId.right(8);
    qInfo() << "YoloNgBoard: following channel" << channelId;

    // Add to following list if not already present
    bool found = false;
    for (const auto& f : m_following) {
        if (f.toMap()[QStringLiteral("channelId")].toString() == channelId) {
            found = true;
            break;
        }
    }
    if (!found) {
        QVariantMap entry;
        entry[QStringLiteral("channelId")] = channelId;
        entry[QStringLiteral("name")] = m_boardName;
        m_following.append(entry);
        saveFollowing();
    }

    emit boardNameChanged();
    emit isReadOnlyChanged();
    emit boardsListChanged();
    fetchPosts();
}

void YoloNgBoard::unfollowBoard(const QString& channelId) {
    for (int i = 0; i < m_following.size(); ++i) {
        if (m_following[i].toMap()[QStringLiteral("channelId")].toString() == channelId) {
            m_following.removeAt(i);
            saveFollowing();
            break;
        }
    }

    // If we're currently viewing this channel, disconnect
    if (m_channelId == channelId) {
        disconnectBoard();
    }

    emit boardsListChanged();
}

void YoloNgBoard::disconnectBoard() {
    m_boardName.clear();
    m_signingKeyHex.clear();
    m_channelId.clear();
    m_checkpointPath.clear();
    m_readOnly = false;
    m_posts.clear();
    emit boardNameChanged();
    emit isReadOnlyChanged();
    emit postsChanged();
}

void YoloNgBoard::switchToBoard(const QString& name) {
    QString secret = m_boardSecrets.value(name);
    if (secret.isEmpty()) {
        qWarning() << "YoloNgBoard: no cached secret for board" << name;
        m_errorMessage = QStringLiteral("No secret cached for board: ") + name;
        emit errorOccurred(m_errorMessage);
        return;
    }
    setBoard(name, secret);
    loadPosts();
    emit postsChanged();
}

void YoloNgBoard::removeBoard(const QString& name) {
    for (int i = 0; i < m_myBoards.size(); ++i) {
        if (m_myBoards[i].toMap()[QStringLiteral("name")].toString() == name) {
            m_myBoards.removeAt(i);
            saveMyBoards();
            break;
        }
    }
    m_boardSecrets.remove(name);

    // If we're currently on this board, disconnect
    if (m_boardName == name) {
        disconnectBoard();
    }

    emit boardsListChanged();
}

QVariantList YoloNgBoard::myBoards() const {
    return m_myBoards;
}

QVariantList YoloNgBoard::followingChannels() const {
    return m_following;
}

// ── Multi-board persistence ─────────────────────────────────────────────────

void YoloNgBoard::saveMyBoards() {
    QJsonArray arr;
    for (const auto& b : m_myBoards) {
        QVariantMap m = b.toMap();
        QJsonObject obj;
        obj[QStringLiteral("name")] = m[QStringLiteral("name")].toString();
        obj[QStringLiteral("channelId")] = m[QStringLiteral("channelId")].toString();
        arr.append(obj);
    }
    kvPut("yolo_ng_my_boards", QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact)));
}

void YoloNgBoard::loadMyBoards() {
    QString json = kvGet("yolo_ng_my_boards");
    if (json.isEmpty()) return;
    QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    if (!doc.isArray()) return;
    m_myBoards.clear();
    for (const auto& v : doc.array()) {
        QVariantMap entry;
        entry[QStringLiteral("name")] = v[QStringLiteral("name")].toString();
        entry[QStringLiteral("channelId")] = v[QStringLiteral("channelId")].toString();
        m_myBoards.append(entry);
    }
    qDebug() << "YoloNgBoard: loaded" << m_myBoards.size() << "my boards";
}

void YoloNgBoard::saveFollowing() {
    QJsonArray arr;
    for (const auto& f : m_following) {
        QVariantMap m = f.toMap();
        QJsonObject obj;
        obj[QStringLiteral("channelId")] = m[QStringLiteral("channelId")].toString();
        obj[QStringLiteral("name")] = m[QStringLiteral("name")].toString();
        arr.append(obj);
    }
    kvPut("yolo_ng_following", QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact)));
}

void YoloNgBoard::loadFollowing() {
    QString json = kvGet("yolo_ng_following");
    if (json.isEmpty()) return;
    QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    if (!doc.isArray()) return;
    m_following.clear();
    for (const auto& v : doc.array()) {
        QVariantMap entry;
        entry[QStringLiteral("channelId")] = v[QStringLiteral("channelId")].toString();
        entry[QStringLiteral("name")] = v[QStringLiteral("name")].toString();
        m_following.append(entry);
    }
    qDebug() << "YoloNgBoard: loaded" << m_following.size() << "following channels";
}

// ── Post fetching ───────────────────────────────────────────────────────────

void YoloNgBoard::fetchPosts() {
    // Retry getting client if not available yet
    if (!m_zoneSequencer && m_logosAPI) {
        m_zoneSequencer = m_logosAPI->getClient("liblogos_zone_sequencer_module");
        if (m_zoneSequencer) qInfo() << "YoloNgBoard: zone_sequencer_module client acquired on retry";
    }
    if (!m_zoneSequencer || m_channelId.isEmpty()) {
        qWarning() << "YoloNgBoard: cannot fetch posts - sequencer:" << (m_zoneSequencer != nullptr) << "channelId:" << m_channelId;
        return;
    }

    static const QString nodeUrl = QStringLiteral("http://192.168.0.209:8080");
    m_zoneSequencer->invokeRemoteMethod(
        "liblogos_zone_sequencer_module", "set_node_url", nodeUrl);

    QVariant result = m_zoneSequencer->invokeRemoteMethod(
        "liblogos_zone_sequencer_module", "query_channel",
        m_channelId, 50);

    QString json = result.toString();
    qInfo() << "YoloNgBoard: fetchPosts got" << json.length() << "bytes";
    if (json.isEmpty() || json == "[]") return;

    QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    if (!doc.isArray()) return;

    m_posts.clear();
    for (const QJsonValue& v : doc.array()) {
        Post post;
        post.id = v["id"].toString();
        post.content = v["data"].toString();
        post.author = QStringLiteral("unknown");
        post.timestamp = QDateTime::currentDateTime();
        m_posts.prepend(post);
    }
    emit postsChanged();
}

// ── Post management ─────────────────────────────────────────────────────────

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
    if (m_readOnly && !m_channelId.isEmpty()) {
        fetchPosts();
    } else {
        loadPosts();
        emit postsChanged();
    }
}

QString YoloNgBoard::createPost(const QString& author, const QString& content, const QString& parentId)
{
    if (m_readOnly) {
        qWarning() << "YoloNgBoard: read-only board, cannot post";
        return QString();
    }

    if (content.trimmed().isEmpty()) {
        m_errorMessage = QStringLiteral("Post content cannot be empty");
        emit errorOccurred(m_errorMessage);
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
    m_errorMessage = QStringLiteral("Post not found");
    emit errorOccurred(m_errorMessage);
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
        m_errorMessage = QStringLiteral("Post not found");
        emit errorOccurred(m_errorMessage);
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
    // Retry getting client if not available yet (module may not be loaded at initLogos time)
    if (!m_zoneSequencer && m_logosAPI) {
        m_zoneSequencer = m_logosAPI->getClient("liblogos_zone_sequencer_module");
        if (m_zoneSequencer) qInfo() << "YoloNgBoard: zone_sequencer_module client acquired on retry";
    }
    if (!m_zoneSequencer) {
        qWarning() << "YoloNgBoard: zone sequencer client not available";
        return;
    }

    if (m_signingKeyHex.isEmpty()) {
        qWarning() << "YoloNgBoard: no board set, cannot inscribe";
        return;
    }

    static const QString nodeUrl = QStringLiteral("http://192.168.0.209:8080");

    // Configure the zone sequencer (idempotent)
    m_zoneSequencer->invokeRemoteMethod(
        "liblogos_zone_sequencer_module", "set_node_url", nodeUrl);
    m_zoneSequencer->invokeRemoteMethod(
        "liblogos_zone_sequencer_module", "set_signing_key", m_signingKeyHex);
    m_zoneSequencer->invokeRemoteMethod(
        "liblogos_zone_sequencer_module", "set_checkpoint_path", m_checkpointPath);

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
