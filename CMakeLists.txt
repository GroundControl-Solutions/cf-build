cmake_minimum_required(VERSION 3.18)

set(CMAKE_BUILD_TYPE "RelWithDebInfo" CACHE STRING "Build type")
set(CMAKE_C_COMPILER clang-cl)
set(CMAKE_CXX_COMPILER clang-cl)
set(BUILD_SHARED_LIBS ON)
# The CoreFoundation CMakeLists.txt lists ASM before C, which causes CMake to pick the wrong linker (https://gitlab.kitware.com/cmake/cmake/-/issues/22495), so declare them in a working order here
project(cf-build LANGUAGES C CXX ASM)

add_custom_target(fail_build
	${CMAKE_COMMAND} -E false
	VERBATIM
)
add_library(fail_build_interface INTERFACE IMPORTED)
add_dependencies(fail_build_interface fail_build)

set(CLANG_BUILTINS_ARCH "" CACHE STRING "Look for clang_rt.builtins-<arch> and explicitly link it")
if(CLANG_BUILTINS_ARCH)
	# For some reason this isn't linked by default and isn't in the default linker path, so we need to explicitly search for it
	get_filename_component(clang_bin_dir "${CMAKE_C_COMPILER}" DIRECTORY)
	find_library(clang_builtins "clang_rt.builtins-${CLANG_BUILTINS_ARCH}.lib"
		HINTS "${clang_bin_dir}/../lib/clang/${CMAKE_C_COMPILER_VERSION}/lib/windows"
		REQUIRED
	)
endif()

set(CF_DEPLOYMENT_SWIFT OFF CACHE BOOL "" FORCE)

# This directory contains fake finders for curl and libxml2, since they're not actually needed
list(INSERT CMAKE_MODULE_PATH 0 "${CMAKE_CURRENT_SOURCE_DIR}/cmake-package-configs")
set(CURL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/cmake-package-configs")
set(ICU_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/icu/icu/icu4c/source/dist/icu")

find_package(ICU REQUIRED COMPONENTS uc i18n)

set(clang_warnings
	-Werror=all
	-Werror=extra
	-Werror=incompatible-function-pointer-types
	-Werror=incompatible-pointer-types

	-Wno-error=switch
	-Wno-switch
	-Wno-error=unused-parameter
	-Wno-unused-parameter
	-Wno-error=unused-function
	-Wno-unused-function
	-Wno-error=unused-variable
	-Wno-unused-variable
	-Wno-error=sign-compare
	-Wno-sign-compare
	-Wno-error=nonnull
	-Wno-nonnull
)

add_subdirectory(swift-corelibs-libdispatch)
add_subdirectory(swift-corelibs-foundation/Sources/UUID)
add_subdirectory(swift-corelibs-foundation/CoreFoundation)

target_compile_options(CoreFoundation
	PRIVATE
	${clang_warnings}
)
target_link_libraries(CoreFoundation
	PRIVATE
	uuid
	${clang_builtins}
)
target_include_directories(CoreFoundation
	PRIVATE
	"${CMAKE_CURRENT_BINARY_DIR}/uuid-headers"
)

# For some reason this is done in the root CMakeLists instead of the UUID CMakeLists, so replicate it here
add_custom_command(OUTPUT ${CMAKE_BINARY_DIR}/uuid-headers/uuid/uuid.h
	COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/uuid-headers/uuid
	COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_CURRENT_SOURCE_DIR}/swift-corelibs-foundation/Sources/UUID/uuid.h ${CMAKE_CURRENT_BINARY_DIR}/uuid-headers/uuid/uuid.h
)
add_custom_target(uuid-headers
	DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/uuid-headers/uuid/uuid.h
)
add_dependencies(CoreFoundation uuid-headers)

target_compile_options(dispatch
	PRIVATE
	${clang_warnings}
)
