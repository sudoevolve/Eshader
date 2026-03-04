cmake_minimum_required(VERSION 3.16)
project(Eshader VERSION 0.1 LANGUAGES CXX)
find_package(Qt6 REQUIRED COMPONENTS Quick Multimedia Network ShaderTools)
qt_standard_project_setup(REQUIRES 6.8)
qt_add_executable(Eshader
    main.cpp
    ShaderCompiler.h
    ShaderCompiler.cpp
)
file(GLOB_RECURSE QML_COMPONENTS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} CONFIGURE_DEPENDS "components/*.qml")
qt_add_qml_module(Eshader
    URI EvolveUI
    VERSION 1.0
    QML_FILES
                Main.qml
                pages/HomePage.qml
                pages/ProjectPage.qml
                pages/ShaderPage.qml
                pages/SettingsPage.qml
                ${QML_COMPONENTS}
)
qt_add_resources(APP_RESOURCES
    src.qrc
)
target_sources(Eshader PRIVATE ${APP_RESOURCES})
target_link_libraries(Eshader PRIVATE Qt6::Quick Qt6::Multimedia Qt6::Network Qt6::ShaderTools)
# Ensure ShaderTools is linked
set_target_properties(Eshader PROPERTIES WIN32_EXECUTABLE TRUE)
