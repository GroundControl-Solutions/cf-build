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
	# VS sometimes uses the full version and sometimes uses only the major version, so search for both
	string(REPLACE "." ";" clang_version_list "${CMAKE_C_COMPILER_VERSION}")
	list(POP_FRONT clang_version_list clang_major_version)
	get_filename_component(clang_bin_dir "${CMAKE_C_COMPILER}" DIRECTORY)
	find_library(CLANG_BUILTINS_PATH "clang_rt.builtins-${CLANG_BUILTINS_ARCH}.lib"
		HINTS
		"${clang_bin_dir}/../lib/clang/${CMAKE_C_COMPILER_VERSION}/lib/windows"
		"${clang_bin_dir}/../lib/clang/${clang_major_version}/lib/windows"
		NO_DEFAULT_PATH
		REQUIRED
	)
endif()

set(CF_DEPLOYMENT_SWIFT OFF CACHE BOOL "" FORCE)

set(HAS_LIBDISPATCH_API OFF CACHE BOOL "" FORCE)
set(BUILD_NETWORKING OFF CACHE BOOL "" FORCE)
set(BUILD_TOOLS OFF CACHE BOOL "" FORCE)

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
	-Wno-error=unused-but-set-variable
	-Wno-unused-but-set-variable
	-Wno-error=unused-label
	-Wno-unused-label
	-Wno-error=sign-compare
	-Wno-sign-compare
	-Wno-error=nonnull
	-Wno-nonnull
	-Wno-error=missing-field-initializers
	-Wno-missing-field-initializers
)

add_subdirectory(swift-corelibs-foundation/Sources/BlocksRuntime)
add_subdirectory(swift-corelibs-foundation/Sources/UUID)
add_subdirectory(swift-corelibs-foundation/CoreFoundation)

target_compile_options(CoreFoundation
	PRIVATE
	${clang_warnings}
)
target_link_libraries(CoreFoundation
	PRIVATE
	uuid
	${CLANG_BUILTINS_PATH}
)
target_include_directories(CoreFoundation
	PRIVATE
	"${CMAKE_CURRENT_BINARY_DIR}/uuid-headers"
)

# For some reason this is done in the root CMakeLists instead of the UUID CMakeLists, so replicate it here
configure_file(
	${CMAKE_CURRENT_SOURCE_DIR}/swift-corelibs-foundation/Sources/UUID/uuid.h
	${CMAKE_CURRENT_BINARY_DIR}/uuid-headers/uuid/uuid.h
	COPYONLY
)

execute_process(
	COMMAND "${CMAKE_COMMAND}" -E echo _MSC_VER _MSC_FULL_VER
	COMMAND "${CMAKE_C_COMPILER}" /E -
	OUTPUT_VARIABLE versions_text
	COMMAND_ERROR_IS_FATAL ANY
)
string(REPLACE ";" "_" versions_text2 "${versions_text}")
string(REGEX REPLACE "\r?\n" ";" version_list "${versions_text2}")
list(FILTER version_list INCLUDE REGEX "^[0-9]* [0-9]*$")
string(REPLACE " " ";" version_nums "${version_list}")
list(POP_FRONT version_nums ver full_ver)
if(NOT ver OR NOT full_ver OR version_nums)
	message(FATAL_ERROR "Could not parse MSVC version; output was ${versions_text}")
endif()
string(LENGTH "${ver}" ver_length)
string(SUBSTRING "${full_ver}" 0 ${ver_length} ver_prefix)
if(NOT ver_prefix STREQUAL ver)
	message(FATAL_ERROR "Full version '${full_ver}' does not start with version '${ver}'")
endif()
string(SUBSTRING "${full_ver}" ${ver_length} -1 build_ver)
math(EXPR major_length "${ver_length}-2")
string(SUBSTRING "${ver}" 0 ${major_length} major_ver)
string(SUBSTRING "${ver}" ${major_length} -1 minor_ver)

message(NOTICE "Clang is imitating MSVC version ${major_ver}.${minor_ver}.${build_ver}")

include(CMakePackageConfigHelpers)
configure_package_config_file(
	GCCoreFoundationConfig.cmake.in
	${CMAKE_CURRENT_BINARY_DIR}/cmake/GCCoreFoundationConfig.cmake
	INSTALL_DESTINATION "cmake"
)
