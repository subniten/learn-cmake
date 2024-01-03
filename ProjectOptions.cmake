include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(learn_make_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(learn_make_setup_options)
  option(learn_make_ENABLE_HARDENING "Enable hardening" ON)
  option(learn_make_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    learn_make_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    learn_make_ENABLE_HARDENING
    OFF)

  learn_make_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR learn_make_PACKAGING_MAINTAINER_MODE)
    option(learn_make_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(learn_make_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(learn_make_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(learn_make_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(learn_make_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(learn_make_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(learn_make_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(learn_make_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(learn_make_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(learn_make_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(learn_make_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(learn_make_ENABLE_PCH "Enable precompiled headers" OFF)
    option(learn_make_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(learn_make_ENABLE_IPO "Enable IPO/LTO" ON)
    option(learn_make_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(learn_make_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(learn_make_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(learn_make_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(learn_make_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(learn_make_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(learn_make_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(learn_make_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(learn_make_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(learn_make_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(learn_make_ENABLE_PCH "Enable precompiled headers" OFF)
    option(learn_make_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      learn_make_ENABLE_IPO
      learn_make_WARNINGS_AS_ERRORS
      learn_make_ENABLE_USER_LINKER
      learn_make_ENABLE_SANITIZER_ADDRESS
      learn_make_ENABLE_SANITIZER_LEAK
      learn_make_ENABLE_SANITIZER_UNDEFINED
      learn_make_ENABLE_SANITIZER_THREAD
      learn_make_ENABLE_SANITIZER_MEMORY
      learn_make_ENABLE_UNITY_BUILD
      learn_make_ENABLE_CLANG_TIDY
      learn_make_ENABLE_CPPCHECK
      learn_make_ENABLE_COVERAGE
      learn_make_ENABLE_PCH
      learn_make_ENABLE_CACHE)
  endif()

  learn_make_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (learn_make_ENABLE_SANITIZER_ADDRESS OR learn_make_ENABLE_SANITIZER_THREAD OR learn_make_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(learn_make_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(learn_make_global_options)
  if(learn_make_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    learn_make_enable_ipo()
  endif()

  learn_make_supports_sanitizers()

  if(learn_make_ENABLE_HARDENING AND learn_make_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR learn_make_ENABLE_SANITIZER_UNDEFINED
       OR learn_make_ENABLE_SANITIZER_ADDRESS
       OR learn_make_ENABLE_SANITIZER_THREAD
       OR learn_make_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${learn_make_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${learn_make_ENABLE_SANITIZER_UNDEFINED}")
    learn_make_enable_hardening(learn_make_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(learn_make_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(learn_make_warnings INTERFACE)
  add_library(learn_make_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  learn_make_set_project_warnings(
    learn_make_warnings
    ${learn_make_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(learn_make_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(learn_make_options)
  endif()

  include(cmake/Sanitizers.cmake)
  learn_make_enable_sanitizers(
    learn_make_options
    ${learn_make_ENABLE_SANITIZER_ADDRESS}
    ${learn_make_ENABLE_SANITIZER_LEAK}
    ${learn_make_ENABLE_SANITIZER_UNDEFINED}
    ${learn_make_ENABLE_SANITIZER_THREAD}
    ${learn_make_ENABLE_SANITIZER_MEMORY})

  set_target_properties(learn_make_options PROPERTIES UNITY_BUILD ${learn_make_ENABLE_UNITY_BUILD})

  if(learn_make_ENABLE_PCH)
    target_precompile_headers(
      learn_make_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(learn_make_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    learn_make_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(learn_make_ENABLE_CLANG_TIDY)
    learn_make_enable_clang_tidy(learn_make_options ${learn_make_WARNINGS_AS_ERRORS})
  endif()

  if(learn_make_ENABLE_CPPCHECK)
    learn_make_enable_cppcheck(${learn_make_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(learn_make_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    learn_make_enable_coverage(learn_make_options)
  endif()

  if(learn_make_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(learn_make_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(learn_make_ENABLE_HARDENING AND NOT learn_make_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR learn_make_ENABLE_SANITIZER_UNDEFINED
       OR learn_make_ENABLE_SANITIZER_ADDRESS
       OR learn_make_ENABLE_SANITIZER_THREAD
       OR learn_make_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    learn_make_enable_hardening(learn_make_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
