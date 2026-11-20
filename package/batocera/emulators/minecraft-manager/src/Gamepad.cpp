#include "Gamepad.h"

#include <QCoreApplication>
#include <QGuiApplication>
#include <QKeyEvent>
#include <QWindow>

#ifdef HAVE_SDL2
#include <SDL.h>
#endif

namespace {
constexpr int kStickDeadZone = 16000;   // of 32767
constexpr int kTriggerPress = 16000;    // L2/R2 (0..32767): pressed above this,
constexpr int kTriggerRelease = 8000;   // released below this
constexpr int kFirstRepeatMs = 380;
constexpr int kRepeatMs = 90;
}

Gamepad::Gamepad(QObject *parent)
    : QObject(parent)
{
#ifdef HAVE_SDL2
    SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS, "1");
    if (SDL_Init(SDL_INIT_GAMECONTROLLER) != 0) {
        qWarning("No controller input: %s", SDL_GetError());
        return;
    }
    m_ready = true;
    for (int i = 0; i < SDL_NumJoysticks(); ++i) {
        if (SDL_IsGameController(i))
            SDL_GameControllerOpen(i);
        else  // Batocera's SDL has no built-in mappings: they come in SDL_GAMECONTROLLERCONFIG
            qWarning("Controller without a mapping, ignored: %s", SDL_JoystickNameForIndex(i));
    }
    updateConnected();
    connect(&m_timer, &QTimer::timeout, this, &Gamepad::poll);
    m_timer.start(16);
#endif
}

Gamepad::~Gamepad()
{
#ifdef HAVE_SDL2
    if (m_ready)
        SDL_Quit();
#endif
}

void Gamepad::send(int key, bool press)
{
    QWindow *window = QGuiApplication::focusWindow();
    if (!window) {
        const auto windows = QGuiApplication::topLevelWindows();
        window = windows.isEmpty() ? nullptr : windows.first();
    }
    if (!window)
        return;
    QKeyEvent event(press ? QEvent::KeyPress : QEvent::KeyRelease, key, Qt::NoModifier);
    QCoreApplication::sendEvent(window, &event);
}

void Gamepad::hold(int key)
{
    if (key == m_heldKey)
        return;
    if (m_heldKey)
        send(m_heldKey, false);
    m_heldKey = key;
    if (key) {
        send(key, true);
        m_heldFor.start();
        m_nextRepeat = kFirstRepeatMs;
    }
}

// Triggers are axes: one key press when pulled past halfway, no repeat
void Gamepad::trigger(bool &down, int value, int key)
{
    if (!down && value > kTriggerPress) {
        down = true;
        send(key, true);
    } else if (down && value < kTriggerRelease) {
        down = false;
        send(key, false);
    }
}

void Gamepad::updateConnected()
{
#ifdef HAVE_SDL2
    bool any = false;
    for (int i = 0; i < SDL_NumJoysticks(); ++i)
        any = any || SDL_IsGameController(i);
    if (any != m_connected) {
        m_connected = any;
        emit connectedChanged();
    }
#endif
}

void Gamepad::poll()
{
#ifdef HAVE_SDL2
    SDL_Event e;
    while (SDL_PollEvent(&e)) {
        switch (e.type) {
        case SDL_QUIT:  // SDL catches SIGTERM and SIGINT (batocera-minecraft stop) and sends this
            QCoreApplication::quit();
            break;
        case SDL_CONTROLLERDEVICEADDED:
            SDL_GameControllerOpen(e.cdevice.which);
            updateConnected();
            break;
        case SDL_CONTROLLERDEVICEREMOVED:
            if (SDL_GameController *pad = SDL_GameControllerFromInstanceID(e.cdevice.which))
                SDL_GameControllerClose(pad);
            updateConnected();
            break;
        case SDL_CONTROLLERBUTTONDOWN:
        case SDL_CONTROLLERBUTTONUP: {
            const bool down = e.type == SDL_CONTROLLERBUTTONDOWN;
            int key = 0;
            switch (e.cbutton.button) {
            case SDL_CONTROLLER_BUTTON_DPAD_UP: key = Qt::Key_Up; break;
            case SDL_CONTROLLER_BUTTON_DPAD_DOWN: key = Qt::Key_Down; break;
            case SDL_CONTROLLER_BUTTON_DPAD_LEFT: key = Qt::Key_Left; break;
            case SDL_CONTROLLER_BUTTON_DPAD_RIGHT: key = Qt::Key_Right; break;
            default: break;
            }
            if (key) {  // directions repeat while held
                m_dpadKey = down ? key : (m_dpadKey == key ? 0 : m_dpadKey);
                hold(m_dpadKey ? m_dpadKey : m_stickKey);
                break;
            }
            switch (e.cbutton.button) {
            case SDL_CONTROLLER_BUTTON_A: key = Qt::Key_Select; break;
            case SDL_CONTROLLER_BUTTON_B: key = Qt::Key_Escape; break;
            case SDL_CONTROLLER_BUTTON_X: key = Qt::Key_Backspace; break;
            case SDL_CONTROLLER_BUTTON_Y: key = Qt::Key_Search; break;
            case SDL_CONTROLLER_BUTTON_LEFTSHOULDER: key = Qt::Key_Backtab; break;
            case SDL_CONTROLLER_BUTTON_RIGHTSHOULDER: key = Qt::Key_Tab; break;
            default: break;
            }
            if (key)
                send(key, down);
            break;
        }
        case SDL_CONTROLLERAXISMOTION: {
            if (e.caxis.axis == SDL_CONTROLLER_AXIS_TRIGGERLEFT) {
                trigger(m_l2Down, e.caxis.value, Qt::Key_PageUp);
                break;
            }
            if (e.caxis.axis == SDL_CONTROLLER_AXIS_TRIGGERRIGHT) {
                trigger(m_r2Down, e.caxis.value, Qt::Key_PageDown);
                break;
            }
            if (e.caxis.axis != SDL_CONTROLLER_AXIS_LEFTX && e.caxis.axis != SDL_CONTROLLER_AXIS_LEFTY)
                break;
            SDL_GameController *pad = SDL_GameControllerFromInstanceID(e.caxis.which);
            if (!pad)
                break;
            const int x = SDL_GameControllerGetAxis(pad, SDL_CONTROLLER_AXIS_LEFTX);
            const int y = SDL_GameControllerGetAxis(pad, SDL_CONTROLLER_AXIS_LEFTY);
            int key = 0;
            if (qAbs(y) >= qAbs(x) && qAbs(y) > kStickDeadZone)
                key = y < 0 ? Qt::Key_Up : Qt::Key_Down;
            else if (qAbs(x) > kStickDeadZone)
                key = x < 0 ? Qt::Key_Left : Qt::Key_Right;
            m_stickKey = key;
            hold(m_dpadKey ? m_dpadKey : m_stickKey);
            break;
        }
        default:
            break;
        }
    }
    if (m_heldKey && m_heldFor.elapsed() >= m_nextRepeat) {
        send(m_heldKey, true);
        m_nextRepeat = m_heldFor.elapsed() + kRepeatMs;
    }
#endif
}
