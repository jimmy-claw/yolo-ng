#pragma once

#include "interfaces/IComponent.h"
#include <QObject>

class YoloNgUIComponent : public QObject, public IComponent
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID IComponent_iid FILE "ui_metadata.json")
    Q_INTERFACES(IComponent)

public:
    explicit YoloNgUIComponent(QObject *parent = nullptr);

    QWidget* createWidget(LogosAPI* logosAPI = nullptr) override;
    void destroyWidget(QWidget* widget) override;
};
