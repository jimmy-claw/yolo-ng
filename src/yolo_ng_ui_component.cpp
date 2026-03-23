#include "yolo_ng_ui_component.h"
#include "yolo_ng_board.h"

#include <QQuickWidget>
#include <QQmlContext>

YoloNgUIComponent::YoloNgUIComponent(QObject *parent) : QObject(parent) {}

QWidget* YoloNgUIComponent::createWidget(LogosAPI* logosAPI) {
    auto* quickWidget = new QQuickWidget();
    quickWidget->setMinimumSize(400, 500);
    quickWidget->setResizeMode(QQuickWidget::SizeRootObjectToView);

    auto* backend = new YoloNgBoard();
    backend->setParent(quickWidget);

#ifdef LOGOS_CORE_AVAILABLE
    if (logosAPI) {
        backend->initLogos(logosAPI);
    }
#endif

    quickWidget->rootContext()->setContextProperty("yoloNgBoard", backend);

    quickWidget->setSource(QUrl("qrc:/yolo_ng/main.qml"));

    return quickWidget;
}

void YoloNgUIComponent::destroyWidget(QWidget* widget) {
    delete widget;
}
