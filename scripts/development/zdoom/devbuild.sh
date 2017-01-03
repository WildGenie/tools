set -o errexit

ZDOOM_PROJECT_LOW=$(echo ${ZDOOM_PROJECT} | tr '[:upper:]' '[:lower:]')

SRC_BASE_DIR=/Volumes/Storage/Work/
SRC_DEPS_DIR=${SRC_BASE_DIR}zdoom-macos-deps/
SRC_ZDOOM_DIR=${SRC_BASE_DIR}devbuilds/${ZDOOM_PROJECT_LOW}/

BASE_DIR=/Volumes/ramdisk/${ZDOOM_PROJECT_LOW}-devbuild/
DEPS_DIR=${BASE_DIR}deps/
ZDOOM_DIR=${BASE_DIR}${ZDOOM_PROJECT_LOW}/
BUILD_DIR=${BASE_DIR}build/
DIST_DIR=${BASE_DIR}dist/

cd "${SRC_DEPS_DIR}"
git pull

cd "${SRC_ZDOOM_DIR}"
git pull

mkdir "${BASE_DIR}"

cd "${BASE_DIR}"
git clone -s "${SRC_DEPS_DIR}" "${DEPS_DIR}"
git clone -s "${SRC_ZDOOM_DIR}" "${ZDOOM_DIR}"

cd "${ZDOOM_DIR}"

if [ -n "$1" ]; then
	git checkout "$1"
fi

ZDOOM_VERSION=`git describe --tags`

mkdir "${BUILD_DIR}"
cd "${BUILD_DIR}"

FMOD_DIR=${DEPS_DIR}fmodex/
OPENAL_DIR=${DEPS_DIR}openal/
MPG123_DIR=${DEPS_DIR}mpg123/
SNDFILE_DIR=${DEPS_DIR}sndfile/
FSYNTH_DIR=${DEPS_DIR}fluidsynth/
FSYNTH_LIB_PREFIX=${FSYNTH_DIR}lib/lib
FSYNTH_LIBS=${FSYNTH_LIB_PREFIX}fluidsynth.a\;${FSYNTH_LIB_PREFIX}glib-2.0.a\;${FSYNTH_LIB_PREFIX}intl.a
OTHER_LIBS=-liconv\ -L${DEPS_DIR}ogg/lib\ -logg\ -L${DEPS_DIR}vorbis/lib\ -lvorbis\ -lvorbisenc\ -L${DEPS_DIR}flac/lib\ -lFLAC
FRAMEWORKS=-framework\ AudioUnit\ -framework\ AudioToolbox\ -framework\ CoreAudio\ -framework\ CoreMIDI
LINKER_FLAGS=${OTHER_LIBS}\ ${FRAMEWORKS}

/Applications/CMake.app/Contents/bin/cmake               \
	-DCMAKE_BUILD_TYPE="RelWithDebInfo"                  \
	-DCMAKE_OSX_DEPLOYMENT_TARGET="${ZDOOM_OS_MIN_VER}"  \
	-DCMAKE_EXE_LINKER_FLAGS="${LINKER_FLAGS}"           \
	-DOSX_COCOA_BACKEND=YES                              \
	-DDYN_OPENAL=NO                                      \
	-DDYN_FLUIDSYNTH=NO                                  \
	-DFORCE_INTERNAL_ZLIB=YES                            \
	-DFORCE_INTERNAL_JPEG=YES                            \
	-DFORCE_INTERNAL_BZIP2=YES                           \
	-DFORCE_INTERNAL_GME=YES                             \
	-DFMOD_INCLUDE_DIR="${FMOD_DIR}inc"                  \
	-DFMOD_LIBRARY="${FMOD_DIR}lib/libfmodex.dylib"      \
	-DOPENAL_INCLUDE_DIR="${OPENAL_DIR}include"          \
	-DOPENAL_LIBRARY="${OPENAL_DIR}lib/libopenal.a"      \
	-DMPG123_INCLUDE_DIR="${MPG123_DIR}include"          \
	-DMPG123_LIBRARIES="${MPG123_DIR}lib/libmpg123.a"    \
	-DSNDFILE_INCLUDE_DIR="${SNDFILE_DIR}include"        \
	-DSNDFILE_LIBRARY="${SNDFILE_DIR}lib/libsndfile.a"   \
	-DFLUIDSYNTH_INCLUDE_DIR="${FSYNTH_DIR}include"      \
	-DFLUIDSYNTH_LIBRARIES="${FSYNTH_LIBS}"              \
	-DLLVM_DIR="${DEPS_DIR}llvm/lib/cmake/llvm"          \
	"${ZDOOM_DIR}"
make -j2

BUNDLE_PATH=${DIST_DIR}${ZDOOM_PROJECT}.app
INFO_PLIST_PATH=${BUNDLE_PATH}/Contents/Info.plist

mkdir "${DIST_DIR}"
cp -R ${ZDOOM_PROJECT_LOW}.app "${BUNDLE_PATH}"
cp -R "${ZDOOM_DIR}docs" "${DIST_DIR}Docs"
ln -s /Applications "${DIST_DIR}/Applications"

plutil -replace LSMinimumSystemVersion -string "${ZDOOM_OS_MIN_VER}" "${INFO_PLIST_PATH}"
plutil -replace CFBundleVersion -string "${ZDOOM_VERSION}" "${INFO_PLIST_PATH}"
plutil -replace CFBundleShortVersionString -string "${ZDOOM_VERSION}" "${INFO_PLIST_PATH}"
plutil -replace CFBundleLongVersionString -string "${ZDOOM_VERSION}" "${INFO_PLIST_PATH}"

DMG_NAME=${ZDOOM_PROJECT}-${ZDOOM_VERSION}
DMG_FILENAME=$(echo ${DMG_NAME}.dmg | tr '[:upper:]' '[:lower:]')
DMG_PATH=${BASE_DIR}${DMG_FILENAME}

hdiutil create -srcfolder "${DIST_DIR}" -volname "${DMG_NAME}" \
	-format UDBZ -fs HFS+ -fsargs "-c c=64,a=16,e=16" "${DMG_PATH}"

DEPLOY_CONFIG_PATH=${SRC_BASE_DIR}devbuilds/.deploy_config

if [ ! -e "${DEPLOY_CONFIG_PATH}" ]; then
	tput setaf 1
	tput bold
	echo "\nDeployment configuration file was not found!\n"
	tput sgr0
	exit 1
fi

ZDOOM_DEVBUILDS=${ZDOOM_PROJECT_LOW}-macos-devbuilds
SRC_DEVBUILDS_DIR=${SRC_BASE_DIR}devbuilds/${ZDOOM_DEVBUILDS}/
DEVBUILDS_DIR=${BASE_DIR}${ZDOOM_DEVBUILDS}/

cd "${SRC_DEVBUILDS_DIR}"
git pull

cd "${BASE_DIR}"
git clone -s "${SRC_DEVBUILDS_DIR}" "${DEVBUILDS_DIR}"

TMP_CHECKSUM=$(shasum -a 256 "${DMG_PATH}")
DMG_CHECKSUM=${TMP_CHECKSUM:0:64}

REPO_URL=https://github.com/alexey-lysiuk/${ZDOOM_DEVBUILDS}
DOWNLOAD_URL=${REPO_URL}/releases/download/${ZDOOM_VERSION}/${DMG_FILENAME}

cd "${DEVBUILDS_DIR}"
git remote remove origin
git remote add origin ${REPO_URL}.git
git fetch --all
git branch -u origin/master
echo \|[\`${ZDOOM_VERSION}\`]\(${DOWNLOAD_URL}\)\|\`${DMG_CHECKSUM}\`\| >> README.md
git add .
git commit -m "+ ${ZDOOM_VERSION}"
git push
