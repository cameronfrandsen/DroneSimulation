# - Find an externpro installation.
# externpro_DIR
################################################################################
# should match xpGetCompilerPrefix in externpro's xpfunmac.cmake
# NOTE: wanted to use externpro version, but chicken-egg problem
function(getCompilerPrefix _ret)
  set(options GCC_TWO_VER)
  cmake_parse_arguments(X "${options}" "" "" ${ARGN})
  if(MSVC)
    set(prefix vc${MSVC_TOOLSET_VERSION})
  elseif(CMAKE_COMPILER_IS_GNUCXX)
    exec_program(${CMAKE_CXX_COMPILER}
      ARGS ${CMAKE_CXX_COMPILER_ARG1} -dumpfullversion -dumpversion
      OUTPUT_VARIABLE GCC_VERSION
      )
    if(X_GCC_TWO_VER)
      set(digits "\\1\\2")
    else()
      set(digits "\\1\\2\\3")
    endif()
    string(REGEX REPLACE "([0-9]+)\\.([0-9]+)\\.([0-9]+)?"
      "gcc${digits}"
      prefix ${GCC_VERSION}
      )
  elseif(${CMAKE_CXX_COMPILER_ID} MATCHES "Clang") # LLVM/Apple Clang (clang.llvm.org)
    if(${CMAKE_SYSTEM_NAME} STREQUAL Darwin)
      exec_program(${CMAKE_CXX_COMPILER}
        ARGS ${CMAKE_CXX_COMPILER_ARG1} -dumpversion
        OUTPUT_VARIABLE CLANG_VERSION
        )
      string(REGEX REPLACE "([0-9]+)\\.([0-9]+)(\\.[0-9]+)?"
        "clang-darwin\\1\\2" # match boost naming
        prefix ${CLANG_VERSION}
        )
    else()
      string(REGEX REPLACE "([0-9]+)\\.([0-9]+)(\\.[0-9]+)?"
        "clang\\1\\2" # match boost naming
        prefix ${CMAKE_CXX_COMPILER_VERSION}
        )
    endif()
  else()
    message(SEND_ERROR "Findexternpro.cmake: compiler support lacking: ${CMAKE_CXX_COMPILER_ID}")
  endif()
  set(${_ret} ${prefix} PARENT_SCOPE)
endfunction()
function(getNumBits _ret)
  if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(numBits 64)
  elseif(CMAKE_SIZEOF_VOID_P EQUAL 4)
    set(numBits 32)
  else()
    message(FATAL_ERROR "numBits not 64 or 32")
  endif()
  set(${_ret} ${numBits} PARENT_SCOPE)
endfunction()
################################################################################
# TRICKY: clear cached variables each time we cmake so we can change
# externpro_REV and reuse the same build directory
unset(externpro_DIR CACHE)
################################################################################
# find the path to the externpro directory
getCompilerPrefix(COMPILER)
getNumBits(BITS)
set(externpro_SIG ${externpro_REV}-${COMPILER}-${BITS})
set(PFX86 "ProgramFiles(x86)")
find_path(externpro_DIR
  NAMES
    externpro_${externpro_SIG}.txt
  PATHS
    # build versions
    C:/src/externpro/_bld/externpro_${externpro_SIG}
    ~/src/externpro/_bld/externpro_${externpro_SIG}
    # environment variable - build versions
    "$ENV{externpro_BUILD_DIR}/externpro_${externpro_SIG}"
    # environment variable - installed versions
    "$ENV{extern_DIR}/externpro ${externpro_SIG}"
    "$ENV{extern_DIR}/externpro-${externpro_SIG}-${CMAKE_SYSTEM_NAME}"
    # installed versions
    "$ENV{ProgramW6432}/externpro ${externpro_SIG}"
    "$ENV{${PFX86}}/externpro ${externpro_SIG}"
    "~/extern/externpro-${externpro_SIG}-${CMAKE_SYSTEM_NAME}"
    "/opt/extern/externpro-${externpro_SIG}-${CMAKE_SYSTEM_NAME}"
  DOC "externpro directory"
  )
if(NOT externpro_DIR)
  if(DEFINED externpro_INSTALLER_LOCATION)
    message(FATAL_ERROR "externpro ${externpro_SIG} not found.\n${externpro_INSTALLER_LOCATION}")
  else()
    message(FATAL_ERROR "externpro ${externpro_SIG} not found")
  endif()
else()
  set(moduleDir ${externpro_DIR}/share/cmake)
  set(findFile ${moduleDir}/Findexternpro.cmake)
  execute_process(COMMAND ${CMAKE_COMMAND} -E compare_files ${CMAKE_CURRENT_LIST_FILE} ${findFile}
    RESULT_VARIABLE filesDiff
    OUTPUT_QUIET
    ERROR_QUIET
    )
  if(filesDiff)
    message(STATUS "local: ${CMAKE_CURRENT_LIST_FILE}.")
    message(STATUS "externpro: ${findFile}.")
    message(AUTHOR_WARNING "Find scripts don't match. You may want to update the local with the externpro version.")
  endif()
  execute_process(COMMAND lsb_release --description
    OUTPUT_VARIABLE lsbDesc # LSB (Linux Standard Base)
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
    )
  if(NOT lsbDesc STREQUAL "")
    set(infoFile ${externpro_DIR}/externpro_${externpro_SIG}.txt)
    set(lsbString "^lsb_release Description:[ \t]+(.*)")
    file(STRINGS ${infoFile} LSB REGEX "${lsbString}")
    string(REGEX REPLACE "${lsbString}" "\\1" xpLSB ${LSB})
    string(REGEX REPLACE "Description:[ \t]+(.*)" "\\1" thisLSB ${lsbDesc})
    if(NOT xpLSB STREQUAL thisLSB)
      message(STATUS "externpro \"${xpLSB}\" build")
      message(STATUS "${PROJECT_NAME} \"${thisLSB}\" build")
      message(AUTHOR_WARNING "linux distribution mismatch")
    endif()
  endif()
  message(STATUS "Found externpro: ${externpro_DIR}")
  list(APPEND XP_MODULE_PATH ${moduleDir})
  link_directories(${externpro_DIR}/lib)
  if(EXISTS ${moduleDir}/xpfunmac.cmake)
    include(${moduleDir}/xpfunmac.cmake)
  endif()
endif()
