LEGACY_DIR=$BUILD_ROOT/src/ulx3s
DIR=$BUILD_ROOT/src/ulx3s_0
echo $LEGACY_DIR
echo $DIR
[ -d $LEGACY_DIR ] && ln -s $LEGACY_DIR $DIR
exit 0
