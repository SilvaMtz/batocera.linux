// Manage Minecraft: install, update and remove the Minecraft system's mods.
// The mod work is done by batocera-minecraft-mods; this shows it on the TV.

#include <QCommandLineParser>
#include <QDir>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QTimer>

#include "Backend.h"
#include "Gamepad.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("minecraft-manager"));
    QGuiApplication::setApplicationDisplayName(QStringLiteral("Manage Minecraft"));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral(
        "Manage Minecraft: install, update and remove mods for P1 and P2.\n"
        "MINECRAFT_MODS_CMD replaces the batocera-minecraft-mods command (for test data)."));
    parser.addHelpOption();
    const QCommandLineOption qmlOption(QStringLiteral("qml"), QStringLiteral("Folder with Main.qml."),
                                       QStringLiteral("dir"), QStringLiteral(MINECRAFT_MANAGER_QML));
    const QCommandLineOption windowedOption(QStringLiteral("windowed"),
                                            QStringLiteral("Run in a 1280x720 window, not full screen."));
    const QCommandLineOption pageOption(QStringLiteral("page"),
                                        QStringLiteral("Tab to start on: installed, browse or updates."),
                                        QStringLiteral("name"), QStringLiteral("installed"));
    const QCommandLineOption shotOption(QStringLiteral("screenshot"),
                                        QStringLiteral("Save a picture of the window and quit (for testing)."),
                                        QStringLiteral("file"));
    const QCommandLineOption delayOption(QStringLiteral("delay"),
                                         QStringLiteral("Milliseconds before --screenshot."),
                                         QStringLiteral("ms"), QStringLiteral("5000"));
    const QCommandLineOption keysOption(QStringLiteral("keys"),
                                        QStringLiteral("Before --screenshot, press these keys (comma separated "
                                                       "Qt key names, e.g. Down,Down,Select), for testing."),
                                        QStringLiteral("keys"));
    parser.addOptions({qmlOption, windowedOption, pageOption, shotOption, delayOption, keysOption});
    parser.process(app);

    Backend backend;
    Gamepad gamepad;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    engine.rootContext()->setContextProperty(QStringLiteral("gamepad"), &gamepad);
    engine.rootContext()->setContextProperty(QStringLiteral("startPage"), parser.value(pageOption));
    engine.rootContext()->setContextProperty(QStringLiteral("fullScreen"), !parser.isSet(windowedOption));
    engine.load(QUrl::fromLocalFile(QDir(parser.value(qmlOption)).filePath(QStringLiteral("Main.qml"))));
    if (engine.rootObjects().isEmpty())
        return 1;

    if (parser.isSet(shotOption)) {
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
        const QString file = parser.value(shotOption);
        const int delay = parser.value(delayOption).toInt();
        const QStringList keys = parser.value(keysOption).split(QLatin1Char(','), Qt::SkipEmptyParts);
        // Keys go in the second half of the wait, a little apart
        for (int i = 0; i < keys.size(); ++i) {
            QTimer::singleShot(delay / 2 + i * 300, window, [window, name = keys.at(i)] {
                const QKeySequence seq = QKeySequence::fromString(name);
                const int key = name == QLatin1String("Select") ? int(Qt::Key_Select)
                              : name == QLatin1String("Search") ? int(Qt::Key_Search)
                              : seq.isEmpty() ? 0 : seq[0].key();
                const QString text = key == Qt::Key_Space ? QStringLiteral(" ")
                                   : key < 0x01000000 ? name.toLower() : QString();
                QKeyEvent press(QEvent::KeyPress, key, Qt::NoModifier, text);
                QKeyEvent release(QEvent::KeyRelease, key, Qt::NoModifier);
                QCoreApplication::sendEvent(window, &press);
                QCoreApplication::sendEvent(window, &release);
            });
        }
        QTimer::singleShot(delay + keys.size() * 300, window, [window, file] {
            window->grabWindow().save(file);
            QCoreApplication::quit();
        });
    }
    return app.exec();
}
