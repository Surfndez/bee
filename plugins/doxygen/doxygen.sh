#!/usr/bin/env bash
#
# Generate docs with doxygen

DOXYGEN_BUILD=Build/docs

doxygen::_new() {
  echo '# doxygen => utils version
DOXYGEN_EXPORT_PATH=docs
DOXYGEN_DOXY_FILES=(bee/docs/html.doxyfile)
DOXYGEN_DOCSET_NAME="${PROJECT}.docset"
DOXYGEN_DOCSET="com.company.${PROJECT}.docset"
DOXYGEN_DOCSET_KEY="$(echo "${PROJECT}" | tr "[:upper:]" "[:lower:]")"
DOXYGEN_DOCSET_ICONS=(bee/docs/icon.png bee/docs/icon@2x.png)'
}

doxygen::generate_doxyfile() {
  log_func "$1"
  local version="$(version::read)"
  sed -i .bak -e "s/PROJECT_NUMBER.*/PROJECT_NUMBER         = ${version}/" "$1"
  rm "$1.bak"
  doxygen "$1"
}

doxygen::make_docset() {
  pushd "${DOXYGEN_BUILD}/docset" >/dev/null
    make
    # In order for Dash to associate this docset with the project keyword,
    # we have to manually modify the generated plist.
    # http://stackoverflow.com/questions/14678025/how-do-i-specify-a-keyword-for-dash-with-doxygen
    sed -i .bak -e "s/<\/dict>/<key>DocSetPlatformFamily<\/key><string>${DOXYGEN_DOCSET_KEY}<\/string><key>DashDocSetFamily<\/key><string>doxy<\/string><\/dict>/" "${DOXYGEN_DOCSET}/Contents/Info.plist"
    rm "${DOXYGEN_DOCSET}/Contents/Info.plist.bak"

    for f in "${DOXYGEN_DOCSET_ICONS[@]}"; do
      cp "${f}" "${DOXYGEN_DOCSET}"
    done

    mv "${DOXYGEN_DOCSET}" "${DOXYGEN_DOCSET_NAME}"
  popd >/dev/null
}

doxygen::generate() {
  log_func
  require doxygen
  utils::clean_dir "${DOXYGEN_BUILD}"

  for f in "${DOXYGEN_DOXY_FILES[@]}"; do
    doxygen::generate_doxyfile "${f}"
  done

  utils::clean_dir "${DOXYGEN_EXPORT_PATH}"
  rsync -air "${DOXYGEN_BUILD}/html/" "${DOXYGEN_EXPORT_PATH}"
}
