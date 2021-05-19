project(nextdoor C CXX)
cmake_minimum_required(VERSION 2.8)

include_directories(src)
include_directories(example)
include_directories(googletest)
include_directories(AnyOption)

# ------------------------------------------------------------------------------
# setting default cmake type to Release
# ------------------------------------------------------------------------------

set(DEFAULT_BUILD_TYPE "Release")
if (NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    message(STATUS "Setting build type to '${DEFAULT_BUILD_TYPE}' as none was specified.")
    set(CMAKE_BUILD_TYPE "${DEFAULT_BUILD_TYPE}" CACHE
            STRING "Choose the type of build." FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
            "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif ()

# ------------------------------------------------------------------------------
# cmake configs
# ------------------------------------------------------------------------------

include(CheckLibraryExists)
include(GNUInstallDirs)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
include_directories(${CMAKE_CURRENT_SOURCE_DIR})

# reference: https://gitlab.kitware.com/cmake/community/-/wikis/doc/cmake/RPATH-handling#always-full-rpath
set(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE)
set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib")
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11 -Wall")
if (APPLE)
    set(CMAKE_MACOSX_RPATH ON)
else ()
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fopenmp -Werror -Wl,-rpath,$ORIGIN")
endif ()
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -O0 -g -fprofile-arcs -ftest-coverage")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O3 -g")

find_package(CUDA 9 REQUIRED)

include_directories(${CUDA_TOOLKIT_INCLUDE})
set(CUDA_LIBS ${CUDA_TOOLKIT_TARGET_DIR}/lib64/stubs/libcuda.so
        ${CUDA_TOOLKIT_TARGET_DIR}/lib64/libnvToolsExt.so
        ${CUDA_TOOLKIT_TARGET_DIR}/lib64/libcudart.so)

if (CUDA_VERSION VERSION_LESS "11.0")
    option(GEN_SM_30 "Whether to generate code for Compute Capability 3.0 devices" OFF)
    if (GEN_SM_30)
        set(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} -gencode arch=compute_30,code=sm_30")
    endif ()
endif ()

option(GEN_SM_35 "Whether to generate code for Compute Capability 3.5 devices" OFF)
if (GEN_SM_35)
    set(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} -gencode arch=compute_35,code=sm_35")
endif ()

option(GEN_SM_37 "Whether to generate code for Compute Capability 3.7 devices" OFF)
if (GEN_SM_37)
    set(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} -gencode arch=compute_37,code=sm_37")
endif ()

option(GEN_SM_50 "Whether to generate code for Compute Capability 5.0 devices" OFF)
if (GEN_SM_50)
    set(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} -gencode arch=compute_50,code=sm_50")
endif ()

option(GEN_SM_52 "Whether to generate code for Compute Capability 5.2 devices" OFF)
if (GEN_SM_52)
    set(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} -gencode arch=compute_52,code=sm_52")
endif ()

if (CUDA_VERSION VERSION_GREATER "7.6")
    option(GEN_SM_60 "Whether to generate code for Compute Capability 6.0 devices" ON)
    option(GEN_SM_61 "Whether to generate code for Compute Capability 6.1 devices" OFF)
    if (GEN_SM_60)
        set(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} -gencode arch=compute_60,code=sm_60")
    endif ()
    if (GEN_SM_61)
        set(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} -gencode arch=compute_61,code=sm_61")
    endif ()
endif ()

if ((CUDA_VERSION VERSION_GREATER "9.0") OR (CUDA_VERSION VERSION_EQUAL "9.0"))
    option(GEN_SM_70 "Whether to generate code for Compute Capability 7.0 devices" ON)
    if (GEN_SM_70)
        set(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} -gencode arch=compute_70,code=sm_70")
    endif ()
endif ()

if ((CUDA_VERSION VERSION_GREATER "10.0") OR (CUDA_VERSION VERSION_EQUAL "10.0"))
    option(GEN_SM_75 "Whether to generate code for Compute Capability 7.5 devices" OFF)
    if (GEN_SM_75)
        set(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} -gencode arch=compute_75,code=sm_75")
    endif ()
endif ()

if ((CUDA_VERSION VERSION_GREATER "11.0") OR (CUDA_VERSION VERSION_EQUAL "11.0"))
    option(GEN_SM_80 "Whether to generate code for Compute Capability 8.0 devices" OFF)
    if (GEN_SM_80)
        set(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} -gencode arch=compute_80,code=sm_80")
    endif ()
endif ()

if ((CUDA_VERSION VERSION_GREATER "11.2") OR (CUDA_VERSION VERSION_EQUAL "11.2"))
    option(GEN_SM_86 "Whether to generate code for Compute Capability 8.6 devices" OFF)
    if (GEN_SM_86)
        set(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} -gencode arch=compute_86,code=sm_86")
    endif ()
endif ()

set(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} -Wno-deprecated-gpu-targets")

if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    message("Debug mode")
    set(CUDA_NVCC_FLAGS ${CUDA_NVCC_FLAGS};-g;-lineinfo;-Xcompiler;-ggdb;-std=c++14;--extended-lambda)
else ()
    set(CUDA_NVCC_FLAGS ${CUDA_NVCC_FLAGS};-O3;-DNDEBUG;-Xcompiler;-DNDEBUG;-std=c++14;--extended-lambda)
endif ()

set(CUDA_PROPAGATE_HOST_FLAGS OFF)
set(CUDA_SEPARABLE_COMPILATION OFF)
message("-- Host Compiler: ${CUDA_HOST_COMPILER}")

# ------------------------------------------------------------------------------
# find_libraries
# ------------------------------------------------------------------------------

# find Threads------------------------------------------------------------------
set(CMAKE_THREAD_PREFER_PTHREAD ON)
find_package(Threads REQUIRED)

# ------------------------------------------------------------------------------
# generate libgrape-lite
# ------------------------------------------------------------------------------
#file(GLOB_RECURSE CORE_SRC_FILES "thirdparty/libgrape-lite/grape/*.cc")
#add_library(grape-lite ${CORE_SRC_FILES})

#target_link_libraries(grape-lite ${MPI_CXX_LIBRARIES}
#        ${CMAKE_THREAD_LIBS_INIT}
#        ${GLOG_LIBRARIES})


cuda_add_executable(uniformRandWalk example/uniformRandWalk.cu AnyOption/anyoption.cpp)
target_link_libraries(uniformRandWalk ${CUDA_curand_LIBRARY})

#cuda_add_executable(run_gpu examples/run_app.cu examples/flags.cc)
#target_include_directories(run_gpu PRIVATE
#        examples/analytical_apps)
#target_link_libraries(run_gpu grape-lite ${MPI_CXX_LIBRARIES}
#        ${GLOG_LIBRARIES} ${GFLAGS_LIBRARIES} ${CMAKE_DL_LIBS} ${NCCL_LIBRARIES})

