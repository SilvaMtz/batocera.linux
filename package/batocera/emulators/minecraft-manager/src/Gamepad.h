#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QTimer>

// Controllers drive the screens through ordinary key presses, so QML handles
// keyboard and controller the same way:
//   D-pad / left stick  arrows (held: repeats)
//   A                   Key_Select    (Enter on a keyboard does the same)
//   B                   Key_Escape    back
//   X                   Key_Backspace
//   Y                   Key_Search    ('/' on a keyboard)
//   LB / RB             Key_Backtab / Key_Tab   switch tabs
// Built without SDL2 (no controller library), it only reports no controller.
class Gamepad : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)

public:
    explicit Gamepad(QObject *parent = nullptr);
    ~Gamepad() override;

    bool connected() const { return m_connected; }

signals:
    void connectedChanged();

private:
    void poll();
    void send(int key, bool press);
    void hold(int key);  // direction now held (0: none)
    void updateConnected();

    QTimer m_timer;
    bool m_connected = false;
    bool m_ready = false;
    int m_heldKey = 0;
    QElapsedTimer m_heldFor;
    qint64 m_nextRepeat = 0;
    int m_stickKey = 0;
    int m_dpadKey = 0;
};
