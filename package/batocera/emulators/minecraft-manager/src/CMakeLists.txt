cmake_minimum_required(VERSION 3.21)
project(minecraft-manager VERSION 1.0 LANGUAGES CXX)

# Manage Minecraft: the Minecraft system's mod manager. A small C++ program
# (runs batocera-minecraft-mods, turns controller input into key presses)
# that shows QML screens read from disk at startup, so the screens can be
# changed without compiling.

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
include(GNUInstallDirs)

find_package(Qt6 6.5 REQUIRED COMPONENTS Gui Qml Quick)

# SDL2 for controllers: its CMake files, else pkg-config
find_package(SDL2 CONFIG QUIET)
if(TARGET SDL2::SDL2)
    set(SDL2_TARGET SDL2::SDL2)
else()
    find_package(PkgConfig)
    if(PkgConfig_FOUND)
        pkg_check_modules(SDL2_PC IMPORTED_TARGET sdl2)
        if(SDL2_PC_FOUND)
            set(SDL2_TARGET PkgConfig::SDL2_PC)
        endif()
    endif()
endif()

add_executable(minecraft-manager main.cpp Backend.cpp Backend.h Gamepad.cpp Gamepad.h)
target_link_libraries(minecraft-manager PRIVATE Qt6::Gui Qt6::Qml Qt6::Quick)
target_compile_definitions(minecraft-manager PRIVATE
    MINECRAFT_MANAGER_QML="${CMAKE_INSTALL_FULL_DATADIR}/minecraft-manager/qml")
if(SDL2_TARGET)
    target_compile_definitions(minecraft-manager PRIVATE HAVE_SDL2)
    target_link_libraries(minecraft-manager PRIVATE ${SDL2_TARGET})
else()
    message(WARNING "SDL2 not found: no controller input (keyboard and mouse only)")
endif()

install(TARGETS minecraft-manager RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(DIRECTORY qml/ DESTINATION ${CMAKE_INSTALL_DATADIR}/minecraft-manager/qml)
