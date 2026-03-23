#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVector>
#include <QVariantList>
#include <QDateTime>

class LogosAPI;
class LogosAPIClient;

/**
 * Post — represents a single post on the YOLO-NG text board
 */
struct Post
{
    QString id;
    QString author;
    QString content;
    QDateTime timestamp;
    int likes = 0;
    QString parentId;
    QString inscriptionId;
};

/**
 * YoloNgBoard — the main board logic for YOLO-NG text board
 *
 * Handles post creation, retrieval, and basic interactions.
 * Integrates with Logos core when available (KV storage, requests).
 */
class YoloNgBoard : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString boardName READ boardName NOTIFY boardNameChanged)
    Q_PROPERTY(QString boardDescription READ boardDescription CONSTANT)
    Q_PROPERTY(QVariantList posts READ posts NOTIFY postsChanged)
    Q_PROPERTY(int postCount READ postCount NOTIFY postsChanged)
    Q_PROPERTY(QString channelId READ channelId NOTIFY boardNameChanged)
    Q_PROPERTY(bool readOnly READ readOnly NOTIFY boardNameChanged)
    Q_PROPERTY(bool isConfigured READ isConfigured NOTIFY boardNameChanged)
    Q_PROPERTY(bool isReadOnly READ isReadOnly NOTIFY isReadOnlyChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorOccurred)

public:
    explicit YoloNgBoard(QObject* parent = nullptr);
    ~YoloNgBoard() override;

    // Board metadata
    QString boardName() const { return m_boardName; }
    QString boardDescription() const { return QStringLiteral("Anonymous text board"); }
    QString channelId() const { return m_channelId; }
    bool readOnly() const { return m_readOnly; }
    bool isConfigured() const { return !m_boardName.isEmpty(); }
    bool isReadOnly() const { return m_readOnly; }
    QString errorMessage() const { return m_errorMessage; }

    Q_INVOKABLE void setBoard(const QString& name, const QString& secret);
    Q_INVOKABLE void followBoard(const QString& channelId);
    Q_INVOKABLE void unfollowBoard(const QString& channelId);
    Q_INVOKABLE void fetchPosts();

    // Multi-board management
    Q_INVOKABLE QVariantList myBoards() const;
    Q_INVOKABLE QVariantList followingChannels() const;
    Q_INVOKABLE void switchToBoard(const QString& name);
    Q_INVOKABLE void removeBoard(const QString& name);
    Q_INVOKABLE void disconnectBoard();

    // Post management
    QVariantList posts() const;
    int postCount() const { return m_posts.size(); }

    Q_INVOKABLE void refreshPosts();
    Q_INVOKABLE QString createPost(const QString& author, const QString& content, const QString& parentId = QString());
    Q_INVOKABLE void deletePost(const QString& postId);
    Q_INVOKABLE void likePost(const QString& postId);

    // Storage operations
    bool loadPosts();
    bool savePosts();

    // Logos integration
    void initLogos(LogosAPI* api);

public slots:
    void shutdown();

signals:
    void postsChanged();
    void postCreated(const QString& postId);
    void postDeleted(const QString& postId);
    void errorOccurred(const QString& message);
    void boardNameChanged();
    void isReadOnlyChanged();
    void boardsListChanged();

private:
    QString generatePostId();
    Post* findPost(const QString& id);
    void inscribePost(const QString& postId, const QString& content);
    void saveMyBoards();
    void loadMyBoards();
    void saveFollowing();
    void loadFollowing();
    QString kvGet(const char* key);
    void kvPut(const char* key, const QString& value);

#ifdef LOGOS_CORE_AVAILABLE
    void handleRequest(const QString& method, const QVariantMap& params, void* callback);
#endif

    QVector<Post> m_posts;
    int m_nextPostId = 1;
    QString m_boardName;
    QString m_signingKeyHex;
    QString m_checkpointPath;
    QString m_channelId;
    bool m_readOnly = false;
    QString m_errorMessage;

    // Multi-board state: list of {name, channelId} for my boards
    QVariantList m_myBoards;
    // Following state: list of {channelId, name} for followed channels
    QVariantList m_following;
    // Cache of board secrets keyed by board name (in-memory only)
    QMap<QString, QString> m_boardSecrets;

#ifdef LOGOS_CORE_AVAILABLE
    void* m_kv = nullptr;
#endif
    LogosAPIClient* m_zoneSequencer = nullptr;
    LogosAPI* m_logosAPI = nullptr;
};
