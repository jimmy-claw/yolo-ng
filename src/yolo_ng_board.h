#pragma once

#include <QObject>
#include <QString>
#include <QVector>
#include <QVariantList>
#include <QDateTime>

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
    Q_PROPERTY(QString boardName READ boardName CONSTANT)
    Q_PROPERTY(QString boardDescription READ boardDescription CONSTANT)
    Q_PROPERTY(QVariantList posts READ posts NOTIFY postsChanged)
    Q_PROPERTY(int postCount READ postCount NOTIFY postsChanged)

public:
    explicit YoloNgBoard(QObject* parent = nullptr);
    ~YoloNgBoard() override;

    // Board metadata
    QString boardName() const { return QStringLiteral("YOLO-NG"); }
    QString boardDescription() const { return QStringLiteral("Anonymous text board"); }

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

public slots:
    void shutdown();

signals:
    void postsChanged();
    void postCreated(const QString& postId);
    void postDeleted(const QString& postId);
    void errorOccurred(const QString& message);

private:
    QString generatePostId();
    Post* findPost(const QString& id);

#ifdef LOGOS_CORE_AVAILABLE
    void handleRequest(const QString& method, const QVariantMap& params, void* callback);
#endif

    QVector<Post> m_posts;
    int m_nextPostId = 1;

#ifdef LOGOS_CORE_AVAILABLE
    void* m_kv = nullptr;
#endif
};
