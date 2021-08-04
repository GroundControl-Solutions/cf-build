if(NOT LibXml2_FOUND)
	add_library(LibXml2::LibXml2 ALIAS fail_build_interface)
	set(LIBXML2_LIBRARY LibXml2::LibXml2)
	set(LIBXML2_LIBRARIES LibXml2::LibXml2)
	set(LIBXML2_VERSION "fake-libxml")
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(LibXml2
	REQUIRED_VARS LIBXML2_LIBRARIES LIBXML2_LIBRARY
	VERSION_VAR LIBXML2_VERSION_STRING
)
