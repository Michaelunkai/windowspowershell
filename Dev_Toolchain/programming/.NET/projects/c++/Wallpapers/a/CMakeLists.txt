cmake_minimum_required(VERSION 3.10)
project(WallpaperChanger)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Set to build as Windows application (no console)
if(WIN32)
    set(CMAKE_WIN32_EXECUTABLE ON)
endif()

add_executable(wallpaper_changer WIN32 wallpaper_changer.cpp)

# Link Windows libraries
target_link_libraries(wallpaper_changer winhttp user32)

# Set output directory
set_target_properties(wallpaper_changer PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
)
