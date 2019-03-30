# print out the version and the architecture
echo "ARCH = $ARCH"
echo "JULIA_VER = $JULIA_VER"

# launch the test script
if [ "$ARCH" == "Linux" ]; then
    pwd
    $ARTENOLIS_SOFT_PATH/julia/$JULIA_VER/bin/julia --color=yes -e 'import Pkg; Pkg.add(pwd()); Pkg.rm("GigaSOM");'
fi

CODE=$?
exit $CODE
