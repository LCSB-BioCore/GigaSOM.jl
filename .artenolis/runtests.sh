# print out the version and the architecture
echo "ARCH = $ARCH"
echo "JULIA_VER = $JULIA_VER"

# launch the test script
if [ "$ARCH" == "Linux" ]; then
    $ARTENOLIS_SOFT_PATH/julia/$JULIA_VER/bin/julia --color=yes -e 'using Pkg; Pkg.add(pwd());'
fi

CODE=$?
exit $CODE
