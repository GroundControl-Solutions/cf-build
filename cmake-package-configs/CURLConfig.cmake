set(empty_dir "${CMAKE_CURRENT_BINARY_DIR}/empty-dir")
file(MAKE_DIRECTORY "${empty_dir}")

set(CURL_FOUND ON)
set(CURL_VERSION "fake-curl")
set(CURL_DIR "${empty_dir}")
add_library(CURL::libcurl ALIAS fail_build_interface)
set(CURL_LIBRARY CURL::libcurl)
