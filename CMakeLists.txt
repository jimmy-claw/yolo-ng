cmake_minimum_required(VERSION 3.16)
project(yolo_ng VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# ── Logos SDK + liblogos (optional) ───────────────────────────────────────────
set(LOGOS_CPP_SDK_ROOT "" CACHE PATH "Path to logos-cpp-sdk install")
set(LOGOS_LIBLOGOS_ROOT "" CACHE PATH "Path to logos-liblogos install")

set(LOGOS_CORE_AVAILABLE OFF)

if(NOT "${LOGOS_CPP_SDK_ROOT}" STREQUAL "" AND NOT "${LOGOS_LIBLOGOS_ROOT}" STREQUAL "")
    # Check if SDK headers exist
    if(EXISTS "${LOGOS_LIBLOGOS_ROOT}/include" AND EXISTS "${LOGOS_CPP_SDK_ROOT}/include")
        set(LOGOS_CORE_AVAILABLE ON)
        
        add_library(logos_cpp_sdk INTERFACE)
        target_include_directories(logos_cpp_sdk INTERFACE
            "${LOGOS_LIBLOGOS_ROOT}/include"
            "${LOGOS_CPP_SDK_ROOT}/include"
            "${LOGOS_CPP_SDK_ROOT}/include/cpp"
            "${LOGOS_CPP_SDK_ROOT}/include/core"
        )

        add_library(logos_core SHARED IMPORTED)
        set_target_properties(logos_core PROPERTIES
            IMPORTED_LOCATION "${LOGOS_LIBLOGOS_ROOT}/lib/liblogos_core.so"
        )

        find_library(LOGOS_SDK_LIB logos_sdk PATHS "${LOGOS_CPP_SDK_ROOT}/lib" NO_DEFAULT_PATH)
        message(STATUS "Logos SDK: Found and enabled")
    else()
        message(STATUS "Logos SDK: Headers not found, building without core integration")
    endif()
endif()

# ── Headless logoscore module plugin ─────────────────────────────────────────
option(BUILD_MODULE "Build headless logoscore plugin" OFF)

if(BUILD_MODULE)
    if(NOT LOGOS_CPP_SDK_ROOT OR NOT LOGOS_LIBLOGOS_ROOT)
        message(FATAL_ERROR "BUILD_MODULE requires -DLOGOS_CPP_SDK_ROOT=<path> -DLOGOS_LIBLOGOS_ROOT=<path>")
    endif()

    find_package(Qt6 REQUIRED COMPONENTS Core RemoteObjects)

    qt_add_plugin(yolo_ng_plugin CLASS_NAME YoloNgPlugin)
    set_target_properties(yolo_ng_plugin PROPERTIES
        PREFIX ""
        OUTPUT_NAME "yolo_ng_plugin"
    )

    target_sources(yolo_ng_plugin PRIVATE
        src/yolo_ng_plugin.cpp
        src/yolo_ng_plugin.h
        src/yolo_ng_board.cpp
        src/yolo_ng_board.h
    )

    target_include_directories(yolo_ng_plugin PRIVATE
        src
        ${CMAKE_SOURCE_DIR}
        "${LOGOS_LIBLOGOS_ROOT}/include"
        "${LOGOS_CPP_SDK_ROOT}/include"
        "${LOGOS_CPP_SDK_ROOT}/include/cpp"
        "${LOGOS_CPP_SDK_ROOT}/include/core"
    )

    # Link logos_core for LogosAPI/PluginInterface symbols (but do NOT define
    # LOGOS_CORE_AVAILABLE — the board's extern-C KV stubs don't exist yet).
    find_library(MODULE_LOGOS_CORE_LIB logos_core
        HINTS "${LOGOS_LIBLOGOS_ROOT}/lib" NO_DEFAULT_PATH)
    target_link_libraries(yolo_ng_plugin PRIVATE
        Qt6::Core Qt6::RemoteObjects
        ${MODULE_LOGOS_CORE_LIB}
    )

    target_compile_definitions(yolo_ng_plugin PRIVATE
        QT_PLUGIN
        YOLO_NG_PLUGIN
    )

    if(APPLE)
        set_target_properties(yolo_ng_plugin PROPERTIES
            BUILD_RPATH   "@loader_path"
            INSTALL_RPATH "@loader_path"
        )
    elseif(UNIX)
        set_target_properties(yolo_ng_plugin PROPERTIES
            BUILD_RPATH   "$ORIGIN"
            INSTALL_RPATH "$ORIGIN"
        )
    endif()

    install(TARGETS yolo_ng_plugin
        LIBRARY DESTINATION lib
    )
endif()

# ── UI Plugin (IComponent for logos-app) ─────────────────────────────────────
option(BUILD_UI_PLUGIN "Build the IComponent UI plugin for logos-app" OFF)

if(BUILD_UI_PLUGIN)
    find_package(Qt6 REQUIRED COMPONENTS Widgets Quick QuickWidgets)

    # component-interfaces (IComponent.h)
    find_package(component-interfaces QUIET)
    if(NOT component-interfaces_FOUND)
        add_library(component-interfaces INTERFACE)
        target_include_directories(component-interfaces INTERFACE
            "${CMAKE_CURRENT_SOURCE_DIR}/interfaces"
        )
    endif()

    set(UI_TARGET yolo_ng_ui)

    message(STATUS "UI plugin: CMAKE_SOURCE_DIR=${CMAKE_SOURCE_DIR}")
    message(STATUS "UI plugin: UI_SOURCE_DIR=${UI_SOURCE_DIR}")

    add_library(${UI_TARGET} SHARED
        "${CMAKE_SOURCE_DIR}/src/yolo_ng_ui_component.cpp"
        "${CMAKE_SOURCE_DIR}/qml/yolo_ng.qrc"
        "${CMAKE_SOURCE_DIR}/src/yolo_ng_board.cpp"
    )

    target_include_directories(${UI_TARGET} PRIVATE
        "${CMAKE_SOURCE_DIR}/src"
        "${CMAKE_SOURCE_DIR}"
        "${CMAKE_SOURCE_DIR}/interfaces"
    )

    get_target_property(INC_DIRS ${UI_TARGET} INCLUDE_DIRECTORIES)
    message(STATUS "UI plugin: Include dirs=${INC_DIRS}")

    target_compile_definitions(${UI_TARGET} PRIVATE
        YOLO_NG_UI_BUILD
        YOLO_NG_UI_METADATA_FILE="${CMAKE_SOURCE_DIR}/ui_metadata.json"
    )

    target_link_libraries(${UI_TARGET} PRIVATE
        Qt6::Core
        Qt6::Widgets
        Qt6::Quick
        Qt6::Qml
        Qt6::QuickWidgets
        component-interfaces
    )

    if(LOGOS_CORE_AVAILABLE)
        find_package(Qt6 REQUIRED COMPONENTS RemoteObjects)
        target_link_libraries(${UI_TARGET} PRIVATE
            Qt6::RemoteObjects
            logos_cpp_sdk
            logos_core
            ${LOGOS_SDK_LIB}
        )
        target_compile_definitions(${UI_TARGET} PRIVATE LOGOS_CORE_AVAILABLE)
        target_link_libraries(${UI_TARGET} PRIVATE dl)
    endif()

    if(APPLE)
        set_target_properties(${UI_TARGET} PROPERTIES
            BUILD_RPATH   "@loader_path"
            INSTALL_RPATH "@loader_path"
        )
    elseif(UNIX)
        set_target_properties(${UI_TARGET} PROPERTIES
            BUILD_RPATH   "$ORIGIN"
            INSTALL_RPATH "$ORIGIN"
        )
    endif()

    install(TARGETS ${UI_TARGET}
        LIBRARY DESTINATION lib
    )
endif()
